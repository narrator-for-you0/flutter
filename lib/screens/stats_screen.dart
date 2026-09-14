import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: const Key('stats_screen'));

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedFilter = 1; // 0: This Week, 1: This Month, 2: Last Month
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'September 2026',
                    style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Switcher
              _buildFilterSegment(),
              const SizedBox(height: 20),

              // Donut Chart Card
              _buildDonutChartCard(),
              const SizedBox(height: 16),

              // Daily Average & Purchases Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'DAILY AVERAGE',
                      value: '₱189.81',
                      subtitle: 'per active day',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'FOOD PURCHASES',
                      value: '47',
                      subtitle: 'meals & drinks',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Daily Trend Bar Chart
              _buildBarChartCard(),
              const SizedBox(height: 16),

              // Spending Breakdown List
              _buildBreakdownCard(),
              const SizedBox(height: 16),

              // Insight Banner
              _buildInsightBanner(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildFilterSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withOpacity(0.5),
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

  Widget _buildDonutChartCard() {
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
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 3,
                    centerSpaceRadius: 60,
                    sections: [
                      _pieSection(const Color(0xFF00C853), 35, 0),
                      _pieSection(const Color(0xFF6C5CE7), 29, 1),
                      _pieSection(const Color(0xFFFFA000), 17, 2),
                      _pieSection(const Color(0xFF00CEC9), 11, 3),
                      _pieSection(const Color(0xFFFF7675), 8, 4),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₱4,935.00',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap any slice to filter by category',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(Color color, double value, int index) {
    final isTouched = index == _touchedIndex;
    return PieChartSectionData(
      color: color,
      value: value,
      title: '',
      radius: isTouched ? 22 : 18,
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    final barData = [160.0, 180.0, 120.0, 210.0, 200.0, 170.0, 245.0];
    final days = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri\n(Today)'];

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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart, color: Color(0xFFFFA000), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'DAILY TREND',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Past 7 days food expense',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Today: ₱245',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 280,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        final isToday = index == 6;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? const Color(0xFF00C853) : const Color(0xFF94A3B8),
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
                barGroups: List.generate(7, (i) {
                  final isToday = i == 6;
                  final isTueWed = i == 3 || i == 4;
                  Color barColor = isToday
                      ? const Color(0xFF00C853)
                      : isTueWed
                          ? const Color(0xFFFFA000)
                          : const Color(0xFF81C784).withOpacity(0.6);

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: barData[i],
                        color: barColor,
                        width: 24,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 280,
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

  Widget _buildBreakdownCard() {
    final categories = [
      {'name': 'Lunch', 'pct': '35%', 'amt': '₱1735.00', 'color': const Color(0xFF00C853)},
      {'name': 'Dinner', 'pct': '29%', 'amt': '₱1420.00', 'color': const Color(0xFF6C5CE7)},
      {'name': 'Breakfast', 'pct': '17%', 'amt': '₱850.00', 'color': const Color(0xFFFFA000)},
      {'name': 'Drinks', 'pct': '11%', 'amt': '₱530.00', 'color': const Color(0xFF00CEC9)},
      {'name': 'Snacks', 'pct': '8%', 'amt': '₱400.00', 'color': const Color(0xFFFF7675)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text('Ranked by spending', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 12),
          ...categories.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: c['color'] as Color),
                    const SizedBox(width: 10),
                    Text(c['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    const Spacer(),
                    Text('(${c['pct']})', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                    Text(c['amt'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
        border: Border.all(color: const Color(0xFFA5D6A7).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: Color(0xFF00C853), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('You\'re doing great!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                SizedBox(height: 2),
                Text('Your food spending is 12% lower than last week. Keep it up!', style: TextStyle(fontSize: 11, color: Color(0xFF388E3C))),
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
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}