import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/listener/category_screen.dart';
import 'package:myna/screens/listener/categories_list_screen.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/section_header.dart';

/// Section displaying category chips in a horizontal list.
class CategoriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const CategoriesSection({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.categories,
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CategoriesListScreen()),
            );
          },
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return CategoryChip(
                key: ValueKey(cat['id']),
                category: cat,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Category chip with colored dot indicator.
class CategoryChip extends StatelessWidget {
  final Map<String, dynamic> category;

  const CategoryChip({super.key, required this.category});

  Color _getCategoryColor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('رمان') || lowerName.contains('داستان')) {
      return const Color(0xFFE57373);
    } else if (lowerName.contains('تاریخ')) {
      return const Color(0xFFFFB74D);
    } else if (lowerName.contains('روانشناسی') || lowerName.contains('خودیاری')) {
      return const Color(0xFF81C784);
    } else if (lowerName.contains('فلسفه') || lowerName.contains('علمی')) {
      return const Color(0xFF64B5F6);
    } else if (lowerName.contains('کودک')) {
      return const Color(0xFFBA68C8);
    } else if (lowerName.contains('شعر') || lowerName.contains('ادبیات')) {
      return const Color(0xFFFFD54F);
    } else if (lowerName.contains('مذهب') || lowerName.contains('دینی')) {
      return const Color(0xFF4DD0E1);
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final name = (category['name_fa'] as String?) ?? '';
    final color = _getCategoryColor(name);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CategoryScreen(
                  categoryId: category['id'] as int,
                  categoryName: AppStrings.localize(name),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.localize(name),
                  style: AppTypography.chip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
