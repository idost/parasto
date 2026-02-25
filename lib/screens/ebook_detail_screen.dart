import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/ebook_providers.dart';
import 'package:myna/services/ebook_service.dart';
import 'package:myna/services/payment_service.dart';
import 'package:myna/services/access_gate_service.dart';
import 'package:myna/services/subscription_service.dart';
import 'package:myna/screens/subscription/paywall_screen.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/screens/epub_reader_screen.dart';
import 'package:myna/screens/payment/payment_success_screen.dart';
import 'package:myna/screens/payment/payment_failure_screen.dart';

/// Wrapper for swipeable ebook detail (Audible-style)
/// Pass a list of ebooks to enable swiping between them
class SwipeableEbookDetail extends StatefulWidget {
  final List<Map<String, dynamic>> ebooks;
  final int initialIndex;

  const SwipeableEbookDetail({
    super.key,
    required this.ebooks,
    this.initialIndex = 0,
  });

  @override
  State<SwipeableEbookDetail> createState() => _SwipeableEbookDetailState();
}

class _SwipeableEbookDetailState extends State<SwipeableEbookDetail> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 1.0,
    );
  }

  // Track current index for potential future use (e.g., page indicators)
  // ignore: unused_field
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.ebooks.length,
      // Allow cache of adjacent pages for faster swiping
      allowImplicitScrolling: true,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      itemBuilder: (context, index) {
        return EbookDetailScreen(
          key: ValueKey(widget.ebooks[index]['id']),
          ebook: widget.ebooks[index],
        );
      },
    );
  }
}

