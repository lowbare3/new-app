# SheRide - Uber Clone (Women's Pink Ride App)

## Project Structure
```
uber-clone/
├── backend/          # Node.js + Socket.IO + SQLite
├── flutter_app/      # Flutter mobile app (pink theme)
└── admin_panel/      # HTML/CSS/JS admin panel
```

## How to Run

### 1. Start Backend
```bash
cd uber-clone/backend
npm install
node server.js
```
Runs on http://localhost:3000

### 2. Run Admin Panel
Open `admin_panel/index.html` in a browser (or serve it):
```bash
npx serve admin_panel
```

### 3. Run Flutter App
```bash
cd flutter_app
flutter pub get
flutter run
```

## Flow
1. App: Login with phone + OTP (123456)
2. App: Set pickup & dropoff → select vehicle → Request Ride
3. App: Shows "Finding drivers near you..."
4. Admin: Sees request → clicks Approve
5. Backend: Assigns nearest female driver
6. App: Shows driver moving toward pickup (animated)
7. Admin: Mark Arrived → Start Ride → End Ride
8. App: Shows receipt

## Tech Stack
- Backend: Node.js, Express, Socket.IO, sql.js (SQLite)
- App: Flutter, flutter_map (OpenStreetMap)
- Admin: HTML, Leaflet.js, Socket.IO client
- All free & open source
