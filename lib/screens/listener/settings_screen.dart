import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/utils/build_info.dart';
import 'package:myna/screens/listener/about_parasto_screen.dart';
import 'package:myna/screens/debug/notification_diagnostics_screen.dart';
import 'package:myna/providers/content_preference_provider.dart';

/// Settings keys for SharedPreferences
class SettingsKeys {
  static const String playbackSpeed = 'playback_speed';
  static const String downloadOverWifiOnly = 'download_wifi_only';
  static const String autoPlayNext = 'auto_play_next';
  static const String sleepTimerMinutes = 'sleep_timer_minutes';
  static const String skipSilence = 'skip_silence';
  static const String boostVolume = 'boost_volume';
  static const String skipForwardSeconds = 'skip_forward_seconds';
  static const String skipBackwardSeconds = 'skip_backward_seconds';
  static const String themeMode = 'theme_mode'; // 'dark', 'light', 'system'
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final double playbackSpeed;
  final bool downloadOverWifiOnly;
  final bool autoPlayNext;
  final int sleepTimerMinutes;
  final bool skipSilence;
  final bool boostVolume;
  final int skipForwardSeconds;
  final int skipBackwardSeconds;
  final String themeMode; // 'dark', 'light', 'system'
  final bool isLoading;

  const SettingsState({
    this.playbackSpeed = 1.0,
    this.downloadOverWifiOnly = true,
    this.autoPlayNext = true,
    this.sleepTimerMinutes = 0,
    this.skipSilence = false,
    this.boostVolume = false,
    this.skipForwardSeconds = 15,
    this.skipBackwardSeconds = 15,
    this.themeMode = 'dark',
    this.isLoading = true,
  });

  /// Convert stored string to Flutter ThemeMode.
  ThemeMode get resolvedThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  SettingsState copyWith({
    double? playbackSpeed,
    bool? downloadOverWifiOnly,
    bool? autoPlayNext,
    int? sleepTimerMinutes,
    bool? skipSilence,
    bool? boostVolume,
    int? skipForwardSeconds,
    int? skipBackwardSeconds,
    String? themeMode,
    bool? isLoading,
  }) {
    return SettingsState(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      downloadOverWifiOnly: downloadOverWifiOnly ?? this.downloadOverWifiOnly,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      skipSilence: skipSilence ?? this.skipSilence,
      boostVolume: boostVolume ?? this.boostVolume,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      skipBackwardSeconds: skipBackwardSeconds ?? this.skipBackwardSeconds,
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      playbackSpeed: prefs.getDouble(SettingsKeys.playbackSpeed) ?? 1.0,
      downloadOverWifiOnly: prefs.getBool(SettingsKeys.downloadOverWifiOnly) ?? true,
      autoPlayNext: prefs.getBool(SettingsKeys.autoPlayNext) ?? true,
      sleepTimerMinutes: prefs.getInt(SettingsKeys.sleepTimerMinutes) ?? 0,
      skipSilence: prefs.getBool(SettingsKeys.skipSilence) ?? false,
      boostVolume: prefs.getBool(SettingsKeys.boostVolume) ?? false,
      skipForwardSeconds: prefs.getInt(SettingsKeys.skipForwardSeconds) ?? 15,
      skipBackwardSeconds: prefs.getInt(SettingsKeys.skipBackwardSeconds) ?? 15,
      themeMode: prefs.getString(SettingsKeys.themeMode) ?? 'dark',
      isLoading: false,
    );
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(SettingsKeys.playbackSpeed, speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> setDownloadOverWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.downloadOverWifiOnly, value);
    state = state.copyWith(downloadOverWifiOnly: value);
  }

