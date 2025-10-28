import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/certificate.dart';

class CertificateAnalyticsWidget extends StatelessWidget {
  final List<Certificate> certificates;
  
  const CertificateAnalyticsWidget({
    super.key,
    required this.certificates,
  });

  @override
  Widget build(BuildContext context) {
    if (certificates.isEmpty) {
      return const Center(
        child: Text(
          'Aucune donnée disponible pour l\'analyse',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre principal
          const Text(
            'Analyse des Certificats',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 20),

          // Indicateurs de pourcentage
          _buildStatusIndicators(),
          const SizedBox(height: 30),

          // Graphique en barres - Répartition par statut
          _buildStatusBarChart(),
          const SizedBox(height: 30),

          // Graphique temporel - Expirations
          _buildExpirationTimeline(),
          const SizedBox(height: 30),

          // Graphique circulaire - Types de certificats
          _buildCertificateTypePieChart(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators() {
    final now = DateTime.now();
    final activeCount = certificates.where((cert) => 
      cert.expirationDate?.isAfter(now) ?? false).length;
    final expiredCount = certificates.where((cert) => 
      cert.expirationDate?.isBefore(now) ?? false).length;
    final soonExpiring = certificates.where((cert) {
      if (cert.expirationDate == null) return false;
      final daysUntilExpiry = cert.expirationDate!.difference(now).inDays;
      return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
    }).length;

    final total = certificates.length;

    return Column(
      children: [
        const Text(
          'État des Certificats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildCircularIndicator(
                'Actifs',
                activeCount,
                total,
                Colors.green,
                Icons.check_circle,
              ),
            ),
            Expanded(
              child: _buildCircularIndicator(
                'Expire Bientôt',
                soonExpiring,
                total,
                Colors.orange,
                Icons.warning,
              ),
            ),
            Expanded(
              child: _buildCircularIndicator(
                'Expirés',
                expiredCount,
                total,
                Colors.red,
                Icons.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularIndicator(String title, int count, int total, Color color, IconData icon) {
    final percentage = total > 0 ? count / total : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 40.0,
            lineWidth: 8.0,
            percent: percentage,
            center: Icon(icon, color: color, size: 24),
            progressColor: color,
            backgroundColor: color.withValues(alpha: 0.2),
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '$count/$total',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBarChart() {
    final now = DateTime.now();
    final statusData = <String, int>{};
    
    for (final cert in certificates) {
      String status;
      if (cert.expirationDate == null) {
        status = 'Sans expiration';
      } else {
        final daysUntilExpiry = cert.expirationDate!.difference(now).inDays;
        if (daysUntilExpiry < 0) {
          status = 'Expiré';
        } else if (daysUntilExpiry <= 30) {
          status = 'Expire bientôt';
        } else {
          status = 'Actif';
        }
      }
      statusData[status] = (statusData[status] ?? 0) + 1;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition par Statut',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: statusData.values.isNotEmpty ? statusData.values.reduce((a, b) => a > b ? a : b).toDouble() + 1 : 1,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final statuses = statusData.keys.toList();
                        if (value.toInt() < statuses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              statuses[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: statusData.entries.map((entry) {
                  final index = statusData.keys.toList().indexOf(entry.key);
                  Color color;
                  switch (entry.key) {
                    case 'Actif':
                      color = Colors.green;
                      break;
                    case 'Expire bientôt':
                      color = Colors.orange;
                      break;
                    case 'Expiré':
                      color = Colors.red;
                      break;
                    default:
                      color = Colors.grey;
                  }
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        color: color,
                        width: 30,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationTimeline() {
    final now = DateTime.now();
    final timelineData = <String, int>{};
    
    for (final cert in certificates) {
      if (cert.expirationDate != null) {
        final daysUntilExpiry = cert.expirationDate!.difference(now).inDays;
        String period;
        
        if (daysUntilExpiry < 0) {
          period = 'Expiré';
        } else if (daysUntilExpiry <= 30) {
          period = '0-30 jours';
        } else if (daysUntilExpiry <= 90) {
          period = '31-90 jours';
        } else if (daysUntilExpiry <= 365) {
          period = '91-365 jours';
        } else {
          period = '+ 1 an';
        }
        
        timelineData[period] = (timelineData[period] ?? 0) + 1;
      }
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chronologie des Expirations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final periods = timelineData.keys.toList();
                        if (value.toInt() < periods.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              periods[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d), width: 1),
                ),
                minX: 0,
                maxX: timelineData.isNotEmpty ? timelineData.length - 1.0 : 0,
                minY: 0,
                maxY: timelineData.values.isEmpty ? 1 : timelineData.values.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: timelineData.entries.map((entry) {
                      final index = timelineData.keys.toList().indexOf(entry.key);
                      return FlSpot(index.toDouble(), entry.value.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateTypePieChart() {
    final typeData = <String, int>{};
    
    for (final cert in certificates) {
      final type = cert.type ?? 'Non spécifié';
      typeData[type] = (typeData[type] ?? 0) + 1;
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Types de Certificats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: typeData.entries.map((entry) {
                        final index = typeData.keys.toList().indexOf(entry.key);
                        final percentage = entry.value / certificates.length * 100;
                        
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: entry.value.toDouble(),
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: typeData.entries.map((entry) {
                      final index = typeData.keys.toList().indexOf(entry.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${entry.key} (${entry.value})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}