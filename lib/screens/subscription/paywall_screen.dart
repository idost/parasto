// Paywall screen — shown when user needs to subscribe to access content.
//
// Purchase flow:
//   1. Screen opens → reads product from SubscriptionService (already initialized)
//   2. If product found → show price, enable purchase button
//   3. User taps "اشتراک" → SubscriptionService.purchaseSubscription()
//      which calls _iap.buyNonConsumable() (correct for iOS auto-renewable
//      subscriptions; on Android the Play Console product type determines
//      renewal behaviour)
//   4. Purchase result arrives on the purchase stream (async)
//   5. SubscriptionService fires onSubscriptionChanged → screen pops with true
//
// Diagnostics (kDebugMode only):
//   • Structured panel: store availability, queried IDs, found IDs,
//     notFoundIDs, query error
//   • "Copy Product ID" button copies com.myna.audiobook.monthly
//   • Full IAP debug log
//
// Per-state Farsi messages:
//   • Simulator detected
//   • Store not available
//   • Product not found (shows notFoundIDs if any)
//   • Purchase pending / error / cancelled

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/services/subscription_service.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';

/// Purchase stream state shown to user while transaction is in flight.
enum _PurchasePhase { idle, pending, purchasing }

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isRestoring = false;
  bool _isRetrying = false;
  _PurchasePhase _purchasePhase = _PurchasePhase.idle;
  String? _errorMessage;

  SubscriptionService get _service => ref.read(subscriptionServiceProvider);

  // ── iOS Simulator detection ──────────────────────────────────────────────
  // On simulator, SIMULATOR_DEVICE_NAME is set in the process environment.
  bool get _isSimulator {
    if (kIsWeb) return false;
    if (!Platform.isIOS) return false;
    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Register callback: when purchase stream fires success while this screen
    // is open, pop with true so the caller refreshes subscription state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.onSubscriptionChanged = () {
        if (mounted) Navigator.of(context).pop(true);
      };
    });
  }

  @override
  void dispose() {
    // Null the callback so it doesn't fire on a dead screen.
    _service.onSubscriptionChanged = null;
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _purchase() async {
    setState(() {
      _purchasePhase = _PurchasePhase.purchasing;
      _errorMessage = null;
    });

    try {
      final started = await _service.purchaseSubscription();
      if (!started && mounted) {
        // purchaseSubscription() returns false when product is null or the
        // store threw synchronously. Actual cancel/error arrive on the stream.
        setState(() {
          _purchasePhase = _PurchasePhase.idle;
          _errorMessage = 'خرید آغاز نشد. لطفاً دوباره تلاش کنید.';
        });
        return;
      }
      // Purchase launched — move to pending while waiting for stream.
      if (mounted) setState(() => _purchasePhase = _PurchasePhase.pending);
    } catch (e) {
      AppLogger.e('PaywallScreen: purchase error', error: e);
      if (mounted) {
        setState(() {
          _purchasePhase = _PurchasePhase.idle;
          _errorMessage = kDebugMode
              ? 'خطا: $e'
              : 'خطا در خرید. لطفاً دوباره تلاش کنید.';
        });
      }
    }
    // NOTE: _purchasePhase stays pending until the stream pops the screen.
    // If user cancels in the native sheet, the stream fires PurchaseStatus.canceled
    // but does NOT call onSubscriptionChanged — so we must reset state here via
    // a separate stream listener in SubscriptionService (already logs it).
    // For now, re-enable the button after a timeout so user isn't stuck.
    Future<void>.delayed(const Duration(seconds: 30), () {
      if (mounted && _purchasePhase != _PurchasePhase.idle) {
        setState(() => _purchasePhase = _PurchasePhase.idle);
      }
    });
  }

  Future<void> _restore() async {
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      final restored = await _service.restorePurchases();
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'اشتراک فعالی یافت نشد.');
      }
    } catch (e) {
      AppLogger.e('PaywallScreen: restore error', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = kDebugMode ? 'خطا در بازیابی: $e' : 'بازیابی ناموفق بود.';
        });
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });
    try {
      await _service.retryQueryProducts();
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _copyProductId() async {
    await Clipboard.setData(
      const ClipboardData(text: IAPConfig.monthlySubscriptionId),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شناسه محصول کپی شد'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the service so the UI rebuilds when retryQueryProducts() completes.
    final service = ref.watch(subscriptionServiceProvider);
    final product = service.monthlyProduct;
    final isAvailable = service.isStoreAvailable;
    final isPurchasing = _purchasePhase != _PurchasePhase.idle;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: isPurchasing ? null : () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'پارستو پریمیوم',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────
              const Center(
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'دسترسی نامحدود به تمام محتوا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'با اشتراک پارستو پریمیوم به تمام کتاب‌های صوتی، پادکست‌ها و مقالات دسترسی داشته باشید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // ── State cards (mutually exclusive) ───────────────────────

              // 1. Simulator
              if (_isSimulator)
                _StateCard(
                  icon: Icons.phonelink_off_rounded,
                  color: AppColors.warning,
                  title: 'شبیه‌ساز شناسایی شد',
                  body: 'خرید اشتراک در شبیه‌ساز iOS امکان‌پذیر نیست.\n'
                      'برای تست پرداخت از TestFlight یا sandbox روی '
                      'دستگاه واقعی استفاده کنید.',
                ),

              // 2. Store unreachable (non-simulator)
              if (!_isSimulator && !isAvailable)
                _StateCard(
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.error,
                  title: 'فروشگاه در دسترس نیست',
                  body: 'اتصال به App Store برقرار نشد.\n'
                      'اینترنت خود را بررسی کرده و دوباره تلاش کنید.',
                ),

              // 3. Product not found (store is available but returned nothing)
              if (!_isSimulator && isAvailable && product == null) ...[
                _ProductNotFoundCard(
                  notFoundIDs: service.lastNotFoundIDs,
                  queryError: service.lastQueryError,
                  onCopyId: _copyProductId,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isRetrying ? null : _retry,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    label: Text(
                      _isRetrying ? 'در حال بررسی...' : 'تلاش مجدد',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 4. Product found — show price card (happy path)
              if (product != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'اشتراک ماهانه',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.price,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'در ماه — تمدید خودکار',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 5. Purchase pending indicator
              if (_purchasePhase == _PurchasePhase.pending) ...[
                const SizedBox(height: 8),
                const _StateCard(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.primary,
                  title: 'در انتظار تأیید App Store',
                  body: 'پرداخت در حال پردازش است. لطفاً صفحه را نبندید.',
                ),
              ],

              const SizedBox(height: 16),

              // ── Error message ───────────────────────────────────────────
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.errorMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ),

              // ── Subscribe button ────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (product != null && !_isSimulator && !isPurchasing)
                      ? _purchase
                      : null,
                  icon: isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Icon(Icons.workspace_premium_rounded, size: 22),
                  label: Text(
                    _purchasePhase == _PurchasePhase.purchasing
                        ? 'در حال پردازش...'
                        : _purchasePhase == _PurchasePhase.pending
                            ? 'در انتظار تأیید...'
                            : 'اشتراک ماهانه',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    disabledBackgroundColor: AppColors.surface,
                    disabledForegroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Restore button ──────────────────────────────────────────
              TextButton(
                onPressed: (_isRestoring || isPurchasing) ? null : _restore,
                child: _isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Text(
                        'بازیابی خرید قبلی',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              // ── Legal disclaimer ────────────────────────────────────────
              const Text(
                'اشتراک به‌صورت خودکار تمدید می‌شود. '
                'می‌توانید هر زمان از تنظیمات App Store لغو کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),

              // ── Debug diagnostics panel (kDebugMode only) ───────────────
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Divider(color: AppColors.surfaceElevated),
                const SizedBox(height: 8),
                _DiagnosticsPanel(service: service, onCopyId: _copyProductId),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── State card ───────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _StateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product not found card ────────────────────────────────────────────────────

class _ProductNotFoundCard extends StatelessWidget {
  final List<String> notFoundIDs;
  final String? queryError;
  final VoidCallback onCopyId;

  const _ProductNotFoundCard({
    required this.notFoundIDs,
    required this.queryError,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the most helpful message based on what the store returned.
    // Case A: store returned notFoundIDs — ID mismatch is the likely cause.
    // Case B: store returned an error — network or agreement issue.
    // Case C: both empty — store returned nothing (Paid Apps Agreement, SK2 issue).
    final bool idMismatch = notFoundIDs.isNotEmpty;
    final bool hasError = queryError != null;

    String bodyText;
    if (idMismatch) {
      bodyText = 'شناسه‌های زیر توسط App Store تأیید نشدند:\n'
          '${notFoundIDs.join(', ')}\n\n'
          'احتمالاً شناسه محصول در App Store Connect با کد اپ مطابقت ندارد.';
    } else if (hasError) {
      bodyText = 'خطا در دریافت اطلاعات محصول.\n'
          'اینترنت خود را بررسی کرده و دوباره تلاش کنید.';
    } else {
      bodyText = 'App Store هیچ محصولی برنگرداند.\n'
          'احتمالاً قرارداد Paid Apps هنوز تکمیل نشده '
          'یا محصول در App Store Connect در حال بررسی است.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search_off_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'محصول اشتراک پیدا نشد',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bodyText,
            style: TextStyle(
              color: AppColors.warning.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Expected product ID with copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    IAPConfig.monthlySubscriptionId,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCopyId,
                  child: const Icon(
                    Icons.copy_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'این شناسه باید دقیقاً (با همین حروف) در App Store Connect ثبت شده باشد.',
            style: TextStyle(
              color: AppColors.warning.withValues(alpha: 0.7),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Debug diagnostics panel ───────────────────────────────────────────────────
// Only rendered in kDebugMode builds. Tree-shaken in release.

class _DiagnosticsPanel extends StatelessWidget {
  final SubscriptionService service;
  final VoidCallback onCopyId;

  const _DiagnosticsPanel({required this.service, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    final rows = <_DiagRow>[
      _DiagRow('store available', service.isStoreAvailable ? '✓ yes' : '✗ no'),
      _DiagRow('queried IDs', IAPConfig.productIds.join(', ')),
      _DiagRow(
        'found IDs',
        service.monthlyProduct != null
            ? service.monthlyProduct!.id
            : '(none)',
      ),
      _DiagRow(
        'notFoundIDs',
        service.lastNotFoundIDs.isEmpty
            ? '(empty)'
            : service.lastNotFoundIDs.join(', '),
      ),
      _DiagRow(
        'query error',
        service.lastQueryError ?? '(none)',
      ),
      _DiagRow(
        'monthly product',
        service.monthlyProduct != null
            ? '${service.monthlyProduct!.id} @ ${service.monthlyProduct!.price}'
            : 'null',
      ),
      _DiagRow('yearly shown', 'no — hidden by design'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'IAP Diagnostics',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onCopyId,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Copy product ID',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.key,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: TextStyle(
                          // Highlight notFoundIDs in amber if non-empty
                          color: (row.key == 'notFoundIDs' &&
                                  row.value != '(empty)')
                              ? AppColors.warning
                              : (row.key == 'query error' &&
                                      row.value != '(none)')
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                          fontSize: 9,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'IAP Debug Log',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            service.debugLog.isEmpty ? '(empty)' : service.debugLog.join('\n'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagRow {
  final String key;
  final String value;
  const _DiagRow(this.key, this.value);
}
