import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/expense_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: const Key('stats_screen'));

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedFilter = 1; // 0: This Week, 1: This Month, 2: Last Month

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            final total = provider.getTotalSpending(_selectedFilter);
            final dailyAvg = provider.getDailyAverage(_selectedFilter);
            final breakdown = provider.getCategoryBreakdown(_selectedFilter);
            final barData = provider.getBarChartData(_selectedFilter);
            final count = provider.getFilteredExpenses(_selectedFilter).length;
            final periodLabel = provider.getPeriodLabel(_selectedFilter);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with dynamic date label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        periodLabel,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Buttons
                  _buildFilterSegment(),
                  const SizedBox(height: 20),

                  // Donut Chart Card
                  _buildDonutChartCard(total, breakdown),
                  const SizedBox(height: 16),

                  // Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'DAILY AVERAGE',
                          value: '₱${dailyAvg.toStringAsFixed(2)}',
                          subtitle: 'per active day',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'FOOD PURCHASES',
                          value: '$count',
                          subtitle: 'meals & drinks',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Bar Chart Card
                  _buildBarChartCard(barData, _selectedFilter),
                  const SizedBox(height: 16),

                  // Category Breakdown
                  _buildBreakdownCard(breakdown),
                  const SizedBox(height: 16),

                  // Insight Banner
                  _buildInsightBanner(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildFilterButton('This Week', 0),
          _buildFilterButton('This Month', 1),
          _buildFilterButton('Last Month', 2),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonutChartCard(double total, List<Map<String, dynamic>> breakdown) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    // Disabled touch interactions to prevent web mouse_tracker errors
                    pieTouchData: PieTouchData(enabled: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 60,
                    sections: breakdown.isEmpty
                        ? [
                            PieChartSectionData(
                              color: const Color(0xFFE2E8F0),
                              value: 100,
                              title: '',
                              radius: 18,
                            )
                          ]
                        : breakdown.map((item) {
                            return PieChartSectionData(
                              color: item['color'] as Color,
                              value: item['amt'] as double,
                              title: '',
                              radius: 18,
                            );
                          }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('₱${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Category Overview',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      {required String title, required String value, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8))),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildBarChartCard(List<double> barData, int filterIndex) {
    final labels = filterIndex == 0
        ? ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri\n(Today)']
        : ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];

    final maxVal = barData.isEmpty
        ? 300.0
        : barData.reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.bar_chart,
                        color: Color(0xFFFFA000), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TREND',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                      Text(
                        filterIndex == 0
                            ? 'Past 7 days food expense'
                            : 'Weekly breakdown',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal == 0 ? 100 : maxVal,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final isLast = index == labels.length - 1 && filterIndex == 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isLast ? FontWeight.bold : FontWeight.normal,
                              color: isLast
                                  ? const Color(0xFF00C853)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(barData.length, (i) {
                  final isLast = i == barData.length - 1 && filterIndex == 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: barData[i],
                        color: isLast
                            ? const Color(0xFF00C853)
                            : const Color(0xFF81C784).withValues(alpha: 0.6),
                        width: 24,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal == 0 ? 100 : maxVal,
                          color: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(List<Map<String, dynamic>> breakdown) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('BREAKDOWN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              Text('Ranked by spending',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No expenses recorded for this period',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ...breakdown.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      CircleAvatar(
                          radius: 5, backgroundColor: c['color'] as Color),
                      const SizedBox(width: 10),
                      Text(c['name'] as String,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B))),
                      const Spacer(),
                      Text('(${c['pct']})',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 8),
                      Text('₱${(c['amt'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildInsightBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: Color(0xFF00C853), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('You\'re doing great!',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
                SizedBox(height: 2),
                Text('Keep track of your meals and drinks to stay on budget!',
                    style: TextStyle(fontSize: 11, color: Color(0xFF388E3C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ],
    );
  }
}