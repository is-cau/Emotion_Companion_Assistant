import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

class FortuneCalendar extends StatelessWidget {
  final List<String> checkedDates;
  const FortuneCalendar({super.key, required this.checkedDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final today = now.day;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final monthLabel = '$year年$month月';
    const weekHeaders = ['一', '二', '三', '四', '五', '六', '日'];
    final leadingBlanks = firstWeekday - 1;
    final cellSize = 32.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(monthLabel,
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 10),
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: weekHeaders.map((w) {
            return SizedBox(
              width: cellSize, height: 24,
              child: Center(
                child: Text(w,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 2),
        // Day grid
        for (int row = 0; row < 6; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final day = idx - leadingBlanks + 1;
              if (day < 1 || day > daysInMonth) {
                return SizedBox(width: cellSize, height: cellSize);
              }

              final dateStr = '$year-$month-$day';
              final checked = checkedDates.contains(dateStr);
              final isToday = day == today;
              final isFuture = DateTime(year, month, day).isAfter(DateTime(year, month, today));

              return SizedBox(
                width: cellSize, height: cellSize,
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(color: AppColors.calmGreen.withValues(alpha: 0.7), width: 1.5)
                        : null,
                    color: checked ? AppColors.calmGreen.withValues(alpha: 0.25) : null,
                  ),
                  child: Center(
                    child: Text('$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isFuture
                            ? AppColors.textHint.withValues(alpha: 0.4)
                            : checked
                                ? AppColors.calmGreen
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

        // Legend
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.calmGreen.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 6),
            Text('已签到', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(width: 16),
            Container(width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.calmGreen.withValues(alpha: 0.7), width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text('今天', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ],
    );
  }
}
