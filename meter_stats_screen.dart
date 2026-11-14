import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db/database_helper.dart';

class MeterStatsScreen extends StatefulWidget {
  final int taskId;
  final String taskTitle;

  const MeterStatsScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<MeterStatsScreen> createState() => _MeterStatsScreenState();
}

class _MeterStatsScreenState extends State<MeterStatsScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'meter_readings', 
      where: 'task_id = ?', 
      whereArgs: [widget.taskId], 
      orderBy: 'date ASC'
    );
    setState(() {
      _history = maps;
      _isLoading = false;
    });
  }

  /// Безопасно разбирает дату показания: в базе может быть и ISO-строка,
  /// и простая дата без времени.
  DateTime? _parseStoredDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _formatDate(dynamic raw) {
    final date = _parseStoredDate(raw);
    if (date == null) return raw?.toString() ?? '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatTime(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (!value.contains('T')) return '';
    final date = _parseStoredDate(raw);
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Статистика: ${widget.taskTitle}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Нет данных для графика.\nВведите показания, чтобы построить график.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'График показаний',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // График
                      Expanded(
                        flex: 2,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (value == index && index >= 0 && index < _history.length) {
                                      final formatted = _formatDate(_history[index]['date']);
                                      final label = formatted.length > 5 ? formatted.substring(0, 5) : formatted;
                                      return Text(label, style: const TextStyle(fontSize: 10));
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _history.asMap().entries.map((e) {
                                  return FlSpot(e.key.toDouble(), _toDouble(e.value['reading_value']));
                                }).toList(),
                                isCurved: true,
                                color: Colors.teal,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'История показаний',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Список истории
                      Expanded(
                        flex: 3,
                        child: ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            // Показываем новые сверху
                            final item = _history[_history.length - 1 - index];
                            final dateStr = _formatDate(item['date']);
                            final timeStr = _formatTime(item['date']);
                            final reading = item['reading_value'];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.speed, color: Colors.blue),
                                title: Text('Показания: $reading', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(timeStr.isEmpty ? 'Дата: $dateStr' : 'Дата: $dateStr в $timeStr'),
                              ),
                            );

                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
