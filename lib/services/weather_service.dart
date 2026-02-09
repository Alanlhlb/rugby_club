import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _baseUrl =
      'https://data.weather.gov.hk/weatherAPI/opendata/weather.php';

  static const _cacheDuration = Duration(minutes: 10);
  static List<DayForecast>? _forecastCache;
  static DateTime? _forecastCacheTime;
  static CurrentWeather? _currentCache;
  static DateTime? _currentCacheTime;

  /// Get 9-day weather forecast from HKO (cached for 10 min)
  Future<List<DayForecast>> get9DayForecast() async {
    if (_forecastCache != null &&
        _forecastCacheTime != null &&
        DateTime.now().difference(_forecastCacheTime!) < _cacheDuration) {
      return _forecastCache!;
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?dataType=fnd&lang=tc'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final forecasts = data['weatherForecast'] as List;

        _forecastCache = forecasts.map((f) => DayForecast.fromJson(f)).toList();
        _forecastCacheTime = DateTime.now();
        return _forecastCache!;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get current weather (cached for 10 min)
  Future<CurrentWeather?> getCurrentWeather() async {
    if (_currentCache != null &&
        _currentCacheTime != null &&
        DateTime.now().difference(_currentCacheTime!) < _cacheDuration) {
      return _currentCache;
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?dataType=rhrread&lang=tc'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentCache = CurrentWeather.fromJson(data);
        _currentCacheTime = DateTime.now();
        return _currentCache;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get weather forecast for a specific date (within 9 days)
  Future<DayForecast?> getForecastForDate(DateTime date) async {
    final forecasts = await get9DayForecast();

    for (final forecast in forecasts) {
      if (_isSameDay(forecast.date, date)) {
        return forecast;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class DayForecast {
  final DateTime date;
  final String week;
  final String forecastWeather;
  final int forecastMinTemp;
  final int forecastMaxTemp;
  final int forecastMinRH;
  final int forecastMaxRH;
  final String forecastIcon;
  final String psr; // Probability of Significant Rain

  DayForecast({
    required this.date,
    required this.week,
    required this.forecastWeather,
    required this.forecastMinTemp,
    required this.forecastMaxTemp,
    required this.forecastMinRH,
    required this.forecastMaxRH,
    required this.forecastIcon,
    required this.psr,
  });

  factory DayForecast.fromJson(Map<String, dynamic> json) {
    // Parse date string like "20260202"
    final dateStr = json['forecastDate'] as String;
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));

    return DayForecast(
      date: DateTime(year, month, day),
      week: json['week'] ?? '',
      forecastWeather: json['forecastWeather'] ?? '',
      forecastMinTemp: json['forecastMintemp']?['value'] ?? 0,
      forecastMaxTemp: json['forecastMaxtemp']?['value'] ?? 0,
      forecastMinRH: json['forecastMinrh']?['value'] ?? 0,
      forecastMaxRH: json['forecastMaxrh']?['value'] ?? 0,
      forecastIcon: json['ForecastIcon']?.toString() ?? '',
      psr: json['PSR'] ?? '',
    );
  }

  String get temperatureRange => '$forecastMinTemp-$forecastMaxTemp°C';
  String get humidityRange => '$forecastMinRH-$forecastMaxRH%';

  String get weatherEmoji {
    // Map HKO icon numbers to emojis
    switch (forecastIcon) {
      case '50':
        return '☀️'; // Sunny
      case '51':
        return '🌤️'; // Sunny Periods
      case '52':
        return '🌥️'; // Sunny Intervals
      case '53':
        return '⛅'; // Sunny Periods with Showers
      case '54':
        return '🌦️'; // Sunny Intervals with Showers
      case '60':
        return '☁️'; // Cloudy
      case '61':
        return '🌧️'; // Overcast
      case '62':
        return '🌧️'; // Light Rain
      case '63':
        return '🌧️'; // Rain
      case '64':
        return '⛈️'; // Heavy Rain
      case '65':
        return '⛈️'; // Thunderstorms
      case '70':
        return '🌫️'; // Mist
      case '71':
        return '🌫️'; // Fog
      case '72':
        return '🌫️'; // Haze
      case '73':
        return '🌫️'; // Smog
      case '80':
        return '🌬️'; // Windy
      case '81':
        return '💨'; // Dry
      case '82':
        return '💧'; // Humid
      case '83':
        return '🥶'; // Cold
      case '84':
        return '🥵'; // Hot
      default:
        return '🌡️';
    }
  }

  bool get hasRainRisk {
    return psr == '高' || psr == '中高' || psr == '中';
  }
}

class CurrentWeather {
  final double? temperature;
  final int? humidity;
  final String? uvIndex;
  final List<String> warningMessages;

  CurrentWeather({
    this.temperature,
    this.humidity,
    this.uvIndex,
    this.warningMessages = const [],
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    double? temp;
    int? humidity;

    // Get temperature from Hong Kong Observatory
    final tempData = json['temperature']?['data'] as List?;
    if (tempData != null && tempData.isNotEmpty) {
      for (final station in tempData) {
        if (station['place'] == '香港天文台') {
          temp = (station['value'] as num?)?.toDouble();
          break;
        }
      }
      // Fallback to first station
      temp ??= (tempData.first['value'] as num?)?.toDouble();
    }

    // Get humidity
    final humidityData = json['humidity']?['data'] as List?;
    if (humidityData != null && humidityData.isNotEmpty) {
      humidity = humidityData.first['value'] as int?;
    }

    // Get warnings
    List<String> warnings = [];
    final warningMsg = json['warningMessage'];
    if (warningMsg is List) {
      warnings = warningMsg.cast<String>();
    }

    return CurrentWeather(
      temperature: temp,
      humidity: humidity,
      uvIndex: json['uvindex']?['data']?.first?['value']?.toString(),
      warningMessages: warnings,
    );
  }
}
