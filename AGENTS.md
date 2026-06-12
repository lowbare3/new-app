# SheRide (Uber Clone)

## Structure

This repo contains three independent projects:

| Directory | Tech | Start command |
|---|---|---|
| `backend/` | Node.js + Express + Socket.IO + sql.js | `node server.js` (port 3000) |
| `flutter_app/` | Flutter + flutter_map (OpenStreetMap) | `flutter pub get && flutter run` |
| `admin_panel/` | Static HTML + Leaflet.js + Socket.IO client | `npx serve admin_panel` |

## Backend

- **No real database** — uses sql.js (SQLite compiled to WASM). File `backend/sheride.db` is created automatically on first run. Delete it to reset all data.
- **Hardcoded drivers** — 5 female drivers in `drivers.js` with static lat/lng in Delhi (around 28.61, 77.23). Status toggles between `available`/`busy` in memory.
- **Fare calculation** — in `vehicles.js`: `baseFare + perKmRate * distance + perMinRate * duration`. Distance computed via crude Euclidean approximation (no actual routing).
- **No auth** — POST `/api/login` with `{ phone, name }` creates a user on the fly. OTP is always `123456` (hardcoded in Flutter app).
- **No migration tooling** — schema is `CREATE TABLE IF NOT EXISTS` in `store.js:16-17`.

## Flutter App

- Pink theme primary color: `#E91E63` (defined in `lib/theme.dart`).
- Uses `flutter_map` (OpenStreetMap via tiles), **not** Google Maps.
- Socket.IO client connects to `http://localhost:3000` (hardcoded in `socket_service.dart`).
- No tests, no linting config, no CI.

## Admin Panel

- Must be **served** (`npx serve admin_panel`), not opened as `file://` — WebSocket and fetch won't work otherwise.
- Hardcodes `http://localhost:3000` for all API calls and Socket.IO connection.

## Ride Flow (for context)

1. Flutter app: login → set pickup/dropoff → select vehicle → Request Ride
2. Backend emits `ride_created` → 6s delay → emits `ride_awaiting_approval` to admin
3. Admin panel: Approve → backend assigns nearest available driver and animates movement (20 steps × 2s intervals)
4. Admin panel: Arrived → Start Ride → End Ride
5. Completed ride frees the driver via `freeDriver()` in `drivers.js`

## What's Not Here

- No tests, no CI, no lint/typecheck scripts, no codegen, no build pipeline. There is nothing to run before committing beyond a manual smoke test.
