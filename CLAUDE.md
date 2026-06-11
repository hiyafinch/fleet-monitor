# Fleet Monitor — CS 3660 Sprint 2

**Goal:** A distributed fleet telemetry monitoring and alerting system. Simulated vehicles publish sensor readings over MQTT. A gateway translates, routes, and enriches them. An alert engine runs an XState state machine per channel. Everything is recorded in an immutable, append-only event store. A live dashboard shows fleet state with a time-travel slider for point-in-time reconstruction.

**Demo day:** June 29, 2026. **Points:** 150.

---

## Student

- Ethan Kidd, UVU CS 3660 Web Design 2, Summer 2026
- GitHub: hiyafinch
- Email: hiyafinch@gmail.com

---

## Style rules (always enforce)

- No em dashes. Ever. Use commas, periods, or restructure.
- No semicolons in prose.
- All generated files start with an AI-citation comment at line 1 (same as Sprint 1).
- Pattern names in the Pattern Index are load-bearing. Do not rename them.

---

## Tech stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 20+ |
| HTTP / WS server | Koa |
| MQTT client | mqtt.js |
| Frontend | Lit Element (ES modules, no bundler required for dev) |
| State machine | XState v5 |
| Database | better-sqlite3 (synchronous, append-only event store) |
| LLM (optional) | Ollama API via Strategy pattern from Sprint 1 |
| Container | Docker + docker-compose |
| Reverse proxy | Caddy (HTTPS + wss) |

---

## Architecture: components and topics

Each component is a separate Node process. They share nothing except the MQTT broker and the SQLite event store file.

| Component | Role | Subscribes | Publishes |
|---|---|---|---|
| `device-sim` | Emits raw sensor readings for multiple vehicles | (none) | `fleet/{vehicleId}/raw` |
| `gateway` | Translate, route, enrich raw readings | `fleet/+/raw` | `fleet/{vehicleId}/{metric}/clean` |
| `alert-engine` | XState machine per channel; decides alert state | `fleet/+/+/clean` | `alerts/{vehicleId}/{metric}` |
| `aggregator` | Windowed rollups (optional stretch) | `fleet/+/+/clean` | `rollups/{vehicleId}/{metric}` |
| `ws-bridge` | Koa service: bridges MQTT to browser over wss; serves dashboard and history API | `alerts/#`, `fleet/#`, `rollups/#` | (to browsers via wss) |
| `dashboard` | Lit Element SPA: live readings, alert states, time-travel slider, ACK/RESOLVE | (via ws-bridge) | ACK / RESOLVE commands |
| `audit-logger` | Appends every domain event to the event store | `fleet/#`, `alerts/#` | (to SQLite) |
| `llm-summarizer` | Generates natural-language alert explanations (optional) | `alerts/#` | `alerts/{vehicleId}/{metric}/summary` |

### Monorepo layout

```
fleet-monitor/
  src/
    bus/
      mqttBus.js          # shared MQTT client factory
    device-sim/
      index.js
    gateway/
      index.js
      MessageTranslator.js
      MessageRouter.js
      ContentEnricher.js
    alert-engine/
      index.js
      alertMachine.js     # XState machine definition
      strategies/
        AlertStrategy.js  # interface / base
        ThresholdStrategy.js
        RollingAverageStrategy.js
        RateOfChangeStrategy.js
      StrategyFactory.js
    events/
      EventDispatcher.js  # Observer subject
      AuditLogger.js      # Observer
      WsBridgeObserver.js # Observer
      eventStore.js       # better-sqlite3 append-only store
    ws-bridge/
      index.js
    llm/
      OllamaAdapter.js    # Adapter reused from Sprint 1
    config.js             # reads process.env; never hardcodes secrets
  dashboard/
    index.html
    components/
      fleet-map.js
      alert-panel.js
      time-travel-slider.js
    i18n/
      en.json
  tests/
    reducer.test.js
    guards.test.js
    MessageRouter.test.js
    ContentEnricher.test.js
    MessageTranslator.test.js
    integration.test.js
  docker-compose.yml
  Caddyfile
  .env.example
  .gitignore
  README.md
  CLAUDE.md
```