  Future<void> setAutoPlayNext(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.autoPlayNext, value);
    state = state.copyWith(autoPlayNext: value);
  }

  Future<void> setSleepTimerMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.sleepTimerMinutes, minutes);
    state = state.copyWith(sleepTimerMinutes: minutes);
  }

  Future<void> setSkipSilence(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.skipSilence, value);
    state = state.copyWith(skipSilence: value);
  }

  Future<void> setBoostVolume(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.boostVolume, value);
    state = state.copyWith(boostVolume: value);
  }

  Future<void> setSkipForwardSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.skipForwardSeconds, seconds);
    state = state.copyWith(skipForwardSeconds: seconds);
  }

  Future<void> setSkipBackwardSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.skipBackwardSeconds, seconds);
    state = state.copyWith(skipBackwardSeconds: seconds);
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsKeys.themeMode, mode);
    state = state.copyWith(themeMode: mode);
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Hidden debug mode: tap version 7 times to unlock
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  static const _tapThreshold = Duration(milliseconds: 500);
  static const _requiredTaps = 7;

  void _onVersionTap() {
    final now = DateTime.now();

    // Reset count if too much time has passed since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > _tapThreshold) {
      _versionTapCount = 0;
    }

    _lastTapTime = now;
    _versionTapCount++;

    if (_versionTapCount >= _requiredTaps) {
      _versionTapCount = 0;
      // Show Build Info screen on all platforms (replaces Android-only diagnostics)
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const BuildInfoScreen(),
        ),
      );
    } else if (_versionTapCount >= 4) {
      // Give a hint after 4 taps
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_requiredTaps - _versionTapCount} more taps to unlock build info'),
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final downloads = ref.watch(downloadProvider);

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(AppStrings.settings),
          centerTitle: true,
        ),
        body: settings.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsetsDirectional.all(16),
                children: [
                  // ── Section 1: Playback ────────────────────────────────
                  _buildSectionHeader(AppStrings.playback),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildPlaybackSpeedTile(context, settings, notifier),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSkipIntervalTile(
                      context: context,
                      icon: Icons.forward_10_rounded,
                      title: AppStrings.skipForwardInterval,
                      currentSeconds: settings.skipForwardSeconds,
                      onChanged: notifier.setSkipForwardSeconds,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSkipIntervalTile(
                      context: context,
                      icon: Icons.replay_10_rounded,
                      title: AppStrings.skipBackwardInterval,
                      currentSeconds: settings.skipBackwardSeconds,
                      onChanged: notifier.setSkipBackwardSeconds,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSwitchTile(
                      icon: Icons.skip_next_rounded,
                      title: AppStrings.autoPlayNext,
                      subtitle: AppStrings.autoPlayNextSubtitle,
                      value: settings.autoPlayNext,
                      onChanged: (value) async {
                        await notifier.setAutoPlayNext(value);
                        ref.read(audioProvider.notifier).updateAutoPlayNextCache(value);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSwitchTile(
                      icon: Icons.speed_rounded,
                      title: AppStrings.skipSilence,
                      subtitle: AppStrings.skipSilenceSubtitle,
                      value: settings.skipSilence,
                      onChanged: (value) async {
                        await notifier.setSkipSilence(value);
                        ref.read(audioProvider.notifier).setSkipSilence(value);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSwitchTile(
                      icon: Icons.volume_up_rounded,
                      title: AppStrings.boostVolume,
                      subtitle: AppStrings.boostVolumeSubtitle,
                      value: settings.boostVolume,
                      onChanged: (value) async {
                        await notifier.setBoostVolume(value);
                        ref.read(audioProvider.notifier).setBoostVolume(value);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildSleepTimerTile(context, settings, notifier),
                  ]),
                  const SizedBox(height: 24),

                  // ── Section 2: Downloads ───────────────────────────────
                  _buildSectionHeader(AppStrings.download),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildSwitchTile(
                      icon: Icons.wifi_rounded,
                      title: AppStrings.downloadWifiOnly,
                      subtitle: AppStrings.downloadWifiOnlySubtitle,
                      value: settings.downloadOverWifiOnly,
                      onChanged: notifier.setDownloadOverWifiOnly,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildStorageUsedTile(downloads),
                  ]),
                  const SizedBox(height: 24),

                  // ── Section 3: Content Preferences ─────────────────────
                  _buildSectionHeader(AppStrings.contentPreferences),
                  const SizedBox(height: 8),
                  _buildContentPreferencesCard(),
                  const SizedBox(height: 24),

                  // ── Section 4: Appearance ──────────────────────────────
                  _buildSectionHeader(AppStrings.appearance),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildThemeModeTile(context, settings, notifier),
                  ]),
                  const SizedBox(height: 24),

                  // ── Section 4: About ───────────────────────────────────
                  _buildSectionHeader(AppStrings.about),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildAboutParastoTile(context),
                    const Divider(height: 1, color: AppColors.border),
                    _buildVersionTile(),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  /// Content preference toggles for home feed filtering.
  Widget _buildContentPreferencesCard() {
    final prefs = ref.watch(contentPreferenceProvider);
    final notifier = ref.read(contentPreferenceProvider.notifier);

    return _buildCard([
      _buildContentPrefToggle(
        icon: Icons.headphones_rounded,
        title: AppStrings.showAudiobooksLabel,
        value: prefs.showAudiobooks,
        onChanged: (_) => notifier.toggle(ContentType.audiobook),
      ),
      const Divider(height: 1, color: AppColors.border),
      _buildContentPrefToggle(
        icon: Icons.podcasts_rounded,
        title: AppStrings.showPodcastsLabel,
        value: prefs.showPodcasts,
        onChanged: (_) => notifier.toggle(ContentType.podcast),
      ),
      const Divider(height: 1, color: AppColors.border),
      _buildContentPrefToggle(
        icon: Icons.article_rounded,
        title: AppStrings.showArticlesLabel,
        value: prefs.showEbooks,
        onChanged: (_) => notifier.toggle(ContentType.ebook),
      ),
      const Divider(height: 1, color: AppColors.border),
      _buildContentPrefToggle(
        icon: Icons.music_note_rounded,
        title: AppStrings.showMusicLabel,
        value: prefs.showMusic,
        onChanged: (_) => notifier.toggle(ContentType.music),
      ),
    ]);
  }

  Widget _buildContentPrefToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        AppStrings.contentPrefsSubtitle,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  /// About Parasto tile — navigates to full about page.
  Widget _buildAboutParastoTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
      title: Text(AppStrings.aboutParasto, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const AboutParastoScreen(),
          ),
        );
      },
    );
  }

  /// Version tile — shows git SHA + environment.
  /// Tap 7 times quickly to open the full Build Info screen.
  Widget _buildVersionTile() {
    return ListTile(
      leading: const Icon(Icons.verified_rounded, color: AppColors.primary),
      title: Text(AppStrings.appVersion, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        '${BuildInfo.gitSha} · ${BuildInfo.environment}',
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
      ),
      trailing: const Text(
        '1.0.0',
        style: TextStyle(color: AppColors.textTertiary),
      ),
      onTap: _onVersionTap,
    );
  }

  /// Storage used tile — shows total download size (read-only info).
  Widget _buildStorageUsedTile(DownloadState downloads) {
    final sizeText = downloads.totalSizeBytes > 0
        ? ref.read(downloadProvider.notifier).getFormattedTotalSizeFarsi()
        : AppStrings.noDownloads;

    return ListTile(
      leading: const Icon(Icons.storage_rounded, color: AppColors.primary),
      title: Text(AppStrings.storageUsed, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        sizeText,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
    );
  }

  /// Theme mode tile — segmented selector for Dark / Light / System.
  Widget _buildThemeModeTile(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    String currentLabel;
    switch (settings.themeMode) {
      case 'light':
        currentLabel = AppStrings.themeLight;
      case 'system':
        currentLabel = AppStrings.themeSystem;
      default:
        currentLabel = AppStrings.themeDark;
    }

    final themeOptions = [
      ('dark', AppStrings.themeDark),
      ('light', AppStrings.themeLight),
      ('system', AppStrings.themeSystem),
    ];

    return ListTile(
      leading: const Icon(Icons.palette_outlined, color: AppColors.primary),
      title: Text(AppStrings.themeMode, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        currentLabel,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
      onTap: () => _showSelectionSheet<String>(
        context: context,
        title: AppStrings.themeMode,
        options: themeOptions.map((o) => o.$1).toList(),
        labelBuilder: (mode) {
          for (final option in themeOptions) {
            if (option.$1 == mode) return option.$2;
          }
          return '';
        },
        currentValue: settings.themeMode,
        onSelected: notifier.setThemeMode,
      ),
    );
  }

  // ── Bottom Sheet Tiles ──────────────────────────────────────────────────

  Widget _buildPlaybackSpeedTile(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return ListTile(
      leading: const Icon(Icons.speed_rounded, color: AppColors.primary),
      title: Text(AppStrings.defaultPlaybackSpeed, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        '${settings.playbackSpeed}x',
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
      onTap: () => _showSelectionSheet<double>(
        context: context,
        title: AppStrings.playbackSpeed,
        options: speeds,
        labelBuilder: (speed) => '${speed}x',
        currentValue: settings.playbackSpeed,
        onSelected: (speed) {
          notifier.setPlaybackSpeed(speed);
          ref.read(audioProvider.notifier).updateDefaultPlaybackSpeedCache(speed);
        },
      ),
    );
  }

  Widget _buildSkipIntervalTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int currentSeconds,
    required Future<void> Function(int) onChanged,
  }) {
    final intervals = [5, 10, 15, 30, 45, 60];

    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        AppStrings.nSeconds(currentSeconds),
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
      onTap: () => _showSelectionSheet<int>(
        context: context,
        title: title,
        options: intervals,
        labelBuilder: AppStrings.nSeconds,
        currentValue: currentSeconds,
        onSelected: onChanged,
      ),
    );
  }

  Widget _buildSleepTimerTile(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    final timerOptions = [
      (0, AppStrings.off),
      (15, AppStrings.minutes15),
      (30, AppStrings.minutes30),
      (45, AppStrings.minutes45),
      (60, AppStrings.hour1),
      (90, AppStrings.hour1_5),
      (120, AppStrings.hours2),
    ];

    String currentLabel = AppStrings.off;
    for (final option in timerOptions) {
      if (option.$1 == settings.sleepTimerMinutes) {
        currentLabel = option.$2;
        break;
      }
    }

    return ListTile(
      leading: const Icon(Icons.bedtime_rounded, color: AppColors.primary),
      title: Text(AppStrings.defaultSleepTimer, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        currentLabel,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
      onTap: () => _showSelectionSheet<int>(
        context: context,
        title: AppStrings.sleepTimer,
        options: timerOptions.map((o) => o.$1).toList(),
        labelBuilder: (minutes) {
          for (final option in timerOptions) {
            if (option.$1 == minutes) return option.$2;
          }
          return '';
        },
        currentValue: settings.sleepTimerMinutes,
        onSelected: notifier.setSleepTimerMinutes,
      ),
    );
  }

  // ── Shared Bottom Sheet ─────────────────────────────────────────────────

  /// Generic selection bottom sheet. Deduplicates the speed / timer / interval
  /// sheets into one reusable method.
  void _showSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required String Function(T) labelBuilder,
    required T currentValue,
    required void Function(T) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...options.map((option) {
              final isSelected = option == currentValue;
              return ListTile(
                title: Text(
                  labelBuilder(option),
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  onSelected(option);
                  Navigator.pop(sheetContext);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Build Info Screen — shows compile-time metadata stamped via --dart-define.
// Accessible by tapping the version tile 7 times in Settings.
// This screen proves which exact commit is running on the device.
// ══════════════════════════════════════════════════════════════════════════════

class BuildInfoScreen extends StatelessWidget {
  const BuildInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <_BuildRow>[
      _BuildRow(
        icon: Icons.commit_rounded,
        label: 'Git SHA',
        value: BuildInfo.gitSha,
        highlight: !BuildInfo.isStamped,
      ),
      _BuildRow(
        icon: Icons.account_tree_rounded,
        label: 'Branch',
        value: BuildInfo.gitBranch,
      ),
      _BuildRow(
        icon: Icons.schedule_rounded,
        label: 'Build Time',
        value: BuildInfo.buildTime,
      ),
      _BuildRow(
        icon: Icons.fingerprint_rounded,
        label: 'Bundle ID',
        value: BuildInfo.bundleId,
      ),
      _BuildRow(
        icon: Icons.build_circle_rounded,
        label: 'Environment',
        value: BuildInfo.environment,
      ),
      _BuildRow(
        icon: Icons.phone_iphone_rounded,
        label: 'Platform',
        value: Platform.operatingSystem,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Build Info',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Stamp status banner ───────────────────────────────────
              if (!BuildInfo.isStamped)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Build was not stamped with git metadata.\n'
                          'Run via the flutter_run.sh script or pass --dart-define flags.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '✓ Build stamped — running from the correct repo',
                          style: TextStyle(
                            color: AppColors.success.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Info rows ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      _buildRow(context, rows[i]),
                      if (i < rows.length - 1)
                        const Divider(height: 1, color: AppColors.border, indent: 52),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Copy full summary ─────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: BuildInfo.summary));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Build info copied to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                label: const Text('Copy full summary', style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              // ── Notification Diagnostics (Android) ────────────────────
              if (Platform.isAndroid)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationDiagnosticsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.warning),
                  label: const Text('Notification Diagnostics', style: TextStyle(color: AppColors.warning)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              if (Platform.isAndroid) const SizedBox(height: 12),

              // ── Expected source of truth ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Source of truth: ~/Projects/ParastoLocal/myna_flutter\n'
                  'Bundle ID: com.myna.audiobook\n'
                  'Branch: cleanup/code-review-backup-20260201-213457',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _BuildRow row) {
    return ListTile(
      leading: Icon(row.icon, color: row.highlight ? AppColors.warning : AppColors.primary, size: 20),
      title: Text(
        row.label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      subtitle: Text(
        row.value,
        style: TextStyle(
          color: row.highlight ? AppColors.warning : AppColors.textPrimary,
          fontSize: 13,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textTertiary),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: row.value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${row.label} copied'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

class _BuildRow {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _BuildRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });
}
