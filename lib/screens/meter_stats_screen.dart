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
                                    if (value.toInt() >= 0 && value.toInt() < _history.length) {
                                      final dateStr = _history[value.toInt()]['date'].toString().split('T')[0];
                                      final parts = dateStr.split('-');
                                      if (parts.length == 3) {
                                        return Text('${parts[2]}.${parts[1]}', style: const TextStyle(fontSize: 10));
                                      }
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
                                  final val = (e.value['reading_value'] as num).toDouble();
                                  return FlSpot(e.key.toDouble(), val);
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
                            final dateStr = item['date'].toString().split('T')[0];
                            final timeStr = item['date'].toString().split('T')[1].substring(0, 5);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.speed, color: Colors.blue),
                                title: Text('Показания: ${item['reading_value']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Дата: $dateStr в $timeStr'),
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
