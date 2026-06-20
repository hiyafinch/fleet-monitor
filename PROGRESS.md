# Sprint 2 Progress Tracker

Last updated: 2026-06-20

---

## Current status

**Week 3 of 4 — complete.** Demo day: June 29. 71/71 tests passing. Dashboard live and verified.

---

## What's done

### Week 0-1 scaffold (June 3-10)
- [x] `CLAUDE.md` written and committed to repo
- [x] GitHub repo created: https://github.com/hiyafinch/fleet-monitor
- [x] Full monorepo scaffold pushed (28 files, one commit)
- [x] All 6 pattern files written with correct class names (Pattern Index complete)
- [x] XState v5 alert machine — all 6 states, guards, transitions
- [x] Append-only event store with hash chain (`src/events/eventStore.js`)
- [x] Observer pattern wired: `EventDispatcher`, `AuditLogger`, `WsBridgeObserver`
- [x] Strategy pattern: `ThresholdStrategy`, `RollingAverageStrategy`, `RateOfChangeStrategy`, `StrategyFactory`
- [x] Gateway EIP pipeline: `MessageTranslator` -> `MessageRouter` -> `ContentEnricher`
- [x] Device simulator with LWT support (3 vehicles, 4 metrics)
- [x] 4 unit test files written (guards, translator, router, enricher)
- [x] `docker-compose.yml`, `Dockerfile`, `.env.example`
- [x] `npm install` successful (better-sqlite3 upgraded to v12 for Node 24 compat)
- [x] MQTT proof of life confirmed on `test.mosquitto.org` — 3 vehicles streaming

### Week 2 (June 10-17)
- [x] Full pipeline end to end: device-sim + gateway + alert-engine live together
- [x] Clean topics confirmed: `fleet/{vehicleId}/{metric}/clean`
- [x] Alert topics confirmed: `alerts/{vehicleId}/{metric}`
- [x] Bug fixed: `lowIsBad` guards for oilPressure and fuelLevel
- [x] RESOLVE event and command topic handling added to alert-engine
- [x] 71/71 tests passing (reducer.test.js 26 tests, integration.test.js 13 tests added)
- [x] Observer fan-out confirmed: AuditLogger and WsBridgeObserver both fire from same dispatch
- [x] Events verified writing to SQLite event store
- [x] Committed: `fa7589a`

### Week 3 (June 17-23)
- [x] `src/ws-bridge/index.js` — Koa HTTP + WebSocket server
  - Bridges MQTT to browser over ws://
  - GET /api/fleet-state (with optional upToTime for time-travel)
  - GET /api/events/range (slider bounds)
  - POST /api/command (ACK/RESOLVE, Bearer auth)
  - Serves static dashboard from /dashboard/
- [x] `dashboard/index.html` — SPA shell, WebSocket client, reconnect logic
- [x] `dashboard/components/fleet-map.js` — Lit Element vehicle card grid
- [x] `dashboard/components/alert-panel.js` — Lit Element active alerts table with ACK/RESOLVE buttons
- [x] `dashboard/components/time-travel-slider.js` — Lit Element range slider, fires time-travel events
- [x] `dashboard/i18n/en.json` — label strings
- [x] `scripts/inject-spike.js` — CLI tool to inject CRITICAL / NORMAL readings for demo
- [x] Bug fixed: stale persistent MQTT sessions on test.mosquitto.org blocked message delivery
  - Root cause: `clean: false` + stable clientIds caused broker to hold stale session state
  - Fix: `clean: true` + `Date.now()` suffix on clientIds for dev
- [x] Dashboard smoke-tested: 3 vehicles, all NORMAL, values updating live every 2s
- [x] Time-travel slider: disabled until events accumulate, then enables with earliest/latest bounds
- [x] ACK/RESOLVE flow: inject-spike.js script ready for demo trigger
- [x] Committed: `8b8439d`

---

## What's next

### Week 4 (June 24-29)
- [ ] Deploy to public HTTPS URL via Caddy (target: June 25 — buffer for TLS/wss issues)
- [ ] Write README (Pattern Index, state chart table, EIP citations, Perfect Framework, run instructions)
- [ ] Self-grep: confirm every pattern name in README exists as a real class in code
- [ ] Record 15-min demo video, upload to YouTube (Unlisted)
- [ ] Commit `sprints/sprint-2-reflection.md` (individual reflection, due 24h after demo)
- [ ] Tag commit: `sprint-2-final`
- [ ] Submit tag URL to Canvas
- [ ] Optional: Ollama LLM summarizer (only if ahead of schedule)

---

## Open issues / things to come back to

### MQTT broker (mqtt.uvucs.org) — BLOCKED
- **Status:** Times out on port 1883. Likely firewalled to UVU campus/VPN.
- **Workaround:** Using `test.mosquitto.org` for all development. Works fine.
- **Before demo:** Switch MQTT_URL back to mqtt.uvucs.org if accessible, or confirm test.mosquitto.org is acceptable.

### Clean session clientIds
- **Current:** `clean: true` + `Date.now()` suffix (dev workaround for test.mosquitto.org session issue)
- **Before demo:** Revert to stable clientIds (`alert-engine-1`, `gateway-1`, `ws-bridge-1`) once deployed on a server that doesn't share broker sessions with development machines.

### Sprint is listed as a Team project
- **Status:** Ethan is doing it solo.
- **Action:** Confirm with Prof. Hunter that solo submission is OK.

---

## Key reminders

- Pattern names in the Pattern Index are load-bearing. Never rename `MessageRouter`, `ContentEnricher`, `MessageTranslator`, `EventDispatcher`, etc.
- Auto-grader matches pattern names to actual code. Always self-grep before submitting.
- Deploy by June 25, not June 29, to leave buffer for TLS/wss issues.
- All generated files need an AI-citation comment at line 1.
- When injecting spikes for demo: `node scripts/inject-spike.js` (CRITICAL) then `node scripts/inject-spike.js clear` (back to NORMAL).

---

## Rubric point breakdown (150 total)

| Line | Points |
|---|---|
| Pub-sub live, robust, multiple subscribers, recoverable from disconnect | 25 |
| 2+ additional EIPs, correctly named and implemented | 25 |
| State chart — non-trivial, documented states/events/transitions/guards | 20 |
| Audit trail — full, point-in-time reconstructable | 15 |
| Vernacular — 3 EIPs cited, 2 GoF named, state chart, 3 Perfect Framework concerns | 25 |
| Deployed at public HTTPS URL | 10 |
| Code quality — organized, useful tests | 15 |
| Presentation + README + individual reflection | 15 |

---

## Repo info

| Item | Value |
|---|---|
| Remote | https://github.com/hiyafinch/fleet-monitor |
| Local | `C:/Users/hiyaf/OneDrive/Documents/School/Web II/fleet-monitor` |
| Sprint tag | `sprint-2-final` (apply when complete) |
| Current broker | `mqtt://test.mosquitto.org:1883` (dev) |
| Target broker | `mqtt://mqtt.uvucs.org:1883` (blocked, see open issues) |
| Latest commit | `8b8439d` — Week 3 complete, dashboard live |
