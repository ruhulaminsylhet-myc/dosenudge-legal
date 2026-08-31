/// Minimal geohash encoder — matches the encoding used by geofire-common in
/// Cloud Functions, so driver locations written here are queryable there.
class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double lat, double lng, {int precision = 9}) {
    var idx = 0;
    var bit = 0;
    var evenBit = true;
    final buffer = StringBuffer();
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;

    while (buffer.length < precision) {
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          idx = idx * 2 + 1;
          lngMin = mid;
        } else {
          idx = idx * 2;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          idx = idx * 2 + 1;
          latMin = mid;
        } else {
          idx = idx * 2;
          latMax = mid;
        }
      }
      evenBit = !evenBit;
      if (++bit == 5) {
        buffer.write(_base32[idx]);
        bit = 0;
        idx = 0;
      }
    }
    return buffer.toString();
  }
}
