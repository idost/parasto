import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

class RatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  const RatingInput({super.key, required this.rating, required this.onRatingChanged, this.size = 40});

  String _getLabel(int r) {
    switch (r) { case 1: return 'ضعیف'; case 2: return 'متوسط'; case 3: return 'خوب'; case 4: return 'عالی'; case 5: return 'شاهکار'; default: return ''; }
  }

  Color _getColor(int r) {
    switch (r) { case 1: return Colors.red; case 2: return Colors.orange; case 3: return Colors.amber; case 4: return Colors.lightGreen; case 5: return Colors.green; default: return AppColors.textTertiary; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) {
        final starValue = index + 1;
        final isActive = rating >= starValue;
        return GestureDetector(onTap: () => onRatingChanged(starValue),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(isActive ? Icons.star : Icons.star_border, size: size, color: isActive ? _getColor(rating) : AppColors.textTertiary)));
      })),
      if (rating > 0) ...[const SizedBox(height: 8), Text(_getLabel(rating), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _getColor(rating)))],
    ]);
  }
}
