import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/insights_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/progress_ring.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InsightsViewModel>();
    final courses = context.watch<CourseViewModel>();
    final i = vm.insights;
    final t = Theme.of(context);
    final s = t.colorScheme;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    if (!vm.loading && i.totalCourses == 0 && i.sessionHistory.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning progress')),
        body: const EmptyState(icon: Icons.insights_outlined, title: 'No progress yet', message: 'Add courses, assignments and study sessions to see your statistics.'),
      );
    }

    final maxMin = [...i.plannedMinutesByDay, 60].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Learning progress')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            ProgressRing(value: i.completionRate, size: 100, center: Text('${(i.completionRate * 100).round()}%', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assignment completion', style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                _Legend(AppColors.success, 'Completed', i.completed),
                _Legend(AppColors.warning, 'Pending', i.pending),
                _Legend(AppColors.danger, 'Overdue', i.overdue),
                _Legend(s.primary, 'Courses', i.totalCourses),
              ]),
            ),
          ]),
        ),
        const SectionHeader('Weekly study hours'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Fmt.hours(i.weeklyCompletedMinutes)} h done · ${Fmt.hours(i.weeklyPlannedMinutes)} h planned', style: t.textTheme.titleSmall),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: (maxMin / 60).ceilToDouble(),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: t.textTheme.labelSmall))),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(days[v.toInt() % 7], style: t.textTheme.labelMedium))),
                    ),
                  ),
                  barGroups: [
                    for (var d = 0; d < 7; d++)
                      BarChartGroupData(x: d, barRods: [
                        BarChartRodData(toY: i.plannedMinutesByDay[d] / 60, width: 10, color: s.primaryContainer, borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: i.completedMinutesByDay[d] / 60, width: 10, color: s.primary, borderRadius: BorderRadius.circular(4)),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Dot(s.primaryContainer), const Text(' Planned   '), _Dot(s.primary), const Text(' Completed'),
            ]),
          ]),
        ),
        const SectionHeader('Course progress'),
        if (i.courseProgress.isEmpty)
          const AppCard(child: Text('No courses yet.'))
        else
          for (final cp in i.courseProgress)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${cp.course.code} · ${cp.course.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall)),
                    Text('${cp.completed}/${cp.total}'),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 8, value: cp.rate)),
                ]),
              ),
            ),
        const SectionHeader('Study session history'),
        if (i.sessionHistory.isEmpty)
          const AppCard(child: Text('Mark study sessions as done in the planner to build your history.'))
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final ss in i.sessionHistory)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(ss.topic, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${courses.nameOf(ss.courseId)} · ${ss.date} · ${ss.startTime}–${ss.endTime}'),
                  trailing: Text('${Fmt.hours(ss.minutes)} h'),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _Legend(this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [_Dot(color), const SizedBox(width: 8), Expanded(child: Text(label)), Text('$value', style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
