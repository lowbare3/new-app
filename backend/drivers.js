const DRIVERS = [
  {
    id: 'd1',
    name: 'Priya Sharma',
    phone: '9999888811',
    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Priya',
    carModel: 'Maruti Suzuki Swift',
    carColor: 'White',
    plate: 'DL-01-AB-1234',
    rating: 4.8,
    status: 'available',
    lat: 28.6129,
    lng: 77.2295,
  },
  {
    id: 'd2',
    name: 'Ananya Patel',
    phone: '9999888822',
    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Ananya',
    carModel: 'Hyundai i20',
    carColor: 'Red',
    plate: 'DL-02-CD-5678',
    rating: 4.9,
    status: 'available',
    lat: 28.6139,
    lng: 77.2395,
  },
  {
    id: 'd3',
    name: 'Neha Gupta',
    phone: '9999888833',
    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Neha',
    carModel: 'Toyota Etios',
    carColor: 'Silver',
    plate: 'DL-03-EF-9012',
    rating: 4.7,
    status: 'available',
    lat: 28.6149,
    lng: 77.2195,
  },
  {
    id: 'd4',
    name: 'Riya Singh',
    phone: '9999888844',
    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Riya',
    carModel: 'Honda City',
    carColor: 'Black',
    plate: 'DL-04-GH-3456',
    rating: 4.6,
    status: 'available',
    lat: 28.6119,
    lng: 77.2495,
  },
  {
    id: 'd5',
    name: 'Kavita Verma',
    phone: '9999888855',
    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Kavita',
    carModel: 'Tata Nexon EV',
    carColor: 'Blue',
    plate: 'DL-05-IJ-7890',
    rating: 5.0,
    status: 'available',
    lat: 28.6159,
    lng: 77.2595,
  },
];

function getAvailableDrivers() {
  return DRIVERS.filter((d) => d.status === 'available');
}

function assignNearestDriver(pickupLat, pickupLng) {
  const available = getAvailableDrivers();
  if (available.length === 0) return null;

  let nearest = available[0];
  let minDist = Infinity;

  for (const d of available) {
    const dist = Math.sqrt(
      Math.pow(d.lat - pickupLat, 2) + Math.pow(d.lng - pickupLng, 2)
    );
    if (dist < minDist) {
      minDist = dist;
      nearest = d;
    }
  }

  nearest.status = 'busy';
  return nearest;
}

function freeDriver(driverId) {
  const d = DRIVERS.find((dr) => dr.id === driverId);
  if (d) d.status = 'available';
}

module.exports = { DRIVERS, assignNearestDriver, freeDriver, getAvailableDrivers };
