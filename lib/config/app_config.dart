class AppConfig {
  AppConfig._(); // prevent instantiation

  /// Call once in main() before runApp() — no-op now (no API keys needed)
  static Future<void> load() async {
    // OpenStreetMap / Nominatim / OSRM require no API keys
  }
}