/// Detail screen for an ebook
class EbookDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> ebook;

  const EbookDetailScreen({
    super.key,
    required this.ebook,
  });

  @override
  ConsumerState<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends ConsumerState<EbookDetailScreen> {
  bool _isLoading = false;
  bool _isPurchasing = false;
  bool _isDescriptionExpanded = false;

  // Dynamic background color extracted from cover image (Audible-style)
  Color _dominantColor = AppColors.primary;
  bool _colorExtracted = false;

  @override
  void initState() {
    super.initState();
    _extractDominantColor();
  }

  /// Extract dominant color from cover image for dynamic background
  Future<void> _extractDominantColor() async {
    // Guard: skip if already extracted or cover URL missing
    if (_colorExtracted) return;
    if (coverUrl == null || coverUrl!.isEmpty) return;

    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(coverUrl!),
        size: const Size(100, 100), // Small size for faster processing
        maximumColorCount: 16,
      );

      // Use dominant color, or vibrant, or muted as fallback
      final color = paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          paletteGenerator.mutedColor?.color ??
          AppColors.primary;

      if (mounted) {
        setState(() {
          _dominantColor = color;
          _colorExtracted = true;
        });
      }
    } catch (e) {
      // Silently fail - use default color
      AppLogger.d('Failed to extract dominant color: $e');
    }
  }

  int get ebookId => widget.ebook['id'] as int;
  String get title => widget.ebook['title_fa'] as String? ?? '';
  String? get subtitle => widget.ebook['subtitle_fa'] as String?;
  String? get author => widget.ebook['author_fa'] as String?;
  String? get translator => widget.ebook['translator_fa'] as String?;
  String? get publisher => widget.ebook['publisher_fa'] as String?;
  String? get isbn => widget.ebook['isbn'] as String?;
  int? get publicationYear => widget.ebook['publication_year'] as int?;
  String? get description => widget.ebook['description_fa'] as String?;
  String? get coverUrl => widget.ebook['cover_url'] as String?;
  bool get isFree => widget.ebook['is_free'] as bool? ?? false;
  int get pageCount => widget.ebook['page_count'] as int? ?? 0;
  int get readCount => widget.ebook['play_count'] as int? ?? widget.ebook['read_count'] as int? ?? 0;
  double get avgRating => (widget.ebook['avg_rating'] as num?)?.toDouble() ?? 0;
  int get reviewCount => widget.ebook['review_count'] as int? ?? 0;
  int get priceToman => widget.ebook['price_toman'] as int? ?? 0;
  String? get categoryName => (widget.ebook['categories'] as Map<String, dynamic>?)?['name_fa'] as String?;

  @override
  Widget build(BuildContext context) {
    final ownershipAsync = ref.watch(ebookOwnershipProvider(ebookId));
    final progressAsync = ref.watch(readingProgressProvider(ebookId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: 420, // Increased for larger cover
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                // Use close icon instead of arrow to avoid RTL mirroring confusion
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate cover size based on screen width (55% of width, 2:3 ratio)
                  final screenWidth = constraints.maxWidth;
                  final coverWidth = screenWidth * 0.58; // 58% of screen width (larger covers)
                  final coverHeight = coverWidth * 1.4; // 2:3 aspect ratio for books

                  // Use dominant color extracted from cover (Audible-style dynamic background)
                  final bgColor = _colorExtracted ? _dominantColor : AppColors.primary;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Dynamic gradient background based on cover color
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                bgColor.withValues(alpha: 0.8),
                                bgColor.withValues(alpha: 0.4),
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      // Cover image centered
                      Center(
                        child: Container(
                          width: coverWidth,
                          height: coverHeight,
                          margin: const EdgeInsets.only(top: 36),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            // No box shadow - cleaner look without frames
                          ),
                          child: Hero(
                            tag: 'ebook_cover_${widget.ebook['id']}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: coverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: coverUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: (coverWidth * 2).toInt(),
                                      memCacheHeight: (coverHeight * 2).toInt(),
                                      placeholder: (_, __) => const ColoredBox(
                                        color: AppColors.surface,
                                        child: Center(
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            color: AppColors.textSecondary,
                                            size: 60,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const ColoredBox(
                                        color: AppColors.surface,
                                        child: Center(
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            color: AppColors.textSecondary,
                                            size: 60,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const ColoredBox(
                                      color: AppColors.surface,
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        color: AppColors.textSecondary,
                                        size: 60,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - use Center + SizedBox for true centering
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Author
                  if (author != null)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        author!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatChip(Icons.auto_stories, '${FarsiUtils.toFarsiDigits(pageCount)} صفحه'),
                      const SizedBox(width: 16),
                      _buildStatChip(Icons.visibility, FarsiUtils.toFarsiDigits(readCount)),
                      if (avgRating > 0) ...[
                        const SizedBox(width: 16),
                        _buildStatChip(Icons.star, FarsiUtils.toFarsiDigits(avgRating.toStringAsFixed(1))),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Category
                  if (categoryName != null)
                    Center(
                      child: Chip(
                        label: Text(
                          categoryName!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: AppColors.surface,
                        side: BorderSide.none,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Progress indicator (if reading)
                  progressAsync.when(
                    data: (progress) {
                      if (progress == null || progress.completionPercentage == 0) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'پیشرفت مطالعه',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${FarsiUtils.toFarsiDigits(progress.completionPercentage.toStringAsFixed(0))}٪',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress.completionPercentage / 100,
                            backgroundColor: AppColors.surface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Action buttons
                  ownershipAsync.when(
                    data: _buildActionButtons,
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _buildActionButtons(false),
                  ),

                  const SizedBox(height: 24),

                  // Description (expandable)
                  if (description != null && description!.isNotEmpty) ...[
                    const Text(
                      'درباره کتاب',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildExpandableDescription(),
                  ],

                  const SizedBox(height: 24),

                  // Metadata section
                  _buildMetadataSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isOwned) {
    // Check subscription status for free items
    final subStatusAsync = ref.watch(subscriptionStatusProvider);
    final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;
    final isSubAvailable = ref.watch(subscriptionAvailableProvider);

    final accessResult = AccessGateService.checkAccess(
      isOwned: isOwned,
      isFree: isFree,
      isSubscriptionActive: isSubActive,
      isSubscriptionAvailable: isSubAvailable,
    );

    if (accessResult.canAccess) {
      // Show read button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _startReading,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.menu_book_rounded),
          label: Text(isOwned ? 'ادامه' : 'شروع مطالعه'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Free item needs subscription
    if (accessResult.needsSubscription) {
      return Column(
        children: [
          // Badge: "رایگان با اشتراک فعال"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              AppStrings.freeWithActiveSubscription,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPaywall,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(AppStrings.subscribe),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Show purchase button
    final priceFormatted = FarsiUtils.formatPriceFarsi(priceToman);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPurchasing ? null : _purchaseEbook,
            icon: _isPurchasing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.shopping_cart),
            label: Text('خرید - $priceFormatted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sample preview button
        // NOTE: Sample preview requires either:
        // 1. A sample_epub_path field in ebooks table with first N pages extracted, OR
        // 2. Server-side EPUB extraction to generate preview on demand
        // For now, show a "coming soon" message until backend support is added.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('نمونه کتاب به زودی...'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
            icon: const Icon(Icons.preview),
            label: const Text('مشاهده نمونه'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Navigate to the paywall screen and refresh on return.
  void _showPaywall() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    ).then((subscribed) {
      if (subscribed == true && mounted) {
        ref.invalidate(ebookOwnershipProvider(ebookId));
        ref.invalidate(subscriptionStatusProvider);
        ref.invalidate(hasPremiumProvider);
      }
    });
  }

  Future<void> _startReading() async {
    setState(() => _isLoading = true);

    try {
      // Check subscription for free items before reading
      final isOwned = await EbookService().isEbookOwned(ebookId);
      if (!isOwned && isFree) {
        final service = SubscriptionService();
        final subStatus = await service.getSubscriptionStatus();
        if (!subStatus.isActive && service.isSubscriptionAvailable) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showPaywall();
          }
          return;
        }
        await EbookService().claimFreeEbook(ebookId);
      }

      // Load ebook in reader
      final success = await ref.read(ebookReaderProvider.notifier).loadEbook(widget.ebook);

      if (success && mounted) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const EpubReaderScreen(),
          ),
        );
      } else if (mounted) {
        final state = ref.read(ebookReaderProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage ?? 'خطا در بارگذاری کتاب'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _purchaseEbook() async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final paymentService = PaymentService();

      if (!paymentService.isAvailable) {
        PaymentService.showNotConfiguredDialog(context);
        return;
      }

      final result = await paymentService.processEbookPayment(
        context: context,
        ebookId: ebookId,
        ebookTitle: title,
      );

      switch (result) {
        case PaymentResult.success:
          // Invalidate ownership provider so UI updates
          ref.invalidate(ebookOwnershipProvider(ebookId));
          if (mounted) {
            // Navigate to success screen
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccessScreen(
                  audiobookTitle: title,
                  coverUrl: coverUrl,
                  priceToman: priceToman,
                  isEbook: true,
                  onGoToLibrary: () {
                    int popCount = 0;
                    Navigator.popUntil(context, (route) {
                      popCount++;
                      return popCount > 2;
                    });
                  },
                  onStartListening: () {
                    Navigator.pop(context); // Pop success screen
                    _startReading(); // Start reading
                  },
                ),
              ),
            );
          }
          break;

        case PaymentResult.cancelled:
          if (mounted) {
            final shouldRetry = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentFailureScreen(
                  audiobookTitle: title,
                  wasCancelled: true,
                  onRetry: () => Navigator.pop(context, true),
                  onBack: () => Navigator.pop(context, false),
                ),
              ),
            );
            if (shouldRetry == true && mounted) {
              _purchaseEbook();
            }
          }
          break;

        case PaymentResult.failed:
          if (mounted) {
            final shouldRetry = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentFailureScreen(
                  audiobookTitle: title,
                  wasCancelled: false,
                  onRetry: () => Navigator.pop(context, true),
                  onBack: () => Navigator.pop(context, false),
                ),
              ),
            );
            if (shouldRetry == true && mounted) {
              _purchaseEbook();
            }
          }
          break;

        case PaymentResult.notConfigured:
          if (mounted) {
            PaymentService.showNotConfiguredDialog(context);
          }
          break;

        case PaymentResult.processing:
          // Payment succeeded but webhook hasn't created entitlement yet
          if (mounted) {
            final paymentServicePoll = PaymentService();
            bool dialogClosed = false;

            PaymentService.showProcessingDialog(
              context,
              onCheckAgain: () async {
                final hasEntitlement = await paymentServicePoll.checkEbookEntitlement(ebookId);
                if (hasEntitlement && mounted) {
                  dialogClosed = true;
                  ref.invalidate(ebookOwnershipProvider(ebookId));
                }
                return hasEntitlement;
              },
            );

            // Poll automatically in the background
            final hasEntitlement = await paymentServicePoll.pollForEbookEntitlement(ebookId);
            if (mounted && !dialogClosed) {
              if (hasEntitlement) {
                Navigator.pop(context);
                ref.invalidate(ebookOwnershipProvider(ebookId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.purchaseSuccess),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            }
          }
          break;
      }
    } catch (e) {
      AppLogger.e('Ebook purchase error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Widget _buildExpandableDescription() {
    final text = description!;
    const maxLength = 200;
    final isLong = text.length > maxLength;
    final displayText = _isDescriptionExpanded || !isLong
        ? text
        : '${text.substring(0, maxLength)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.8,
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _isDescriptionExpanded ? 'نمایش کمتر' : 'نمایش بیشتر',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataSection() {
    // Collect all non-null metadata items
    final List<MapEntry<String, String>> metadataItems = [];

    if (author != null && author!.isNotEmpty) {
      metadataItems.add(MapEntry('نویسنده', author!));
    }
    if (translator != null && translator!.isNotEmpty) {
      metadataItems.add(MapEntry('مترجم', translator!));
    }
    if (publisher != null && publisher!.isNotEmpty) {
      metadataItems.add(MapEntry('ناشر', publisher!));
    }
    if (publicationYear != null) {
      metadataItems.add(MapEntry('سال انتشار', FarsiUtils.toFarsiDigits(publicationYear!)));
    }
    if (isbn != null && isbn!.isNotEmpty) {
      metadataItems.add(MapEntry('شابک', isbn!));
    }
    if (categoryName != null && categoryName!.isNotEmpty) {
      metadataItems.add(MapEntry('دسته‌بندی', categoryName!));
    }
    if (pageCount > 0) {
      metadataItems.add(MapEntry('تعداد صفحات', FarsiUtils.toFarsiDigits(pageCount)));
    }

    if (metadataItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مشخصات کتاب',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: metadataItems.asMap().entries.map((entry) {
              final isLast = entry.key == metadataItems.length - 1;
              return _buildMetadataRow(
                entry.value.key,
                entry.value.value,
                showDivider: !isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            color: AppColors.border,
            height: 1,
          ),
      ],
    );
  }
}
