/// A coarse weather bucket, mapped from WMO weather-interpretation codes, that
/// drives the Today-screen animation, icon and label.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunder,
}

/// Current conditions for the user's location (from Open-Meteo).
class Weather {
  const Weather({required this.tempC, required this.code, required this.isDay});

  /// Temperature in degrees Celsius.
  final double tempC;

  /// Raw WMO weather code.
  final int code;

  /// Whether it's daytime at the location (drives sun-vs-moon visuals).
  final bool isDay;

  WeatherCondition get condition => weatherConditionFromCode(code);
}

/// Maps a WMO weather code to a [WeatherCondition].
/// See https://open-meteo.com/en/docs (weather_code).
WeatherCondition weatherConditionFromCode(int code) {
  switch (code) {
    case 0:
    case 1:
      return WeatherCondition.clear;
    case 2:
      return WeatherCondition.partlyCloudy;
    case 3:
      return WeatherCondition.cloudy;
    case 45:
    case 48:
      return WeatherCondition.fog;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return WeatherCondition.drizzle;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return WeatherCondition.rain;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return WeatherCondition.snow;
    case 95:
    case 96:
    case 99:
      return WeatherCondition.thunder;
    default:
      return WeatherCondition.cloudy;
  }
}
