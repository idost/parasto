import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

/// About Parasto screen with app information and mission
class AboutParastoScreen extends StatelessWidget {
  const AboutParastoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(AppStrings.aboutParasto),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo/Name Header
              _buildHeader(),
              const SizedBox(height: 24),

              // About Section
              _buildSection(
                title: AppStrings.aboutParastoTitle,
                content: AppStrings.aboutParastoContent,
              ),
              const SizedBox(height: 20),

              // Why Parasto Section
              _buildSection(
                title: AppStrings.whyParastoTitle,
                content: AppStrings.whyParastoContent,
              ),
              const SizedBox(height: 20),

              // Features Section
              _buildFeaturesSection(),
              const SizedBox(height: 20),

              // User Upload Section
              _buildSection(
                title: AppStrings.userUploadTitle,
                content: AppStrings.userUploadContent,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Parasto Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.headphones,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.parastaAppName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.parastoTagline,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.featuresTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.featuresIntro,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          ...AppStrings.featuresList.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
