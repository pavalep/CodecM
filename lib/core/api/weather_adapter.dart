import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final double temperature;
  final String condition;
  final int weatherCode;

  const WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.weatherCode,
  });

  String get greetingText {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get summary => '${temperature.round()}°C • $condition';
}

class WeatherAdapter {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  final http.Client _client;

  WeatherAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Map WMO weather code to readable string
  static String mapWmoCode(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Misty';
    if (code >= 51 && code <= 67) return 'Rain showers';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Heavy rain';
    if (code >= 95) return 'Thunderstorm';
    return 'Breezy';
  }

  /// Get current weather for location (defaults to SF Bay Area / 37.77, -122.42)
  Future<WeatherInfo> getCurrentWeather({double latitude = 37.77, double longitude = -122.42}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,weather_code',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 18.0;
          final code = (current['weather_code'] as num?)?.toInt() ?? 1;
          return WeatherInfo(
            temperature: temp,
            condition: mapWmoCode(code),
            weatherCode: code,
          );
        }
      }
    } catch (_) {}

    return const WeatherInfo(
      temperature: 19.0,
      condition: 'Partly cloudy',
      weatherCode: 2,
    );
  }
}
