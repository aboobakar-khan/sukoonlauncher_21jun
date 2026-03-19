import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches prayer times from the Aladhan API.
/// Handles retries, timeouts, and parsing edge cases.
class AladhanApiService {
  static const String _baseUrl = 'https://api.aladhan.com/v1';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxRetries = 2;

  /// Fetch prayer times for a specific date + location.
  /// Returns a map: { 'Fajr': 'HH:mm', 'Dhuhr': 'HH:mm', ... }
  /// Throws on network failure after retries.
  static Future<Map<String, String>> fetchPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    required DateTime date,
    int school = 0, // 0 = Shafi'i (Standard), 1 = Hanafi
  }) async {
    final dateStr = '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';

    final uri = Uri.parse('$_baseUrl/timings/$dateStr').replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': method.toString(),
        'school': school.toString(), // Add Asr calculation school
      },
    );

    Exception? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final timings = data['data']['timings'] as Map<String, dynamic>;

          // Extract the 5 mandatory prayers + Sunrise, strip timezone suffix
          return {
            'Fajr': _cleanTime(timings['Fajr'] as String),
            'Sunrise': _cleanTime(timings['Sunrise'] as String),
            'Dhuhr': _cleanTime(timings['Dhuhr'] as String),
            'Asr': _cleanTime(timings['Asr'] as String),
            'Maghrib': _cleanTime(timings['Maghrib'] as String),
            'Isha': _cleanTime(timings['Isha'] as String),
          };
        } else {
          lastError = Exception('API returned ${response.statusCode}');
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Wait before retry (exponential backoff)
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }

    throw lastError ?? Exception('Failed to fetch prayer times');
  }

  /// Fetch prayer times for a specific list of dates (batch).
  /// Returns map keyed by yyyy-MM-dd.
  /// Only fetches the given dates — caller filters out already-cached ones.
  static Future<Map<String, Map<String, String>>> fetchBatchPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    required List<DateTime> dates,
    int school = 0, // 0 = Shafi'i, 1 = Hanafi
  }) async {
    final results = <String, Map<String, String>>{};

    // Fetch sequentially to avoid rate limiting
    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final dateKey = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      try {
        results[dateKey] = await fetchPrayerTimes(
          latitude: latitude,
          longitude: longitude,
          method: method,
          date: date,
          school: school,
        );
      } catch (e) {
        // Skip failed days — will use previous cache
        continue;
      }

      // Small delay between requests to respect rate limits
      if (i < dates.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return results;
  }

  /// Aladhan sometimes returns "05:23 (EET)" — strip the timezone.
  static String _cleanTime(String raw) {
    final trimmed = raw.trim();
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0) return trimmed.substring(0, spaceIdx);
    return trimmed;
  }

  /// Available calculation methods for UI dropdown.
  static const List<Map<String, dynamic>> calculationMethods = [
    {'id': 1, 'name': 'University of Islamic Sciences, Karachi'},
    {'id': 2, 'name': 'Islamic Society of North America (ISNA)'},
    {'id': 3, 'name': 'Muslim World League (MWL)'},
    {'id': 4, 'name': 'Umm Al-Qura University, Makkah'},
    {'id': 5, 'name': 'Egyptian General Authority of Survey'},
    {'id': 7, 'name': 'Institute of Geophysics, Tehran'},
    {'id': 8, 'name': 'Gulf Region'},
    {'id': 9, 'name': 'Kuwait'},
    {'id': 10, 'name': 'Qatar'},
    {'id': 11, 'name': 'Majlis Ugama Islam Singapura'},
    {'id': 12, 'name': 'UOIF (France)'},
    {'id': 13, 'name': 'Diyanet İşleri Başkanlığı (Turkey)'},
    {'id': 14, 'name': 'Spiritual Administration of Muslims of Russia'},
    {'id': 15, 'name': 'Moonsighting Committee Worldwide'},
  ];
}
