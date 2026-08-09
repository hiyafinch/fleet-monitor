# Fleet Monitor — Sprint 2 Presentation Summary

**CS 3660 Web Design 2 — Summer 2026**
**Ethan Kidd**

---

## What it does

Fleet Monitor ingests real-time sensor readings from simulated vehicles over MQTT, evaluates them against configurable alert thresholds, and maintains an immutable audit trail in SQLite. A browser dashboard shows live fleet state and supports point-in-time reconstruction by dragging a time-travel slider.

---

## Enterprise Integration Patterns

### 1. Publish-Subscribe Channel

The MQTT broker (mqtt.uvucs.org) is the pub-sub backbone. Three independent services each open their own MQTT client with QoS 1 delivery:

- `gateway` subscribes to `fleet/+/raw` for incoming raw sensor payloads
- `alert-engine` subscribes to `fleet/+/+/clean`, `fleet/+/status`, and `fleet/+/+/command`
- `ws-bridge` subscribes to `alerts/#` and `fleet/#` to relay everything to browsers

The gateway also uses Last Will and Testament (LWT) so the broker publishes an offline status if the gateway disconnects without warning. Reconnect period is 2000 ms on all clients for resilience.

Reference: Hohpe and Woolf, *Enterprise Integration Patterns* (2003), ch. 6.

### 2. Message Translator

`MessageTranslator.js` normalizes raw device payloads into a canonical schema before anything else runs. It validates that `vehicleId`, `metric`, and `value` are present and well-formed, rejects malformed messages, and produces a consistent shape the rest of the pipeline can rely on. No downstream class needs to know what format the device originally sent.

Reference: EIP, ch. 7 — Message Translator.

### 3. Content-Based Router

`MessageRouter.js` examines the `metric` field of each translated message and resolves the correct downstream topic and route. It supports per-metric routes (`coolantTemp`, `oilPressure`, `rpm`, `fuelLevel`) plus a wildcard fallback. The router never mutates the message — it only decides where it goes.

Reference: EIP, ch. 7 — Content-Based Router.

### 4. Content Enricher

`ContentEnricher.js` adds reference data from a vehicle registry (calibration offsets, metadata), a rolling average over the last N readings, and alert thresholds for the metric. By the time a message exits the enricher it carries everything downstream consumers need — the alert engine does not have to look anything up.

Reference: EIP, ch. 8 — Content Enricher.

---

## GoF Design Patterns

### 1. Strategy (GoF)

Each metric channel selects an alert evaluation strategy at startup via `StrategyFactory.createStrategy()`. Concrete strategies are `ThresholdStrategy` (static warn/crit thresholds), `RollingAverageStrategy` (smooths noisy spikes using the enricher's rolling average), and `RateOfChangeStrategy` (flags rapid changes). All implement the `AlertStrategy` base class with an `evaluate(enrichedMessage, channelConfig)` method returning `{ isWarning, isCritical, reason }`.

The alert engine calls `strategies[metric].evaluate(enriched, channelConfig)` on every incoming reading and attaches the result to the `ReadingRecorded` domain event. Swapping the algorithm for a channel requires only a config change — no alert engine logic changes.

Reference: Gamma et al., *Design Patterns* (1994), Strategy.

### 2. Observer (GoF)

`EventDispatcher` maintains a subscriber list and fans out every domain event to all registered observers. Two observers are wired up at startup:

- `AuditLogger` — writes every event to the append-only SQLite event store
- `WsBridgeObserver` — forwards events to connected browser clients over WebSocket

The dispatcher doesn't know anything about storage or WebSockets. Adding a third observer (for example, a Slack alerting notifier) requires zero changes to the dispatcher or the alert engine.

Reference: Gamma et al., *Design Patterns* (1994), Observer.

### 3. Factory Method (GoF)

`StrategyFactory.createStrategy(strategyName)` is a Factory Method that encapsulates construction of concrete strategy objects. The alert engine calls it with a string key from the channel config and gets back the right `AlertStrategy` instance. Adding a new strategy type means adding one entry to the factory map.

Reference: Gamma et al., *Design Patterns* (1994), Factory Method.

---

## State chart: alert lifecycle

One XState v5 machine runs per monitored channel. States: `NORMAL`, `WARNING`, `CRITICAL`, `ACKNOWLEDGED`, `RESOLVED`, `OFFLINE`. Key design decisions:

**Hysteresis** — recovery from WARNING back to NORMAL requires the value to drop below `warnThreshold - hysteresisMargin` (default 5 units). This prevents flapping when a reading oscillates near the threshold.

**Sustained readings** — transitions to WARNING and CRITICAL require `sustainedReadings` (default 3) consecutive qualifying readings. A single spike does not trigger an alert.

**Staleness** — if no reading arrives within `stalenessMs` (default 30 s), a `HEARTBEAT_TIMEOUT` event fires and the machine moves to `OFFLINE`. Recovery happens on `DEVICE_ONLINE` or the next valid reading.

**Direction inversion** — metrics where low values are dangerous (oilPressure, fuelLevel) use a `lowIsBad` flag that inverts all threshold comparisons.

Full transition table is in README.md.

---

## Perfect Framework concerns

### 1. Secrets management

All credentials (MQTT username/password, SQLite path, command auth token) are loaded exclusively from environment variables via `dotenv`. No secrets appear in source code. `.env` is in `.gitignore`. The `.env.example` file documents every variable with a safe default.

### 2. Auditability (audit trail)

`eventStore.js` is strictly append-only — no UPDATE or DELETE operations exist. Every domain event carries `occurred_at`, `recorded_at`, `actor`, `correlation_id`, `causation_id`, and a per-aggregate SHA-256 hash chain. `verifyChain()` detects tampering. `getAllEvents({ upToTime })` supports point-in-time reconstruction of any past fleet state, accessible via `GET /api/fleet-state?upToTime=<iso>`.

### 3. Security

The `POST /api/command` endpoint (ACK/RESOLVE) requires `Authorization: Bearer <token>`. Unauthenticated requests receive 401. The token is set via the `AUTH_TOKEN` environment variable and is never logged or committed.

### 4. Resilience

All MQTT clients use QoS 1 (at-least-once delivery) and a 2000 ms reconnect period. The gateway publishes an LWT message so downstream consumers learn immediately when it drops. The alert engine handles `HEARTBEAT_TIMEOUT` to mark channels `OFFLINE` rather than leaving stale state indefinitely.

### 5. Scalability

Each of the four services (gateway, alert-engine, ws-bridge, device-sim) is a stateless, independently deployable Node process. Horizontal scaling is possible because shared state lives in the MQTT broker and the SQLite event store, not in process memory. The event-sourcing design means adding a new read model requires only a new projection over the existing event store.

---

## Demo highlights

- Device simulator publishes readings for 4 vehicles across 4 metric types
- Gateway translates, routes, and enriches each reading in under 5 ms
- Alert engine transitions channels to WARNING and CRITICAL as simulated values cross thresholds
- Dashboard shows live fleet grid with color-coded alert states
- Time-travel slider reconstructs fleet state at any past timestamp from the event store
- ACK and RESOLVE commands issued from the dashboard reach the alert engine via MQTT in under 100 ms

---

## Reflection

The biggest challenge was the MQTT-to-browser bridging requirement. Browsers served over HTTPS cannot connect to a plain `ws://` endpoint. The ws-bridge process solves this by acting as a protocol adapter: it speaks MQTT internally and exposes a `wss://` WebSocket to browsers. The XState machine's hysteresis and sustained-readings guards required careful test design to drive each guard path independently.
