import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/currency_helper.dart';

final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await Supabase.instance.client.from('app_settings').select('*');
  final Map<String, dynamic> settings = {};
  for (final row in response) {
    settings[row['key'] as String] = row['value'];
  }
  return settings;
});

class AdminAppSettingsScreen extends ConsumerStatefulWidget {
  const AdminAppSettingsScreen({super.key});

  @override
  ConsumerState<AdminAppSettingsScreen> createState() => _AdminAppSettingsScreenState();
}

class _AdminAppSettingsScreenState extends ConsumerState<AdminAppSettingsScreen> {
  bool _isSaving = false;

  Future<void> _updateSetting(String key, Map<String, dynamic> value) async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': Supabase.instance.client.auth.currentUser?.id,
      });
      ref.invalidate(appSettingsProvider);
      if (mounted) _showSuccess('Settings saved');
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('App Settings'),
          centerTitle: true,
        ),
        body: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
          data: (settings) {
            final currencySettings = settings['default_currency'] as Map<String, dynamic>?;
            final defaultCurrency = (currencySettings?['code'] as String?) ?? 'USD';
            final currencySymbol = (currencySettings?['symbol'] as String?) ?? '\$';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Financial Settings'),
                _buildSettingCard(
                  icon: Icons.attach_money,
                  title: 'Default Currency',
                  subtitle: '$defaultCurrency ($currencySymbol)',
                  onTap: () => _showCurrencyDialog(currencySettings),
                ),
                _buildSettingCard(
                  icon: Icons.percent,
                  title: 'Sales Commission',
                  subtitle: '${((settings['commission_rate'] as Map<String, dynamic>?)?['percentage'] as int?) ?? 30}% per sale',
                  onTap: () => _showCommissionDialog(((settings['commission_rate'] as Map<String, dynamic>?)?['percentage'] as int?) ?? 30),
                ),
                _buildSettingCard(
                  icon: Icons.money,
                  title: 'Minimum Price',
                  subtitle: CurrencyHelper.format(
                    (((settings['min_audiobook_price'] as Map<String, dynamic>?)?['amount'] as num?) ?? 0.99).toDouble(),
                    currency: ((settings['min_audiobook_price'] as Map<String, dynamic>?)?['currency'] as String?) ?? 'USD',
                  ),
                  onTap: () => _showPriceDialog(
                    'min_audiobook_price',
                    'Minimum Price',
                    (((settings['min_audiobook_price'] as Map<String, dynamic>?)?['amount'] as num?) ?? 0.99).toDouble(),
                    ((settings['min_audiobook_price'] as Map<String, dynamic>?)?['currency'] as String?) ?? 'USD',
                  ),
                ),
                _buildSettingCard(
                  icon: Icons.money_off,
                  title: 'Maximum Price',
                  subtitle: CurrencyHelper.format(
                    (((settings['max_audiobook_price'] as Map<String, dynamic>?)?['amount'] as num?) ?? 99.99).toDouble(),
                    currency: ((settings['max_audiobook_price'] as Map<String, dynamic>?)?['currency'] as String?) ?? 'USD',
                  ),
                  onTap: () => _showPriceDialog(
                    'max_audiobook_price',
                    'Maximum Price',
                    (((settings['max_audiobook_price'] as Map<String, dynamic>?)?['amount'] as num?) ?? 99.99).toDouble(),
                    ((settings['max_audiobook_price'] as Map<String, dynamic>?)?['currency'] as String?) ?? 'USD',
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('App Information'),
                _buildSettingCard(
                  icon: Icons.email,
                  title: 'Support Email',
                  subtitle: ((settings['contact_email'] as Map<String, dynamic>?)?['value'] as String?) ?? 'support@myna.app',
                  onTap: () => _showTextDialog('contact_email', 'Support Email', ((settings['contact_email'] as Map<String, dynamic>?)?['value'] as String?) ?? ''),
                ),
                const SizedBox(height: 24),

                if (_isSaving)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _buildSettingCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: const Icon(Icons.edit, color: AppColors.textTertiary, size: 20),
    ),
  );

  Future<void> _showCurrencyDialog(Map<String, dynamic>? currentValue) async {
    final currentCode = (currentValue?['code'] as String?) ?? 'USD';
    String selectedCode = currentCode;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Default Currency', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: CurrencyHelper.getSupportedCodes().map((code) {
              final info = CurrencyHelper.getInfo(code);
              return RadioListTile<String>(
                title: Text('${info.symbol} ${info.name}', style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(code, style: const TextStyle(color: AppColors.textSecondary)),
                value: code,
                groupValue: selectedCode,
                onChanged: (value) => setState(() => selectedCode = value!),
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedCode), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != null && result != currentCode) {
      final info = CurrencyHelper.getInfo(result);
      await _updateSetting('default_currency', {
        'code': result,
        'symbol': info.symbol,
        'name': info.name,
      });
    }
  }

  Future<void> _showCommissionDialog(int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sales Commission', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Commission percentage per sale:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: '%',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? currentValue), child: const Text('Save')),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _updateSetting('commission_rate', {'percentage': result});
    }
  }

  Future<void> _showPriceDialog(String key, String title, double currentValue, String currency) async {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(2));
    final currencyInfo = CurrencyHelper.getInfo(currency);
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: currencyInfo.symbol,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text) ?? currentValue), child: const Text('Save')),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _updateSetting(key, {'amount': result, 'currency': currency});
    }
  }

  Future<void> _showTextDialog(String key, String title, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _updateSetting(key, {'value': result});
    }
  }
}