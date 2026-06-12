const VEHICLES = [
  {
    id: 'sheride-auto',
    name: 'SheRide Auto',
    icon: '🛺',
    capacity: 3,
    description: 'Budget friendly, quick rides',
    baseFare: 10,
    perKmRate: 5,
    perMinRate: 1,
    multiplier: 0.7,
    eta: '2-4 min',
  },
  {
    id: 'sheride-x',
    name: 'SheRide X',
    icon: '🚗',
    capacity: 4,
    description: 'Affordable everyday rides',
    baseFare: 20,
    perKmRate: 8,
    perMinRate: 1.5,
    multiplier: 1,
    eta: '1-3 min',
  },
  {
    id: 'sheride-xl',
    name: 'SheRide XL',
    icon: '🚙',
    capacity: 6,
    description: 'For groups up to 6',
    baseFare: 35,
    perKmRate: 14,
    perMinRate: 2.5,
    multiplier: 1.5,
    eta: '3-5 min',
  },
  {
    id: 'sheride-premium',
    name: 'SheRide Premium',
    icon: '🚘',
    capacity: 4,
    description: 'Luxury cars, top-rated drivers',
    baseFare: 50,
    perKmRate: 20,
    perMinRate: 4,
    multiplier: 2,
    eta: '4-6 min',
  },
];

function calculateFare(vehicleId, distanceKm, durationMin) {
  const v = VEHICLES.find((v) => v.id === vehicleId);
  if (!v) return null;
  const fare = v.baseFare + v.perKmRate * distanceKm + v.perMinRate * durationMin;
  return Math.round(fare);
}

module.exports = { VEHICLES, calculateFare };
