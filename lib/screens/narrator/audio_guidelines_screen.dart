import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/audio_validator.dart';

/// Screen showing audio quality guidelines for narrators.
class AudioGuidelinesScreen extends StatelessWidget {
  const AudioGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text(
            'راهنمای کیفیت صدا',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Quick Requirements
              _buildSectionTitle('الزامات سریع'),
              const SizedBox(height: 12),
              _buildRequirementsCard(),
              const SizedBox(height: 24),

              // Recommended Settings
              _buildSectionTitle('تنظیمات پیشنهادی'),
              const SizedBox(height: 12),
              _buildSettingsCard(),
              const SizedBox(height: 24),

              // Why These Settings
              _buildSectionTitle('چرا این تنظیمات؟'),
              const SizedBox(height: 12),
              _buildExplanationCard(),
              const SizedBox(height: 24),

              // How to Export
              _buildSectionTitle('نحوه خروجی گرفتن'),
              const SizedBox(height: 12),
              _buildExportGuideCard(),
              const SizedBox(height: 24),

              // Tips
              _buildSectionTitle('نکات ضبط'),
              const SizedBox(height: 12),
              _buildTipsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.large,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mic,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'راهنمای گویندگان',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'برای بهترین کیفیت پخش و کمترین حجم فایل، این راهنما را دنبال کنید.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildRequirementRow(
            icon: Icons.audio_file,
            title: 'فرمت مجاز',
            value: 'MP3 یا M4A (AAC)',
            isGood: true,
          ),
          const Divider(color: AppColors.border),
          _buildRequirementRow(
            icon: Icons.storage,
            title: 'حداکثر حجم هر فصل',
            value: AudioValidator.getMaxFileSizeFormatted(),
            isGood: true,
          ),
          const Divider(color: AppColors.border),
          _buildRequirementRow(
            icon: Icons.timer,
            title: 'حداکثر مدت هر فصل',
            value: AudioValidator.getMaxDurationFormatted(),
            isGood: true,
          ),
          const Divider(color: AppColors.border),
          _buildRequirementRow(
            icon: Icons.block,
            title: 'فرمت‌های غیرمجاز',
            value: 'WAV, FLAC, OGG, AIFF',
            isGood: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isGood,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isGood ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
              borderRadius: AppRadius.small,
            ),
            child: Icon(
              icon,
              color: isGood ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGood ? Icons.check_circle : Icons.cancel,
            color: isGood ? AppColors.success : AppColors.error,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildSettingRow('فرمت خروجی', 'MP3 یا M4A (AAC)'),
          _buildSettingRow('کانال صدا', 'مونو (Mono)'),
          _buildSettingRow('نرخ نمونه‌برداری', '44100 Hz (44.1 kHz)'),
          _buildSettingRow('بیت‌ریت', '64-96 kbps'),
          _buildSettingRow('عمق بیت', '16-bit'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.small,
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'با این تنظیمات، هر ساعت صدا حدود ۳۰ مگابایت خواهد شد.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExplanationItem(
            icon: Icons.record_voice_over,
            title: 'مونو کافی است',
            description: 'کتاب صوتی فقط صدای گوینده است. استریو فقط حجم را دو برابر می‌کند.',
          ),
          const SizedBox(height: 16),
          _buildExplanationItem(
            icon: Icons.speed,
            title: 'بیت‌ریت پایین',
            description: 'صدای گفتاری با ۶۴-۹۶ kbps کیفیت عالی دارد. بیت‌ریت بالاتر فقط حجم را زیاد می‌کند.',
          ),
          const SizedBox(height: 16),
          _buildExplanationItem(
            icon: Icons.phone_android,
            title: 'سازگاری بیشتر',
            description: 'MP3 و M4A روی همه دستگاه‌ها پخش می‌شوند و برای پخش آنلاین بهینه هستند.',
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.small,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSoftwareGuide(
            name: 'Audacity',
            steps: [
              'File → Export → Export as MP3',
              'Bit Rate Mode: Constant',
              'Quality: 64-96 kbps',
              'Channel Mode: Mono',
            ],
          ),
          const Divider(color: AppColors.border, height: 32),
          _buildSoftwareGuide(
            name: 'Adobe Audition',
            steps: [
              'File → Export → File',
              'Format: MP3 Audio',
              'Sample Type: Mono',
              'Bitrate: 64-96 kbps CBR',
            ],
          ),
          const Divider(color: AppColors.border, height: 32),
          _buildSoftwareGuide(
            name: 'GarageBand',
            steps: [
              'Share → Export Song to Disk',
              'Format: MP3',
              'Quality: Good/Medium',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoftwareGuide({
    required String name,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        children: [
          _buildTipItem(
            icon: Icons.mic_external_on,
            tip: 'از میکروفون با کیفیت استفاده کنید. حتی یک هدست خوب بهتر از میکروفون داخلی است.',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.volume_off,
            tip: 'در محیط ساکت ضبط کنید. صدای پس‌زمینه کیفیت را خراب می‌کند.',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.straighten,
            tip: 'فاصله ثابت با میکروفون داشته باشید (حدود ۱۵-۲۰ سانتی‌متر).',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.water_drop,
            tip: 'آب بنوشید! خشکی گلو کیفیت صدا را کاهش می‌دهد.',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.preview,
            tip: 'قبل از آپلود، فایل را گوش کنید تا از کیفیت مطمئن شوید.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String tip,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.success, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tip,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
