# Fleet Monitor — CS 3660 Sprint 2

Distributed fleet telemetry monitoring and alerting system. Simulated vehicles publish sensor readings over MQTT. A gateway pipeline translates, routes, and enriches messages. An XState alert engine runs a state machine per channel. An append-only SQLite event store supports point-in-time fleet reconstruction. A ws-bridge serves the dashboard and bridges MQTT to the browser over WebSocket.

## Live deployment

- **Dashboard:** https://fleet-monitor-ws-bridge.onrender.com/dashboard/
- **API:** https://fleet-monitor-ws-bridge.onrender.com/api/fleet-state

## Architecture

```
device-sim  -->  MQTT broker (mqtt.uvucs.org)
                    |
              gateway (EIP pipeline)
              Translator -> Router -> Enricher
                    |
              alert-engine (XState per channel)
              + EventDispatcher (Observer)
              + AuditLogger -> event store (SQLite)
                    |
              ws-bridge (Koa + WebSocket)
                    |
              dashboard (browser)
```

## Patterns

| Pattern | Where |
|---|---|
| Publish-Subscribe Channel (EIP) | mqttBus.js — gateway, alert-engine, ws-bridge each subscribe |
| Message Translator (EIP) | MessageTranslator.js — normalizes raw device payloads |
| Content-Based Router (EIP) | MessageRouter.js — routes by metric type |
| Content Enricher (EIP) | ContentEnricher.js — adds registry data and rolling average |
| Strategy (GoF) | AlertStrategy / ThresholdStrategy / RollingAverageStrategy / RateOfChangeStrategy |
| Factory Method (GoF) | StrategyFactory.createStrategy() |
| Observer (GoF) | EventDispatcher notifying AuditLogger and WsBridgeObserver |

## Alert state chart

One XState machine instance runs per monitored channel (e.g., `vehicle-7:coolantTemp`).

### States

| State | Meaning |
|---|---|
| NORMAL | All readings within bounds |
| WARNING | Sustained readings above warn threshold |
| CRITICAL | Sustained readings above critical threshold |
| ACKNOWLEDGED | Operator has seen the alert |
| RESOLVED | Alert cleared — readings back to normal or manually resolved |
| OFFLINE | No heartbeat received within stalenessMs |

### Transition table

| From | Event | Guard | To |
|---|---|---|---|
| NORMAL | READING | isCritical(value) AND sustained(count, required) | CRITICAL |
| NORMAL | READING | isWarning(value) AND sustained(count, required) | WARNING |
| NORMAL | READING | none | NORMAL (increment consecutiveCount) |
| NORMAL | HEARTBEAT_TIMEOUT | isStale(lastSeen) | OFFLINE |
| WARNING | READING | isCritical(value) AND sustained(count, required) | CRITICAL |
| WARNING | READING | isBackToNormal(value) AND sustained(count, required) | NORMAL |
| WARNING | READING | none | WARNING (increment consecutiveCount) |
| WARNING | ACK | always | ACKNOWLEDGED |
| WARNING | HEARTBEAT_TIMEOUT | isStale(lastSeen) | OFFLINE |
| CRITICAL | READING | isWarning(value) (not critical) | WARNING |
| CRITICAL | READING | isBackToNormal(value) AND sustained(count, required) | NORMAL |
| CRITICAL | READING | none | CRITICAL (increment consecutiveCount) |
| CRITICAL | ACK | always | ACKNOWLEDGED |
| CRITICAL | HEARTBEAT_TIMEOUT | isStale(lastSeen) | OFFLINE |
| ACKNOWLEDGED | READING | isCritical(value) | CRITICAL |
| ACKNOWLEDGED | READING | isBackToNormal(value) AND sustained(count, required) | RESOLVED |
| ACKNOWLEDGED | READING | none | ACKNOWLEDGED (increment consecutiveCount) |
| ACKNOWLEDGED | RESOLVE | always | RESOLVED |
| ACKNOWLEDGED | HEARTBEAT_TIMEOUT | isStale(lastSeen) | OFFLINE |
| RESOLVED | READING | isBackToNormal(value) | NORMAL |
| RESOLVED | READING | meetsAnyCondition(value) | WARNING |
| OFFLINE | DEVICE_ONLINE | always | NORMAL |
| OFFLINE | READING | always | NORMAL |

### Guard definitions

| Guard | Logic |
|---|---|
| `isWarning(value, warn, crit, lowIsBad)` | `value >= warn && value < crit` (or inverted when lowIsBad) |
| `isCritical(value, crit, lowIsBad)` | `value >= crit` (or `value <= crit` when lowIsBad) |
| `isBackToNormal(value, warn, margin, lowIsBad)` | `value < (warn - margin)` (or `value > (warn + margin)` when lowIsBad) |
| `sustained(count, required)` | `count >= required` |
| `isStale(lastSeen, stalenessMs)` | `Date.now() - lastSeen > stalenessMs` |
| `meetsAnyCondition(value, warn, crit, lowIsBad)` | `value >= warn` (or `value <= warn` when lowIsBad) |

The `lowIsBad` flag inverts direction for metrics where low values are dangerous (oilPressure, fuelLevel).

### Hysteresis

To avoid flapping between WARNING and NORMAL, the `isBackToNormal` guard requires the value to drop below `warnThreshold - hysteresisMargin` (default: 5 units below warn). Transitions also require `sustainedReadings` consecutive qualifying readings (default: 3) before state change.

## Running locally

```bash
# Install dependencies
npm install

# Copy and edit environment variables
cp .env.example .env

# Run tests
npm test

# Start services (each in its own terminal)
npm run start:gateway
npm run start:alert-engine
npm run start:ws-bridge
npm run start:device-sim
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| MQTT_URL | mqtt://mqtt.uvucs.org:1883 | MQTT broker URL |
| MQTT_USER | | Broker username |
| MQTT_PASS | | Broker password |
| AUTH_TOKEN | changeme | Bearer token for ACK/RESOLVE commands |
| SQLITE_PATH | ./data/events.db | SQLite event store path |
| WS_BRIDGE_PORT | 3000 | Port for ws-bridge HTTP server |
| SUSTAINED_READINGS | 3 | Consecutive readings required for state change |
| STALENESS_MS | 30000 | Milliseconds before a channel is considered offline |

## Tests

```bash
npm test
```

72 tests across 6 files covering guards, EIP pipeline, alert machine transitions, and end-to-end integration.