---

## MQTT conventions

- **Broker:** mqtt.uvucs.org (port 1883 plain, 8883 TLS)
- **Topic scheme:** `fleet/{vehicleId}/{metric}/clean`, `alerts/{vehicleId}/{metric}`
- **QoS 1** on all alert and command topics (no silent drops)
- **Retained messages** on latest reading and alert state per topic (fresh subscriber sees current state immediately)
- **Last Will and Testament (LWT):** each device-sim publishes LWT to `fleet/{vehicleId}/status` with payload `{"status":"offline"}`. The alert-engine consumes this to drive the OFFLINE transition.
- **Stable clientId + cleanSession=false** on alert-engine and ws-bridge so reconnected subscribers resume their sessions
- **Browser constraint:** browsers over HTTPS cannot connect to plain `ws://`. The ws-bridge sits between MQTT and the browser. The browser speaks `wss://` to the bridge; the bridge (server-side) speaks plain MQTT to the broker.

---

## Pattern Index (load-bearing names, do not rename)

| Pattern | Type | Class / File | Citation |
|---|---|---|---|
| Publish-Subscribe Channel | EIP | `src/bus/mqttBus.js` + all subscribers | https://www.enterpriseintegrationpatterns.com/patterns/messaging/PublishSubscribeChannel.html |
| Message Router (Content-Based Router) | EIP | `src/gateway/MessageRouter.js` | https://www.enterpriseintegrationpatterns.com/patterns/messaging/ContentBasedRouter.html |
| Content Enricher | EIP | `src/gateway/ContentEnricher.js` | https://www.enterpriseintegrationpatterns.com/patterns/messaging/DataEnricher.html |
| Message Translator | EIP | `src/gateway/MessageTranslator.js` | https://www.enterpriseintegrationpatterns.com/patterns/messaging/MessageTranslator.html |
| Strategy | GoF | `src/alert-engine/strategies/` + `StrategyFactory.js` | GoF (Gamma et al., Design Patterns) |
| Observer | GoF | `src/events/EventDispatcher.js` | GoF (Gamma et al., Design Patterns) |

**Important:** The auto-grader does name-matching. Every pattern name above must exist as a real class and file in the repo before the sprint deadline.

---

## State chart: alert lifecycle

One XState machine instance per monitored channel (e.g., vehicle-7 coolantTemp). Defined in `src/alert-engine/alertMachine.js`.

### States

| State | Meaning |
|---|---|
| `NORMAL` | Readings within bounds |
| `WARNING` | Crossed warning threshold, sustained |
| `CRITICAL` | Crossed critical threshold, sustained |
| `ACKNOWLEDGED` | Operator acknowledged; suppresses re-notification but keeps tracking |
| `RESOLVED` | Condition cleared and held below threshold past hysteresis margin |
| `OFFLINE` | No readings within staleness window, or LWT fired |

### Events

`READING { value, ts }`, `ACK { operator }`, `RESOLVE`, `HEARTBEAT_TIMEOUT`, `DEVICE_ONLINE`

### Guards

| Guard | Meaning |
|---|---|
| `isWarning(value)` | value >= warnThreshold and < critThreshold |
| `isCritical(value)` | value >= critThreshold |
| `isBackToNormal(value)` | value < (warnThreshold - hysteresisMargin) |
| `sustainedFor(n)` | Triggering condition held for n consecutive readings |
| `isStale(lastSeen)` | now - lastSeen > stalenessMs |
| `isActiveAlert()` | Current state is WARNING or CRITICAL |

### Transitions

