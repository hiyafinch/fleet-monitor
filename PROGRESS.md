# Sprint 2 Progress Tracker

Last updated: 2026-06-17

---

## Current status

**Week 3 of 4.** Demo day: June 29. Week 2 complete. 71/71 tests passing. Starting ws-bridge and dashboard.

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

### Week 2 (June 10)
- [x] Full pipeline end to end: device-sim + gateway + alert-engine live together
- [x] Clean topics confirmed: `fleet/{vehicleId}/{metric}/clean`
- [x] Alert topics confirmed: `alerts/{vehicleId}/{metric}`
- [x] Bug fixed: `lowIsBad` guards for oilPressure and fuelLevel
  - oilPressure and fuelLevel were falsely firing CRITICAL at normal values
  - Root cause: `value >= critThreshold` fires when value=45, critThreshold=15
  - Fix: `lowIsBad=true` flips all comparisons for those metrics
- [x] 32/32 tests passing (added 7 new lowIsBad direction tests)
- [x] Committed and pushed: `8260d89`

---

## What's next

### Week 2 (June 10-17)
- [x] Add `reducer.test.js` — 26 tests covering all XState transitions, sustain counter, lowIsBad, context tracking
- [x] Add `integration.test.js` — 13 tests: full in-process pipeline, Observer fan-out confirmed, event store writes, hash chain, point-in-time replay
- [x] Observer fan-out confirmed: AuditLogger and WsBridgeObserver both fire from same dispatch
- [x] Events verified writing to SQLite event store (covered by integration tests)
- [x] Bug fixed: duplicate `main()` call in `src/alert-engine/index.js`
- [x] 71/71 tests passing. Committed: `fa7589a`
- [ ] Optional: Ollama LLM summarizer (only if ahead of schedule)

### Week 3 (June 17-23)
- [ ] `ws-bridge` — Koa + secure WebSocket, bridges MQTT to browser
- [ ] Lit Element dashboard — live readings, alert state panels
- [ ] Time-travel slider — drags to any past timestamp, reconstructs fleet state
- [ ] ACK / RESOLVE controls on dashboard
- [ ] Browser reconnect handling (catch-up from event store on reconnect)

### Week 4 (June 24-29)
- [ ] Deploy to public HTTPS URL (target: June 25 — buffer for TLS issues)
- [ ] Write README (Pattern Index, state chart table, EIP citations, Perfect Framework, run instructions)
- [ ] Self-grep: confirm every pattern name in README exists as a real class in code
- [ ] Record 15-min demo video, upload to YouTube (Unlisted)
- [ ] Commit `docs/presentation.md` (presentation summary)
- [ ] Commit `sprints/sprint-2-reflection.md` (individual reflection, due 24h after demo)
- [ ] Tag commit: `sprint-2-final`
- [ ] Submit tag URL to Canvas

---

## Open issues / things to come back to

### MQTT broker (mqtt.uvucs.org) — BLOCKED
- **Status:** Times out on port 1883. Likely firewalled to UVU campus/VPN.
- **Workaround:** Using `test.mosquitto.org` for all development. Works fine.
- **What's needed:** Either UVU VPN credentials, or ask Prof. Hunter directly for broker credentials/connection instructions. No credentials found in course GitHub or assignment brief.
- **Fallback:** The rubric says "MQTT or WebSockets" — if broker stays inaccessible, ws-bridge can satisfy the pub-sub requirement over WebSockets only. Full marks still achievable.
- **Action:** Ask professor on Canvas or in Google Meet. Try UVU VPN if available.

### Sprint is listed as a Team project
- **Status:** Ethan is doing it solo.
- **Action:** Confirm with Prof. Hunter that solo submission is OK.

### CC Artifact 2 (Subagent Recipe)
- **Due:** June 8 (already past). Check Canvas to see if this was submitted or needs to catch up.

### Week 5 reflection (w05.md)
- **Due:** June 8 (already past). Check Canvas, may need to submit late.

---

## Key reminders

- Pattern names in the Pattern Index are load-bearing. Never rename `MessageRouter`, `ContentEnricher`, `MessageTranslator`, `EventDispatcher`, etc.
- Auto-grader matches pattern names to actual code. Always self-grep before submitting.
- Deploy by June 25, not June 29, to leave buffer for TLS/wss issues.
- Render free tier spins down — wake backend before demoing.
- Git Bash: type `cd` manually, do not paste multi-line commands.
- All generated files need an AI-citation comment at line 1.
- Use bash (not Write tool) for files >~6KB — Write tool pads with null bytes and truncates content.

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
| Latest commit | `fa7589a` — Week 2 complete, 71/71 tests |
