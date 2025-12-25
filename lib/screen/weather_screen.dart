import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

const _kBgTop = Color(0xFFF8F9FA);
const _kBgMid = Color(0xFFE3F2FD);
const _kBgBot = Color(0xFFBBDEFB);
const _kPrimary = Color(0xFF2196F3);
const _kCardBg = Color(0xFFFFFFFF);

const String _weatherApiUrl = 'https://wttr.in/Nablus?format=j1&lang=ar';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _weatherData;
  List<Map<String, dynamic>>? _weeklyForecast;
  bool _loading = true;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fetchWeather();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(_weatherApiUrl);
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('انتهت مهلة الاتصال'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_condition']?[0];
        final weather = data['weather'];

        if (current != null && weather != null) {
          final forecast = <Map<String, dynamic>>[];
          for (int i = 0; i < weather.length && i < 7; i++) {
            final day = weather[i];
            final hourly = day['hourly'] as List?;

            forecast.add({
              'date': day['date'] ?? '',
              'dayName': _getDayName(day['date'] ?? '', i),
              'temp': double.tryParse(day['avgtempC'] ?? '0') ?? 0,
              'maxTemp': double.tryParse(day['maxtempC'] ?? '0') ?? 0,
              'minTemp': double.tryParse(day['mintempC'] ?? '0') ?? 0,
              'windSpeed': (double.tryParse(
                  (hourly != null && hourly.isNotEmpty)
                      ? (hourly[0]['windspeedKmph'] ?? '0')
                      : '0'
              ) ?? 0) / 3.6,
              'condition': (hourly != null && hourly.isNotEmpty)
                  ? (hourly[0]['weatherDesc']?[0]?['value'] ?? 'غير معروف')
                  : 'غير معروف',
              'icon': _getIconCode(
                  (hourly != null && hourly.isNotEmpty)
                      ? (hourly[0]['weatherCode'] ?? '113')
                      : '113'
              ),
              'uvIndex': int.tryParse(day['uvIndex'] ?? '0') ?? 0,
            });
          }

          setState(() {
            _weatherData = {
              'name': 'نابلس، فلسطين',
              'main': {
                'temp': double.tryParse(current['temp_C'] ?? '0') ?? 0,
                'feels_like': double.tryParse(current['FeelsLikeC'] ?? '0') ?? 0,
                'humidity': int.tryParse(current['humidity'] ?? '0') ?? 0,
                'pressure': int.tryParse(current['pressure'] ?? '0') ?? 0,
              },
              'weather': [{
                'main': current['weatherDesc']?[0]?['value'] ?? 'غير معروف',
                'description': current['weatherDesc']?[0]?['value'] ?? 'غير معروف',
                'icon': _getIconCode(current['weatherCode'] ?? '113'),
              }],
              'wind': {
                'speed': (double.tryParse(current['windspeedKmph'] ?? '0') ?? 0) / 3.6,
              },
              'visibility': double.tryParse(current['visibility'] ?? '10') ?? 10,
              'cloudcover': int.tryParse(current['cloudcover'] ?? '0') ?? 0,
            };
            _weeklyForecast = forecast;
            _loading = false;
          });
          _fadeController.forward();
        } else {
          throw Exception('بيانات غير صحيحة');
        }
      } else {
        throw Exception('فشل تحميل بيانات الطقس');
      }
    } catch (e) {
      _loadDemoWeather();
    }
  }

  String _getIconCode(String code) {
    final codeInt = int.tryParse(code) ?? 113;
    if (codeInt == 113) return '01d';
    if (codeInt >= 116 && codeInt <= 119) return '02d';
    if (codeInt >= 122 && codeInt <= 143) return '03d';
    if (codeInt >= 176 && codeInt <= 185) return '09d';
    if (codeInt >= 200 && codeInt <= 202) return '11d';
    if (codeInt >= 227 && codeInt <= 230) return '13d';
    return '01d';
  }

  String _getDayName(String date, int index) {
    final now = DateTime.now();
    final day = now.add(Duration(days: index));
    final weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return weekDays[day.weekday % 7];
  }

  void _loadDemoWeather() {
    final demoForecast = <Map<String, dynamic>>[];
    final weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    for (int i = 0; i < 7; i++) {
      demoForecast.add({
        'date': '',
        'dayName': weekDays[i],
        'temp': 22.0 + (i * 0.5),
        'maxTemp': 25.0 + (i * 0.5),
        'minTemp': 18.0 + (i * 0.5),
        'windSpeed': 3.0 + (i * 0.2),
        'condition': 'صافي',
        'icon': '01d',
        'uvIndex': 5,
      });
    }

    setState(() {
      _weatherData = {
        'name': 'نابلس، فلسطين',
        'main': {'temp': 22.5, 'feels_like': 21.8, 'humidity': 65, 'pressure': 1013},
        'weather': [{'main': 'Clear', 'description': 'صافي', 'icon': '01d'}],
        'wind': {'speed': 3.2},
        'visibility': 10.0,
        'cloudcover': 20,
      };
      _weeklyForecast = demoForecast;
      _loading = false;
      _error = 'لا يمكن الاتصال بالخادم - بيانات تجريبية';
    });
    _fadeController.forward();
  }

  String _getWeatherIcon(String iconCode) {
    switch (iconCode) {
      case '01d': case '01n': return '☀️';
      case '02d': case '02n': return '⛅';
      case '03d': case '03n': case '04d': case '04n': return '☁️';
      case '09d': case '09n': return '🌧️';
      case '10d': case '10n': return '🌦️';
      case '11d': case '11n': return '⛈️';
      case '13d': case '13n': return '❄️';
      case '50d': case '50n': return '🌫️';
      default: return '🌤️';
    }
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 0) return Colors.blue[300]!;
    if (temp < 10) return Colors.cyan[300]!;
    if (temp < 20) return Colors.green[300]!;
    if (temp < 30) return Colors.orange[300]!;
    return Colors.red[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_kBgTop, _kBgMid, _kBgBot],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchWeather,
          color: _kPrimary,
          backgroundColor: _kCardBg,
          child: _loading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
                const SizedBox(height: 16),
                Text(
                  'جاري تحميل بيانات الطقس...',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          )
              : FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildCurrentWeather(),
                  _buildWeeklyForecast(),
                  _buildDetailsGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on, color: _kPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weatherData?['name'] ?? 'فلسطين',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Text(
                        'وضع تجريبي',
                        style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange[800]),
                      ),
                    ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black54, size: 28),
            onPressed: _fetchWeather,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather() {
    final temp = _weatherData?['main']?['temp'] ?? 0;
    final feelsLike = _weatherData?['main']?['feels_like'] ?? 0;
    final condition = _weatherData?['weather']?[0]?['description'] ?? 'غير معروف';
    final icon = _weatherData?['weather']?[0]?['icon'] ?? '01d';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _getWeatherIcon(icon),
            style: const TextStyle(fontSize: 100),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${temp.toStringAsFixed(0)}',
                style: GoogleFonts.cairo(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: _getTemperatureColor(temp),
                  height: 1,
                ),
              ),
              Text(
                '°C',
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            condition,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الإحساس بـ ${feelsLike.toStringAsFixed(0)}°',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecast() {
    if (_weeklyForecast == null || _weeklyForecast!.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: _kPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'توقعات الأسبوع',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _weeklyForecast!.length,
            itemBuilder: (context, index) => _buildDayCard(_weeklyForecast![index], index == 0),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day, bool isToday) {
    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? _kPrimary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? _kPrimary : Colors.grey.withOpacity(0.2),
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day['dayName'] ?? '',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
              color: isToday ? _kPrimary : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _getWeatherIcon(day['icon'] ?? '01d'),
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 4),
          Column(
            children: [
              Text(
                '${(day['maxTemp'] ?? 0).toStringAsFixed(0)}°',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(day['minTemp'] ?? 0).toStringAsFixed(0)}°',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _buildDetailCard(
            icon: Icons.water_drop,
            label: 'الرطوبة',
            value: '${_weatherData?['main']?['humidity'] ?? 0}%',
            gradient: [Colors.blue[400]!, Colors.blue[600]!],
          ),
          _buildDetailCard(
            icon: Icons.air,
            label: 'الرياح',
            value: '${(_weatherData?['wind']?['speed'] ?? 0).toStringAsFixed(1)} م/ث',
            gradient: [Colors.green[400]!, Colors.green[600]!],
          ),
          _buildDetailCard(
            icon: Icons.compress,
            label: 'الضغط',
            value: '${_weatherData?['main']?['pressure'] ?? 0} hPa',
            gradient: [Colors.orange[400]!, Colors.orange[600]!],
          ),
          _buildDetailCard(
            icon: Icons.visibility,
            label: 'الرؤية',
            value: '${(_weatherData?['visibility'] ?? 0).toStringAsFixed(0)} كم',
            gradient: [Colors.purple[400]!, Colors.purple[600]!],
          ),
        ],
      ),
    );
  }
  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: gradient[0].withOpacity(0.3),
            width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: gradient[0], size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}