import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/expense_provider.dart';
import '../widgets/spending_calendar.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: const Key('stats_screen'));

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedFilter = 1; // 0: This Week, 1: This Month, 2: Last Month
  int _view = 0; // 0: Overview, 1: Calendar
  bool _byType =
      false; // breakdown grouping: false = subcategory, true = major type

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      backgroundColor: AppColors.bgAlt,
      body: SafeArea(
        child: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            final total = provider.getTotalSpending(_selectedFilter);
            final dailyAvg = provider.getDailyAverage(_selectedFilter);
            final breakdown = _byType
                ? provider.getTypeBreakdown(_selectedFilter)
                : provider.getCategoryBreakdown(_selectedFilter);
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
                      Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      if (_view == 0)
                        Text(
                          periodLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.faint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Overview / Calendar switch
                  _buildViewSwitch(),
                  const SizedBox(height: 16),

                  if (_view == 1)
                    const SpendingCalendar()
                  else ...[
                    // Filter Buttons
                    _buildFilterSegment(),
                    const SizedBox(height: 20),

                    // Nothing logged in this period: the charts would be a grey
                    // ring and a fake axis, so say so plainly instead. The header,
                    // view switch, and filter stay put so the user can pick
                    // another period or open the calendar.
                    if (count == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: EmptyState(
                          icon: Icons.query_stats,
                          title: 'No data for $periodLabel',
                          message:
                              'Once you log expenses in this period the donut, '
                              'trend, and category breakdown will fill in here.',
                          accent: const Color(0xFF00C853),
                          badgeColor: AppColors.greenSoft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 40,
                          ),
                        ),
                      )
                    else ...[
                      // Donut Chart Card
                      _buildDonutChartCard(total, breakdown),
                      const SizedBox(height: 16),

                      // Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'DAILY AVERAGE',
                              value: formatPeso(dailyAvg, decimals: 2),
                              subtitle: 'per active day',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'TRANSACTIONS',
                              value: '$count',
                              subtitle: 'expenses logged',
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
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Overview | Calendar
  Widget _buildViewSwitch() {
    Widget button(String label, IconData icon, int index) {
      final isSelected = _view == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _view = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? const Color(0xFF00C853) : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? AppColors.text : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.track.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          button('Overview', Icons.donut_large, 0),
          button('Calendar', Icons.calendar_month, 1),
        ],
      ),
    );
  }

  // By Category | By Type (inside the donut card)
  Widget _buildBreakdownToggle() {
    Widget chip(String label, bool value) {
      final isSelected = _byType == value;
      return GestureDetector(
        onTap: () => setState(() => _byType = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.greenSoft : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.greenDark : AppColors.faint,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [chip('By Category', false), chip('By Type', true)],
    );
  }

  Widget _buildFilterSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.track.withValues(alpha: 0.5),
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
              color: isSelected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonutChartCard(
    double total,
    List<Map<String, dynamic>> breakdown,
  ) {
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
                              color: AppColors.track,
                              value: 100,
                              title: '',
                              radius: 18,
                            ),
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
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.faint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatPeso(total, decimals: 2),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildBreakdownToggle(),
        ],
      ),
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppColors.faint),
          ),
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
                      color: AppColors.amberSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: Color(0xFFFFA000),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TREND',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        filterIndex == 0
                            ? 'Past 7 days spending'
                            : 'Weekly breakdown',
                        style: TextStyle(fontSize: 11, color: AppColors.faint),
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
                        final isLast =
                            index == labels.length - 1 && filterIndex == 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isLast
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isLast
                                  ? const Color(0xFF00C853)
                                  : AppColors.faint,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
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
                          color: AppColors.fill,
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
            children: [
              Text(
                'BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              Text(
                'Ranked by spending',
                style: TextStyle(fontSize: 11, color: AppColors.faint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'Nothing here for this period',
              message: 'Log an expense and the breakdown will fill in.',
              compact: true,
              padding: const EdgeInsets.symmetric(vertical: 16),
            )
          else
            ...breakdown.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: c['color'] as Color,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      c['name'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '(${c['pct']})',
                      style: TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPeso((c['amt'] as double), decimals: 2),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
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

  Widget _buildInsightBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoftAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA5D6A7).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: Color(0xFF00C853), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re doing great!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.greenDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Keep track of your meals and drinks to stay on budget!',
                  style: TextStyle(fontSize: 11, color: AppColors.greenDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