| From | Event | Guard | To |
|---|---|---|---|
| NORMAL | READING | isWarning && sustainedFor(n) | WARNING |
| NORMAL | READING | isCritical && sustainedFor(n) | CRITICAL |
| WARNING | READING | isCritical && sustainedFor(n) | CRITICAL |
| WARNING | READING | isBackToNormal && sustainedFor(n) | NORMAL |
| CRITICAL | READING | !isCritical && isWarning | WARNING |
| WARNING or CRITICAL | ACK | isActiveAlert | ACKNOWLEDGED |
| ACKNOWLEDGED | READING | isCritical | CRITICAL |
| ACKNOWLEDGED | READING | isBackToNormal && sustainedFor(n) | RESOLVED |
| RESOLVED | READING | isBackToNormal | NORMAL |
| any | HEARTBEAT_TIMEOUT | isStale | OFFLINE |
| OFFLINE | DEVICE_ONLINE or READING | (none) | NORMAL |

---

## Event store (append-only, never UPDATE or DELETE domain rows)

Table: `events`

| Column | Purpose |
|---|---|
| `id` | Autoincrement, monotonic ordering |
| `aggregate_type` | e.g. `channel` |
| `aggregate_id` | e.g. `vehicle-7:coolantTemp` |
| `event_type` | `ReadingRecorded`, `AlertRaised`, `AlertEscalated`, `AlertAcknowledged`, `AlertResolved`, `DeviceWentOffline` |
| `payload` | JSON |
| `occurred_at` | Domain time (ISO string) |
| `recorded_at` | System time |
| `actor` | `system` or operator id |
| `correlation_id` | Ties a reading to the alert events it caused |
| `causation_id` | The event that directly caused this one |
| `hash` | sha256(prev_hash + canonical(payload)) |
| `prev_hash` | Hash of the preceding row (hash chain for tamper-evidence) |

Point-in-time reconstruction: select all events for `aggregate_id` with `occurred_at <= T`, fold through the pure reducer, get exact historical state.

---

## Perfect Framework checklist

| Concern | Evidence location |
|---|---|
| Secrets management | `.env` (gitignored), `.env.example`, `src/config.js` reads `process.env` |
| Authentication | Koa middleware on ws-bridge ACK/RESOLVE endpoints; token required for any mutation |
| Scalability | Stateless gateway/alert-engine workers; `docker-compose --scale gateway=2`; documented in README |
| Persistence | `events` table; state rebuilt by replay on restart |
| Audit trails | Event store + hash chain + time-travel reconstruction |
| Deployment | Public HTTPS via Caddy, `Caddyfile` in repo |

---

## Testing expectations

Unit tests (Node built-in test runner, same as Sprint 1):
- `tests/reducer.test.js` — pure reducer / state fold logic
- `tests/guards.test.js` — each guard function in isolation
- `tests/MessageRouter.test.js` — routing logic for each metric type
- `tests/ContentEnricher.test.js` — enrichment adds expected fields
- `tests/MessageTranslator.test.js` — normalization of raw payloads

Integration test:
- `tests/integration.test.js` — publish a raw reading, verify it emerges as an alert event in the event store (full pipeline, in-process)

---

## Out of scope

- User accounts / multi-tenant auth (token auth on commands is sufficient)
- Real vehicle hardware
- Complex business rules beyond what the alert machine covers
- Any UI feature not needed for the demo beats in the implementation plan
- React, Vue, or any frontend framework beyond Lit Element

---

## Build phases

| Phase | Dates | Focus |
|---|---|---|
| Week 0-1 | June 3-9 | MQTT proof of life, gateway EIPs, audit-logger, event store |
| Week 2 | June 10-16 | XState alert machine, Strategy, Observer, tests |
| Week 3 | June 17-23 | Dashboard, ws-bridge, time-travel slider, tests complete |
| Week 4 | June 24-29 | Deploy, README, presentation video, reflection |

**Deploy no later than June 25** to leave buffer for TLS/wss issues.
