const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'sheride.db');
let db;

async function initDb() {
  const SQL = await initSqlJs();
  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    db = new SQL.Database(buffer);
  } else {
    db = new SQL.Database();
  }
  db.run('CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, phone TEXT NOT NULL, name TEXT DEFAULT \'\')');
  db.run('CREATE TABLE IF NOT EXISTS rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, driver_id TEXT, vehicle_type TEXT, pickup_lat REAL, pickup_lng REAL, pickup_address TEXT, drop_lat REAL, drop_lng REAL, drop_address TEXT, fare_estimate REAL, status TEXT DEFAULT \'requested\', created_at TEXT DEFAULT (datetime(\'now\')), updated_at TEXT DEFAULT (datetime(\'now\')))');
  saveDb();
}

function saveDb() {
  const data = db.export();
  fs.writeFileSync(DB_PATH, Buffer.from(data));
}

function queryOne(sql, params) {
  const stmt = db.prepare(sql);
  if (params) stmt.bind(params);
  if (stmt.step()) {
    const cols = stmt.getColumnNames();
    const row = stmt.get();
    stmt.free();
    const obj = {};
    cols.forEach((c, i) => { obj[c] = row[i]; });
    return obj;
  }
  stmt.free();
  return null;
}

function queryAll(sql, params) {
  const results = [];
  const stmt = db.prepare(sql);
  if (params) stmt.bind(params);
  while (stmt.step()) {
    const cols = stmt.getColumnNames();
    const row = stmt.get();
    const obj = {};
    cols.forEach((c, i) => { obj[c] = row[i]; });
    results.push(obj);
  }
  stmt.free();
  return results;
}

function execute(sql, params) {
  db.run(sql, params);
  saveDb();
}

function createUser(id, phone, name) {
  execute('INSERT OR REPLACE INTO users (id, phone, name) VALUES (?, ?, ?)', [id, phone, name]);
  return { id, phone, name };
}

function getUserByPhone(phone) {
  return queryOne('SELECT * FROM users WHERE phone = ?', [phone]);
}

function createRide(ride) {
  execute('INSERT INTO rides (id, user_id, driver_id, vehicle_type, pickup_lat, pickup_lng, pickup_address, drop_lat, drop_lng, drop_address, fare_estimate, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [ride.id, ride.userId, ride.driverId, ride.vehicleType, ride.pickupLat, ride.pickupLng, ride.pickupAddress, ride.dropLat, ride.dropLng, ride.dropAddress, ride.fareEstimate, ride.status]);
  return ride;
}

function updateRideStatus(rideId, status) {
  execute("UPDATE rides SET status = ?, updated_at = datetime('now') WHERE id = ?", [status, rideId]);
}

function assignDriver(rideId, driverId) {
  execute("UPDATE rides SET driver_id = ?, status = 'driver_assigned', updated_at = datetime('now') WHERE id = ?", [driverId, rideId]);
}

function getRide(rideId) {
  return queryOne('SELECT * FROM rides WHERE id = ?', [rideId]);
}

function getActiveRides() {
  return queryAll("SELECT * FROM rides WHERE status NOT IN ('completed', 'cancelled') ORDER BY created_at DESC");
}

module.exports = { initDb, createUser, getUserByPhone, createRide, updateRideStatus, assignDriver, getRide, getActiveRides };
