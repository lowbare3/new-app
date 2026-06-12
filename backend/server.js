const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const crypto = require('crypto');
const store = require('./store');
const { VEHICLES, calculateFare } = require('./vehicles');
const { DRIVERS, assignNearestDriver, freeDriver } = require('./drivers');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const FINDING_DRIVERS_DELAY = 6000;

const userSockets = {}; // userId -> socketId
let driverMovementIntervals = {};

io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);

  socket.on('register_user', ({ userId }) => {
    userSockets[userId] = socket.id;
    console.log(`User ${userId} registered with socket ${socket.id}`);
  });

  socket.on('disconnect', () => {
    for (const [uid, sid] of Object.entries(userSockets)) {
      if (sid === socket.id) {
        delete userSockets[uid];
        break;
      }
    }
    console.log(`Socket disconnected: ${socket.id}`);
  });
});

app.post('/api/login', (req, res) => {
  const { phone, name } = req.body;
  const id = 'u_' + crypto.randomBytes(4).toString('hex');
  const user = store.createUser(id, phone, name || '');
  res.json({ success: true, user });
});

app.get('/api/vehicles', (req, res) => {
  const { pickupLat, pickupLng, dropLat, dropLng } = req.query;
  const dist = Math.sqrt(Math.pow(parseFloat(dropLat || 0) - parseFloat(pickupLat || 0), 2) + Math.pow(parseFloat(dropLng || 0) - parseFloat(pickupLng || 0), 2)) * 111;
  const duration = dist / 0.5;
  const vehicles = VEHICLES.map((v) => ({
    ...v,
    fareEstimate: calculateFare(v.id, dist, duration),
    distanceKm: Math.round(dist * 10) / 10,
    durationMin: Math.round(duration),
  }));
  res.json({ success: true, vehicles });
});

app.post('/api/request-ride', async (req, res) => {
  const { userId, vehicleType, pickupLat, pickupLng, pickupAddress, dropLat, dropLng, dropAddress } = req.body;
  const dist = Math.sqrt(Math.pow(dropLat - pickupLat, 2) + Math.pow(dropLng - pickupLng, 2)) * 111;
  const duration = dist / 0.5;
  const fare = calculateFare(vehicleType, dist, duration);

  const rideId = 'r_' + crypto.randomBytes(6).toString('hex');
  const ride = {
    id: rideId,
    userId,
    driverId: null,
    vehicleType,
    pickupLat,
    pickupLng,
    pickupAddress,
    dropLat,
    dropLng,
    dropAddress,
    fareEstimate: fare,
    status: 'finding_driver',
  };

  store.createRide(ride);
  io.to(userSockets[userId]).emit('ride_created', ride);
  io.emit('admin_ride_update', { ...ride, userName: store.getUserByPhone(userId)?.name || '' });

  setTimeout(() => {
    const currentRide = store.getRide(rideId);
    if (!currentRide || currentRide.status === 'cancelled') return;
    io.emit('ride_awaiting_approval', { ...ride, userName: store.getUserByPhone(userId)?.name || '' });
  }, FINDING_DRIVERS_DELAY);

  res.json({ success: true, rideId, message: 'Finding drivers near you...' });
});

app.post('/api/approve-ride', (req, res) => {
  const { rideId } = req.body;
  const ride = store.getRide(rideId);
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found' });

  const driver = assignNearestDriver(ride.pickup_lat, ride.pickup_lng);
  if (!driver) {
    store.updateRideStatus(rideId, 'no_drivers');
    io.emit('ride_update', { rideId, status: 'no_drivers' });
    return res.json({ success: false, message: 'No drivers available' });
  }

  store.assignDriver(rideId, driver.id);
  store.updateRideStatus(rideId, 'driver_assigned');

  const updatedRide = store.getRide(rideId);
  io.emit('ride_update', { ...updatedRide, driver });
  io.emit('admin_ride_update', { ...updatedRide, driver, userName: store.getUserByPhone(ride.user_id)?.name || '' });

  const steps = 20;
  const intervalTime = 2000;
  let step = 0;
  const destLat = ride.pickup_lat;
  const destLng = ride.pickup_lng;
  const startLat = driver.lat;
  const startLng = driver.lng;

  if (driverMovementIntervals[rideId]) clearInterval(driverMovementIntervals[rideId]);

  driverMovementIntervals[rideId] = setInterval(() => {
    step++;
    const progress = step / steps;
    const currentLat = startLat + (destLat - startLat) * progress;
    const currentLng = startLng + (destLng - startLng) * progress;

    io.emit('driver_location', { rideId, lat: currentLat, lng: currentLng, step, totalSteps: steps });

    io.emit('admin_driver_location', { rideId, lat: currentLat, lng: currentLng });

    if (step >= steps) {
      clearInterval(driverMovementIntervals[rideId]);
      delete driverMovementIntervals[rideId];
    }
  }, intervalTime);

  res.json({ success: true, message: 'Driver assigned', driver });
});

app.post('/api/driver-arrived', (req, res) => {
  const { rideId } = req.body;
  store.updateRideStatus(rideId, 'driver_arrived');
  const ride = store.getRide(rideId);
  io.emit('ride_update', { ...ride, driver: DRIVERS.find((d) => d.id === ride.driver_id) });
  io.emit('admin_ride_update', { ...ride, driver: DRIVERS.find((d) => d.id === ride.driver_id) });
  res.json({ success: true });
});

app.post('/api/start-ride', (req, res) => {
  const { rideId } = req.body;
  store.updateRideStatus(rideId, 'in_progress');
  const ride = store.getRide(rideId);
  io.emit('ride_update', { ...ride, driver: DRIVERS.find((d) => d.id === ride.driver_id) });
  io.emit('admin_ride_update', { ...ride, driver: DRIVERS.find((d) => d.id === ride.driver_id) });
  res.json({ success: true });
});

app.post('/api/end-ride', (req, res) => {
  const { rideId } = req.body;
  store.updateRideStatus(rideId, 'completed');
  const ride = store.getRide(rideId);
  const driver = DRIVERS.find((d) => d.id === ride.driver_id);
  if (driver) freeDriver(driver.id);

  const completedData = { ...ride, driver, fare: ride.fare_estimate };
  io.emit('ride_completed', completedData);
  io.emit('admin_ride_update', { ...completedData, status: 'completed' });

  if (driverMovementIntervals[rideId]) {
    clearInterval(driverMovementIntervals[rideId]);
    delete driverMovementIntervals[rideId];
  }

  res.json({ success: true, ride: completedData });
});

app.get('/api/active-rides', (req, res) => {
  const rides = store.getActiveRides();
  const enriched = rides.map((r) => ({
    ...r,
    driver: DRIVERS.find((d) => d.id === r.driver_id) || null,
    userName: store.getUserByPhone(r.user_id)?.name || '',
  }));
  res.json({ success: true, rides: enriched });
});

app.get('/api/drivers', (req, res) => {
  res.json({ success: true, drivers: DRIVERS });
});

const PORT = process.env.PORT || 3000;
store.initDb().then(() => {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`SheRide backend running on http://localhost:${PORT}`);
  });
});
