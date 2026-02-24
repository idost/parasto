import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/notification_permission_service.dart';

/// Debug screen to diagnose Android notification/lockscreen issues.
/// Hidden from normal users - accessed via 7-tap on app version in Settings.
class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() => _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState extends State<NotificationDiagnosticsScreen> {
  NotificationDiagnostics? _diagnostics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final diag = await NotificationPermissionService().getNotificationDiagnostics();
      if (mounted) {
        setState(() {
          _diagnostics = diag;
          _isLoading = false;
          if (diag == null && Platform.isAndroid) {
            _error = 'Failed to get diagnostics from native';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _copyDiagnostics() {
    if (_diagnostics == null) return;

    final text = '[AUDIO_NOTIF] DIAG[MANUAL] ${_diagnostics!.toFormattedString()}';
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied to clipboard'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openChannelSettings() async {
    final opened = await NotificationPermissionService().openChannelSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open channel settings'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openAppSettings() async {
    final opened = await NotificationPermissionService().openAppNotificationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open app settings'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Notification Diagnostics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiagnostics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!Platform.isAndroid) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, size: 64, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text(
              'iOS does not require\nnotification diagnostics',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDiagnostics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_diagnostics == null) {
      return const Center(
        child: Text(
          'No diagnostics available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final diag = _diagnostics!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Health status card
        _buildHealthCard(diag),
        const SizedBox(height: 16),

        // Diagnostics values
        _buildDiagnosticsCard(diag),
        const SizedBox(height: 16),

        // Issues list (if any)
        if (diag.issues.isNotEmpty) ...[
          _buildIssuesCard(diag),
          const SizedBox(height: 16),
        ],

        // Action buttons
        _buildActionsCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHealthCard(NotificationDiagnostics diag) {
    final isHealthy = diag.isHealthy;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHealthy ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            size: 48,
            color: isHealthy ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Notifications Ready' : 'Issues Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHealthy
                      ? 'All checks passed. Notifications should work.'
                      : '${diag.issues.length} issue(s) found that may prevent notifications.',
                  style: TextStyle(
                    color: isHealthy ? AppColors.success.withValues(alpha: 0.8) : AppColors.error.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(NotificationDiagnostics diag) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Diagnostic Values',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildDiagRow('SDK Version', 'Android ${diag.sdkInt}', _getSdkIcon(diag.sdkInt)),
          _buildDiagRow('App Notifications', diag.notifEnabled ? 'Enabled' : 'DISABLED', _getBoolIcon(diag.notifEnabled)),
          _buildDiagRow('POST_NOTIFICATIONS', diag.postNotifGranted ? 'Granted' : (diag.sdkInt >= 33 ? 'NOT GRANTED' : 'N/A (SDK < 33)'), _getBoolIcon(diag.postNotifGranted || diag.sdkInt < 33)),
          _buildDiagRow('Channel Exists', diag.channelExists ? 'Yes' : 'NO', _getBoolIcon(diag.channelExists)),
          _buildDiagRow('Channel Importance', '${diag.channelImportance} (${diag.channelImportanceName})', _getImportanceIcon(diag.channelImportance)),
          _buildDiagRow('Channel Blocked', diag.channelBlocked ? 'YES' : 'No', _getBoolIcon(!diag.channelBlocked)),
          _buildDiagRow('Lockscreen Visibility', _getLockscreenVisibilityName(diag.channelLockscreenVisibility), Icons.lock_outline),
          _buildDiagRow('Can Show Badge', diag.channelCanShowBadge ? 'Yes' : 'No', Icons.badge_outlined),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, dynamic icon) {
    final iconWidget = icon is IconData
        ? Icon(icon, size: 20, color: AppColors.textTertiary)
        : icon as Widget;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 24, child: iconWidget),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getBoolIcon(bool value) {
    return Icon(
      value ? Icons.check_circle : Icons.cancel,
      size: 20,
      color: value ? AppColors.success : AppColors.error,
    );
  }

  IconData _getSdkIcon(int sdk) {
    return Icons.android;
  }

  Widget _getImportanceIcon(int importance) {
    final color = importance >= 3
        ? AppColors.success
        : importance >= 2
            ? AppColors.warning
            : AppColors.error;
    return Icon(Icons.priority_high, size: 20, color: color);
  }

  String _getLockscreenVisibilityName(int visibility) {
    switch (visibility) {
      case -1:
        return 'Default';
      case 0:
        return 'No override';
      case 1:
        return 'Private';
      case 2:
        return 'Public';
      default:
        return 'Unknown ($visibility)';
    }
  }

  Widget _buildIssuesCard(NotificationDiagnostics diag) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                SizedBox(width: 8),
                Text(
                  'Issues Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.error),
          ...diag.issues.map((issue) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.tune, color: AppColors.primary),
            title: const Text('Open Channel Settings', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('app.myna.audio', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: _openChannelSettings,
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: AppColors.primary),
            title: const Text('Open App Notification Settings', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Fallback if channel not found', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: _openAppSettings,
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.primary),
            title: const Text('Copy Diagnostics', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Copy formatted DIAG line to clipboard', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: _copyDiagnostics,
          ),
        ],
      ),
    );
  }
}
