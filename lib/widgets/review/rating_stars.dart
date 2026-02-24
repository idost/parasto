import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showValue;
  final int? reviewCount;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.activeColor,
    this.inactiveColor,
    this.showValue = false,
    this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          Color color;
          if (rating >= starValue) {
            icon = Icons.star;
            color = activeColor ?? Colors.amber;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half;
            color = activeColor ?? Colors.amber;
          } else {
            icon = Icons.star_border;
            color = inactiveColor ?? AppColors.textTertiary;
          }
          return Icon(icon, size: size, color: color);
        }),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.85, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text('($reviewCount)', style: TextStyle(fontSize: size * 0.75, color: AppColors.textTertiary)),
        ],
      ],
    );
  }
}
