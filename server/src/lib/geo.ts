const EARTH_RADIUS_KM = 6371;

export function haversineKm(
  a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number },
): number {
  const dLat = toRadians(b.latitude - a.latitude);
  const dLon = toRadians(b.longitude - a.longitude);
  const lat1 = toRadians(a.latitude);
  const lat2 = toRadians(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}

/**
 * Coarsen coordinates before returning them in discovery responses. Three
 * decimals is roughly 100 m, enough to help a worker judge the area without
 * exposing an exact private address.
 */
export function coarsen(value: number, decimals = 3): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

export function roundKm(value: number): number {
  return Math.round(value * 10) / 10;
}
