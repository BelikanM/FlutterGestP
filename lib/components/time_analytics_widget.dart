import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async';

class TimeAnalyticsWidget extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String title;
  
  const TimeAnalyticsWidget({
    super.key,
    this.startDate,
    this.endDate,
    this.title = 'Temps Écoulé',
  });

  @override
  TimeAnalyticsWidgetState createState() => TimeAnalyticsWidgetState();
}

class TimeAnalyticsWidgetState extends State<TimeAnalyticsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _calculateProgress(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Mise à jour en temps réel toutes les minutes
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _progressAnimation = Tween<double>(
            begin: _progressAnimation.value,
            end: _calculateProgress(),
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ));
          _animationController.reset();
          _animationController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  double _calculateProgress() {
    if (widget.startDate == null || widget.endDate == null) return 0.0;
    
    final now = DateTime.now();
    final total = widget.endDate!.difference(widget.startDate!).inMilliseconds;
    final elapsed = now.difference(widget.startDate!).inMilliseconds;
    
    if (total <= 0) return 1.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Duration _getElapsedTime() {
    if (widget.startDate == null) return Duration.zero;
    return DateTime.now().difference(widget.startDate!);
  }

  Duration _getRemainingTime() {
    if (widget.endDate == null) return Duration.zero;
    final remaining = widget.endDate!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration _getTotalTime() {
    if (widget.startDate == null || widget.endDate == null) return Duration.zero;
    return widget.endDate!.difference(widget.startDate!);
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    if (days > 0) {
      return '$days j ${hours}h ${minutes}min';
    } else if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Color _getProgressColor() {
    final progress = _calculateProgress();
    if (progress < 0.5) return Colors.green;
    if (progress < 0.8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _getElapsedTime();
    final remaining = _getRemainingTime();
    final total = _getTotalTime();
    final progress = _calculateProgress();
    final progressColor = _getProgressColor();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: progressColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Indicateur circulaire principal
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CircularPercentIndicator(
                    radius: 100.0,
                    lineWidth: 15.0,
                    percent: _progressAnimation.value,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(_progressAnimation.value * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        const Text(
                          'Écoulé',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    progressColor: progressColor,
                    backgroundColor: progressColor.withValues(alpha: 0.2),
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 1500,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Informations détaillées
          _buildTimeInfo('Temps Écoulé', elapsed, Icons.play_arrow, Colors.blue),
          const SizedBox(height: 12),
          _buildTimeInfo('Temps Restant', remaining, Icons.hourglass_empty, 
              remaining.inDays <= 7 ? Colors.red : Colors.green),
          const SizedBox(height: 12),
          _buildTimeInfo('Durée Totale', total, Icons.timer, Colors.grey),
          const SizedBox(height: 20),

          // Graphique linéaire de progression
          Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progression dans le Temps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}%',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('Début', style: TextStyle(fontSize: 10));
                              if (value == 50) return const Text('Milieu', style: TextStyle(fontSize: 10));
                              if (value == 100) return const Text('Fin', style: TextStyle(fontSize: 10));
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 100,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            const FlSpot(0, 0),
                            FlSpot(50, progress * 50),
                            FlSpot(100, progress * 100),
                          ],
                          isCurved: true,
                          color: progressColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: progressColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: progressColor.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, Duration duration, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}