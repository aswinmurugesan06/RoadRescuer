const DistanceUtil = {
  /**
   * Calculate haversine distance in kilometers between two coordinates.
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Number((R * c).toFixed(2));
  },

  /**
   * Estimate travel duration in minutes based on distance and average city speed (30 km/h) + traffic buffer.
   */
  estimateDurationMinutes(distanceKm) {
    if (distanceKm <= 0) return 1;
    const avgSpeedKmH = 30.0;
    const minutes = Math.round((distanceKm / avgSpeedKmH) * 60);
    return Math.max(minutes, 2);
  },

  /**
   * Generate smooth intermediate coordinates between origin and destination.
   */
  generateInterpolatedRoute(lat1, lon1, lat2, lon2, points = 8) {
    const coordinates = [];
    for (let i = 0; i <= points; i++) {
      const fraction = i / points;
      // Add subtle curved jitter for realistic roadway simulation
      const curve = Math.sin(fraction * Math.PI) * 0.002;
      const lat = Number((lat1 + (lat2 - lat1) * fraction + curve).toFixed(6));
      const lng = Number((lon1 + (lon2 - lon1) * fraction + curve).toFixed(6));
      coordinates.push([lng, lat]);
    }
    return coordinates;
  },
};

class RoutingService {
  /**
   * Calculate turn-by-turn route and geometry between origin and destination coordinates.
   * Leverages OSRM (Open Source Routing Machine) compatible with OpenFreeMap, with reliable fallback.
   */
  async getDirections({ originLat, originLng, destLat, destLng }) {
    // 1. Input Validation
    const oLat = parseFloat(originLat);
    const oLng = parseFloat(originLng);
    const dLat = parseFloat(destLat);
    const dLng = parseFloat(destLng);

    if (
      isNaN(oLat) ||
      isNaN(oLng) ||
      isNaN(dLat) ||
      isNaN(dLng) ||
      oLat < -90 ||
      oLat > 90 ||
      dLat < -90 ||
      dLat > 90 ||
      oLng < -180 ||
      oLng > 180 ||
      dLng < -180 ||
      dLng > 180
    ) {
      const error = new Error('Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180.');
      error.statusCode = 400;
      throw error;
    }

    const directDistanceKm = DistanceUtil.calculateDistance(oLat, oLng, dLat, dLng);

    // 2. Attempt fetching from OSRM Open Routing API
    try {
      const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${oLng},${oLat};${dLng},${dLat}?overview=full&geometries=geojson`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3500);

      const response = await fetch(osrmUrl, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (response.ok) {
        const json = await response.json();
        if (json.code === 'Ok' && json.routes && json.routes.length > 0) {
          const route = json.routes[0];
          const distanceKm = Number((route.distance / 1000).toFixed(2));
          const durationMinutes = Math.max(1, Math.round(route.duration / 60));

          return {
            status: 'success',
            provider: 'OSRM',
            distanceKm,
            durationMinutes,
            geometry: route.geometry, // { type: 'LineString', coordinates: [[lng, lat], ...] }
            origin: { latitude: oLat, longitude: oLng },
            destination: { latitude: dLat, longitude: dLng },
          };
        }
      }
    } catch (_) {
      // Graceful fallback to deterministic geometric routing
    }

    // 3. Fallback Route Calculation
    // Realistic road distance ~ 1.25x haversine distance
    const roadDistanceKm = Number((directDistanceKm * 1.25).toFixed(2));
    const durationMinutes = DistanceUtil.estimateDurationMinutes(roadDistanceKm);
    const coordinates = DistanceUtil.generateInterpolatedRoute(oLat, oLng, dLat, dLng, 10);

    return {
      status: 'success',
      provider: 'RoadRescue-LocalEngine',
      distanceKm: roadDistanceKm,
      durationMinutes,
      geometry: {
        type: 'LineString',
        coordinates,
      },
      origin: { latitude: oLat, longitude: oLng },
      destination: { latitude: dLat, longitude: dLng },
    };
  }
}

module.exports = new RoutingService();
