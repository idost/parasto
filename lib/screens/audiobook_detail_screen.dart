import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:myna/widgets/common/optimized_cover_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/services/purchase_service.dart';
import 'package:myna/services/payment_service.dart';
import 'package:myna/services/access_gate_service.dart';
import 'package:myna/services/subscription_service.dart';
import 'package:myna/screens/subscription/paywall_screen.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/services/wishlist_service.dart';
import 'package:myna/services/book_summary_service.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/widgets/audiobook_detail/author_follow_button.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/screens/player/player_screen.dart';
import 'package:myna/screens/listener/write_review_screen.dart';
import 'package:myna/screens/listener/reviews_screen.dart';
import 'package:myna/screens/listener/music_screen.dart';
import 'package:myna/screens/support/create_ticket_screen.dart';
import 'package:myna/widgets/review/rating_stars.dart';
import 'package:myna/widgets/review/review_card.dart';
import 'package:myna/widgets/content_type_badge.dart';
import 'package:myna/widgets/error_view.dart';
import 'package:myna/widgets/mini_player.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/screens/payment/payment_success_screen.dart';
import 'package:myna/screens/payment/payment_failure_screen.dart';
import 'package:myna/screens/listener/library_screen.dart' show ownedBooksWithProgressProvider, ownedItemsWithProgressProvider, ContentType;
import 'package:myna/screens/creator/creator_profile_screen.dart';

class AudiobookDetailScreen extends ConsumerStatefulWidget {
  final int audiobookId;

  const AudiobookDetailScreen({super.key, required this.audiobookId});

  @override
  ConsumerState<AudiobookDetailScreen> createState() => _AudiobookDetailScreenState();
}

class _AudiobookDetailScreenState extends ConsumerState<AudiobookDetailScreen> {
  Map<String, dynamic>? _audiobook;
  List<Map<String, dynamic>> _chapters = [];
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _metadata; // book_metadata or music_metadata
  List<Map<String, dynamic>> _creators = []; // Creator profiles linked to this audiobook
  List<Map<String, dynamic>> _musicCategories = []; // Music categories for this album
  bool _isLoading = true;
  bool _isOwned = false;
  bool _isPurchasing = false;
  bool _isInWishlist = false;
  bool _isTogglingWishlist = false;
  String? _errorMessage;
  Color? _dominantCoverColor; // Extracted from cover art via palette_generator

  // Chapter list expansion state
  bool _chaptersExpanded = false;
  static const int _initialChapterCount = 5;

  // Description expansion state
  bool _descriptionExpanded = false;

  // AI Summary state
  String? _aiSummary;
  bool _isLoadingSummary = false;
  bool _summaryError = false;
  bool _summaryRateLimited = false;
  String? _summaryErrorDetails;

  // Related books state (Audible-style recommendations)
  List<Map<String, dynamic>> _moreFromAuthor = [];
  List<Map<String, dynamic>> _youMayAlsoEnjoy = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final supabase = Supabase.instance.client;

      // PERFORMANCE: Run audiobook + chapters + reviews queries in parallel
      // Include FULL book_metadata and music_metadata to avoid separate fetch
      // (not profiles which is the uploader account, not the actual narrator/artist)
      final basicDataFutures = await Future.wait([
        supabase
            .from('audiobooks')
            .select('*, categories(name_fa), book_metadata(*), music_metadata(*)')
            .eq('id', widget.audiobookId)
            .maybeSingle(),
        supabase
            .from('chapters')
            .select('*')
            .eq('audiobook_id', widget.audiobookId)
            .order('chapter_index', ascending: true),
        supabase
            .from('reviews')
            .select('*, profiles(display_name, avatar_url)')
            .eq('audiobook_id', widget.audiobookId)
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(3),
      ]);

      final audiobook = basicDataFutures[0] as Map<String, dynamic>?;
      final chapters = basicDataFutures[1] as List;
      final reviews = basicDataFutures[2] as List;

      // Handle case where audiobook doesn't exist or isn't accessible
      if (audiobook == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'کتاب صوتی یافت نشد';
          });
        }
        return;
      }

      // FIX: Free books still need an entitlement to appear in library.
      // User must explicitly "claim" free books by tapping the button.
      // This creates a proper entitlement row which the library query uses.
      // We always check for entitlement, regardless of is_free status.
      bool owned = false;
      Map<String, dynamic>? progress;
      bool inWishlist = false;

      // PERFORMANCE: Run user-specific queries in parallel if user is logged in
      if (user != null) {
        // Start all futures simultaneously
        // Always check for entitlement (free or paid - both need entitlements for library)
        final entitlementFuture = supabase
                .from('entitlements')
                .select('id')
                .eq('user_id', user.id)
                .eq('audiobook_id', widget.audiobookId)
                .maybeSingle();

        final progressFuture = supabase
            .from('listening_progress')
            .select('*')
            .eq('user_id', user.id)
            .eq('audiobook_id', widget.audiobookId)
            .maybeSingle();

        final wishlistFuture = ref.read(wishlistServiceProvider).isInWishlist(widget.audiobookId.toString());

        // Wait for all results (they run in parallel)
        final results = await (entitlementFuture, progressFuture, wishlistFuture).wait;

        // User owns if they have an entitlement (from purchase or free claim)
        if (results.$1 != null) {
          owned = true;
        }
        progress = results.$2;
        inWishlist = results.$3;
      }

      // PERFORMANCE: Use metadata from JOIN instead of separate fetch
      // The audiobook query now includes book_metadata(*) and music_metadata(*)
      final contentType = (audiobook['content_type'] as String?) ?? 'audiobook';
      final isMusic = contentType == 'music';
      Map<String, dynamic>? metadata;
      if (isMusic) {
        metadata = audiobook['music_metadata'] as Map<String, dynamic>?;
      } else {
        metadata = audiobook['book_metadata'] as Map<String, dynamic>?;
      }

      // Fetch linked creators (from creators table via audiobook_creators)
      // This is optional - if no creators are linked, we fall back to legacy fields
      List<Map<String, dynamic>> creators = [];
      try {
        creators = await CreatorService().getCreatorsForAudiobook(widget.audiobookId);
      } catch (e) {
        AppLogger.e('Failed to fetch creators', error: e);
      }

      // Fetch music categories (if music)
      List<Map<String, dynamic>> musicCategories = [];
      if (isMusic) {
        try {
          final categoriesResult = await supabase
              .from('audiobook_music_categories')
              .select('music_category_id, music_categories(id, name_fa, icon)')
              .eq('audiobook_id', widget.audiobookId);

          musicCategories = List<Map<String, dynamic>>.from(categoriesResult);
        } catch (e) {
          AppLogger.e('Failed to fetch music categories', error: e);
        }
      }

      // Fetch "More from Author" and "You May Also Enjoy" recommendations (in parallel)
      List<Map<String, dynamic>> moreFromAuthor = [];
      List<Map<String, dynamic>> youMayAlsoEnjoy = [];

      try {
        final authorFa = audiobook['author_fa'] as String?;
        final authorEn = audiobook['author_en'] as String?;
        final categoryId = audiobook['category_id'] as int?;

        // Build futures for parallel execution
        final futures = <Future<List<dynamic>>>[];

        // More from Author query (if author exists)
        if ((authorFa != null && authorFa.isNotEmpty) || (authorEn != null && authorEn.isNotEmpty)) {
          String authorFilter = '';
          if (authorFa != null && authorFa.isNotEmpty) {
            authorFilter = 'author_fa.eq.$authorFa';
          }
          if (authorEn != null && authorEn.isNotEmpty) {
            if (authorFilter.isNotEmpty) {
              authorFilter += ',author_en.eq.$authorEn';
            } else {
              authorFilter = 'author_en.eq.$authorEn';
            }
          }
          futures.add(
            supabase
                .from('audiobooks')
                .select('id, title_fa, cover_url, author_fa, avg_rating, is_free, price_toman')
                .eq('status', 'approved')
                .eq('content_type', contentType)
                .or(authorFilter)
                .neq('id', widget.audiobookId)
                .order('avg_rating', ascending: false)
                .limit(10),
          );
        } else {
          futures.add(Future.value(<dynamic>[]));
        }

        // You May Also Enjoy query (if category exists)
        if (categoryId != null) {
          futures.add(
            supabase
                .from('audiobooks')
                .select('id, title_fa, cover_url, author_fa, avg_rating, is_free, price_toman')
                .eq('status', 'approved')
                .eq('content_type', contentType)
                .eq('category_id', categoryId)
                .neq('id', widget.audiobookId)
                .order('avg_rating', ascending: false)
                .limit(10),
          );
        } else {
          futures.add(Future.value(<dynamic>[]));
        }

        final results = await Future.wait(futures);
        moreFromAuthor = List<Map<String, dynamic>>.from(results[0]);
        youMayAlsoEnjoy = List<Map<String, dynamic>>.from(results[1]);

        // Filter out duplicates from "You May Also Enjoy" that are already in "More from Author"
        final authorBookIds = moreFromAuthor.map((b) => b['id'] as int).toSet();
        youMayAlsoEnjoy = youMayAlsoEnjoy.where((b) => !authorBookIds.contains(b['id'])).toList();
      } catch (e) {
        AppLogger.e('Failed to fetch related books', error: e);
        // Continue without recommendations - not critical
      }

      if (mounted) {
        setState(() {
          _audiobook = audiobook;
          _chapters = List<Map<String, dynamic>>.from(chapters);
          _isOwned = owned;
          _progress = progress;
          _reviews = List<Map<String, dynamic>>.from(reviews);
          _metadata = metadata;
          _creators = creators;
          _musicCategories = musicCategories;
          _isInWishlist = inWishlist;
          _moreFromAuthor = moreFromAuthor;
          _youMayAlsoEnjoy = youMayAlsoEnjoy;
          _isLoading = false;
        });

        // Extract dominant color from cover art for the hero background.
        // Runs after setState so the screen is visible immediately; a second
        // setState fires once the color is ready, causing a smooth transition.
        final coverUrl = audiobook['cover_url'] as String?;
        if (coverUrl != null && coverUrl.isNotEmpty && _dominantCoverColor == null) {
          PaletteGenerator.fromImageProvider(
            NetworkImage(coverUrl),
            maximumColorCount: 20,
          ).then((palette) {
            if (mounted) {
              setState(() {
                _dominantCoverColor =
                    palette.darkVibrantColor?.color ??
                    palette.vibrantColor?.color ??
                    palette.dominantColor?.color;
              });
            }
          }).catchError((_) {
            // Palette extraction is best-effort — ignore errors
          });
        }
      }
    } on PostgrestException catch (e) {
      AppLogger.e('Supabase error loading audiobook details', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطا در دریافت اطلاعات کتاب';
        });
      }
    } catch (e) {
      AppLogger.e('Error loading audiobook details', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isNetworkError(e)
              ? 'خطا در اتصال به اینترنت'
              : 'خطا در بارگذاری اطلاعات';
        });
      }
    }
  }

  bool _isNetworkError(dynamic e) {
    final message = e.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('timeout');
  }

  Future<void> _toggleWishlist() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای افزودن به علاقه‌مندی‌ها وارد شوید')),
      );
      return;
    }

    setState(() => _isTogglingWishlist = true);
    try {
      final wishlistService = ref.read(wishlistServiceProvider);
      await wishlistService.toggleWishlist(widget.audiobookId.toString());
      if (mounted) {
        setState(() {
          _isInWishlist = !_isInWishlist;
          _isTogglingWishlist = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInWishlist ? 'به علاقه‌مندی‌ها اضافه شد' : 'از علاقه‌مندی‌ها حذف شد'),
            backgroundColor: _isInWishlist ? AppColors.success : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingWishlist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در به‌روزرسانی علاقه‌مندی‌ها'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _purchase() async {
    if (_audiobook == null) return;

    final isFree = _audiobook!['is_free'] == true;
    final priceToman = (_audiobook!['price_toman'] as int?) ?? 0;
    final title = (_audiobook!['title_fa'] as String?) ?? '';
    final coverUrl = _audiobook!['cover_url'] as String?;

    // Guard free content: require subscription before claiming
    if (isFree) {
      final subStatusAsync = ref.read(subscriptionStatusProvider);
      final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;
      if (!isSubActive) {
        _showPaywall();
        return;
      }
    }

    setState(() => _isPurchasing = true);

    try {
      if (isFree) {
        // Free books (subscription verified above) - simple flow
        final purchaseService = PurchaseService(Supabase.instance.client);
        final result = await purchaseService.purchaseAudiobook(
          context: context,
          audiobookId: widget.audiobookId,
          priceToman: priceToman,
          isFree: isFree,
        );

        switch (result) {
          case PurchaseResult.success:
            setState(() => _isOwned = true);
            // OWNERSHIP SYNC: Update audio provider if this book is currently playing
            ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(widget.audiobookId);
            // Invalidate library cache so the new book appears
            // Must invalidate BOTH the family provider and legacy provider
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.articles));
            ref.invalidate(ownedBooksWithProgressProvider);  // Legacy
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کتاب به کتابخانه شما اضافه شد'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
            break;
          case PurchaseResult.paymentRequired:
            // This shouldn't happen for free books, but handle it gracefully
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('این کتاب رایگان نیست'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
            break;
          case PurchaseResult.cancelled:
            // User cancelled - no message needed
            break;
          case PurchaseResult.error:
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('خطا در افزودن کتاب. لطفاً دوباره تلاش کنید.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            break;
        }
      } else {
        // Paid books - use full payment flow with screens
        final paymentService = PaymentService();

        if (!paymentService.isAvailable) {
          PaymentService.showNotConfiguredDialog(context);
          return;
        }

        final result = await paymentService.processPayment(
          context: context,
          audiobookId: widget.audiobookId,
          audiobookTitle: title,
          ref: ref,  // Pass ref to suspend audio updates during payment
        );

        switch (result) {
          case PaymentResult.success:
            setState(() => _isOwned = true);
            // OWNERSHIP SYNC: Update audio provider if this book is currently playing
            ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(widget.audiobookId);
            // Invalidate BOTH the family provider (used by LibraryScreen) and legacy provider
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.articles));
            ref.invalidate(ownedBooksWithProgressProvider);  // Legacy
            if (mounted) {
              // Navigate to success screen
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentSuccessScreen(
                    audiobookTitle: title,
                    coverUrl: coverUrl,
                    priceToman: priceToman,
                    onGoToLibrary: () {
                      // Invalidate library cache so the new book appears
                      ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
                      ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
                      ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
                      ref.invalidate(ownedItemsWithProgressProvider(ContentType.articles));
                      ref.invalidate(ownedBooksWithProgressProvider);
                      // FIX: Use popUntil to safely pop multiple screens at once
                      // This avoids _debugLocked error from calling pop() twice synchronously
                      int popCount = 0;
                      Navigator.popUntil(context, (route) {
                        popCount++;
                        return popCount > 2; // Pop success screen + detail screen
                      });
                    },
                    onStartListening: () {
                      Navigator.pop(context); // Pop success screen
                      _playAudiobook(); // Start playing
                    },
                  ),
                ),
              );
            }
            break;
          case PaymentResult.cancelled:
            // Show cancelled screen with retry option
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
                _purchase(); // Retry purchase
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
                _purchase(); // Retry purchase
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
            // Show processing dialog with "Check Again" button
            if (mounted) {
              final paymentServicePoll = PaymentService();
              final audiobookId = widget.audiobookId;

              // Track if dialog was already closed by manual "Check Again" success
              bool dialogClosed = false;

              // Show dialog with manual retry capability
              PaymentService.showProcessingDialog(
                context,
                onCheckAgain: () async {
                  // Check for entitlement
                  final hasEntitlement = await paymentServicePoll.checkEntitlement(audiobookId);
                  if (hasEntitlement && mounted) {
                    dialogClosed = true; // Dialog will close itself on success
                    setState(() => _isOwned = true);
                    // OWNERSHIP SYNC: Update audio provider if this book is currently playing
                    ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(audiobookId);
                    // Invalidate library providers
                    ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
                    ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
                    ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
                    ref.invalidate(ownedBooksWithProgressProvider);
                  }
                  return hasEntitlement;
                },
              );

              // Also poll automatically in the background
              final hasEntitlement = await paymentServicePoll.pollForEntitlement(audiobookId);
              if (mounted && !dialogClosed) {
                if (hasEntitlement) {
                  // SUCCESS: Close dialog and update UI
                  Navigator.pop(context);
                  setState(() => _isOwned = true);
                  // OWNERSHIP SYNC: Update audio provider if this book is currently playing
                  ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(audiobookId);
                  // FIX: Invalidate ALL library providers (family + legacy)
                  ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
                  ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
                  ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
                  ref.invalidate(ownedBooksWithProgressProvider);  // Legacy
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.purchaseSuccess),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                // IMPORTANT: If entitlement NOT found, do NOT close the dialog!
                // User can click "Check Again" manually. The dialog stays open.
                // This fixes the issue where purchase button reappears after payment.
              }
            }
            break;
        }
      }
    } catch (e) {
      AppLogger.e('Purchase error', error: e);
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

  void _playAudiobook({int chapterIndex = 0, int? seekTo}) async {
    if (_audiobook == null) return;

    final isFree = _audiobook!['is_free'] == true;

    // Check access gate before playing free content
    if (isFree && !_isOwned) {
      final subStatusAsync = ref.read(subscriptionStatusProvider);
      final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;
      final isSubAvailable = ref.read(subscriptionAvailableProvider);

      // Check if this specific chapter is a preview (previews always play)
      final isPreview = chapterIndex < _chapters.length &&
          _chapters[chapterIndex]['is_preview'] == true;

      final accessResult = AccessGateService.checkAccess(
        isOwned: _isOwned,
        isFree: isFree,
        isSubscriptionActive: isSubActive,
        isSubscriptionAvailable: isSubAvailable,
        isPreviewContent: isPreview,
      );

      if (!accessResult.canAccess) {
        // Free content locked — show paywall
        _showPaywall();
        return;
      }

      // Subscription active — auto-claim for library
      AppLogger.i('Auto-claiming free audiobook ${widget.audiobookId} on play');
      final purchaseService = PurchaseService(Supabase.instance.client);
      final result = await purchaseService.purchaseAudiobook(
        context: context,
        audiobookId: widget.audiobookId,
        priceToman: 0,
        isFree: true,
      );
      if (result == PurchaseResult.success) {
        setState(() => _isOwned = true);
        ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(widget.audiobookId);
        ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
        ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
        ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
        ref.invalidate(ownedItemsWithProgressProvider(ContentType.articles));
        ref.invalidate(ownedBooksWithProgressProvider);
        AppLogger.i('Free audiobook claimed successfully');
      }
    }

    // Pass subscription state to audio_provider for chapter-level gating
    final subStatusAsync = ref.read(subscriptionStatusProvider);
    final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;

    ref.read(audioProvider.notifier).play(
      audiobook: _audiobook!,
      chapters: _chapters,
      chapterIndex: chapterIndex,
      seekTo: seekTo,
      isOwned: _isOwned,
      isSubscriptionActive: isSubActive,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          audiobook: _audiobook!,
          chapters: _chapters,
          initialChapterIndex: chapterIndex,
          playbackAlreadyStarted: true, // We already called play() above
        ),
      ),
    ).then((_) => _loadData());
  }

  void _reportIssue() {
    if (_audiobook == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای ارسال گزارش وارد شوید')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateTicketScreen(
          audiobookId: widget.audiobookId,
          audiobookTitle: (_audiobook!['title_fa'] as String?) ?? '',
        ),
      ),
    );
  }

  int _calculateTotalDuration() {
    // First try audiobook's total_duration_seconds (most accurate if set)
    if (_audiobook != null) {
      final audiobookDuration = _audiobook!['total_duration_seconds'];
      if (audiobookDuration != null && (audiobookDuration as num).toInt() > 0) {
        return audiobookDuration.toInt();
      }
    }

    // Fall back to summing chapter durations
    int total = 0;
    for (final ch in _chapters) {
      total += (ch['duration_seconds'] as int?) ?? 0;
    }
    return total;
  }

  /// Fetches AI-generated 2-line summary for this audiobook.
  /// Only calls the API when user explicitly taps the button.
  Future<void> _fetchAiSummary({bool forceRefresh = false}) async {
    // Don't fetch if already loading
    if (_isLoadingSummary) return;

    // Check session cache first (unless force refresh)
    final summaryService = ref.read(bookSummaryServiceProvider);
    if (!forceRefresh && summaryService.hasCachedSummary(widget.audiobookId)) {
      final cached = summaryService.getCachedSummary(widget.audiobookId);
      if (cached != null) {
        setState(() {
          _aiSummary = cached;
          _summaryError = false;
          _summaryRateLimited = false;
          _summaryErrorDetails = null;
        });
        return;
      }
    }

    setState(() {
      _isLoadingSummary = true;
      _summaryError = false;
      _summaryRateLimited = false;
      _summaryErrorDetails = null;
    });

    try {
      final result = await summaryService.getBookSummary(
        widget.audiobookId,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      if (result.hasContent) {
        setState(() {
          _aiSummary = result.summary;
          _isLoadingSummary = false;
          _summaryError = false;
          _summaryRateLimited = false;
          _summaryErrorDetails = null;
        });
      } else if (result.rateLimitExceeded) {
        setState(() {
          _isLoadingSummary = false;
          _summaryError = false;
          _summaryRateLimited = true;
          _summaryErrorDetails = null;
        });
      } else {
        setState(() {
          _isLoadingSummary = false;
          _summaryError = true;
          _summaryRateLimited = false;
          _summaryErrorDetails = _formatSummaryErrorDetails(result);
        });
      }
    } catch (e) {
      AppLogger.e('Summary fetch failed', error: e);
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
        _summaryError = true;
        _summaryRateLimited = false;
        _summaryErrorDetails = 'AI error: unexpected_exception';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch audio state to determine if mini player should be shown
    final audioState = ref.watch(audioProvider.select((s) => (
      hasAudio: s.hasAudio,
      playingAudiobookId: s.audiobook?['id'] as int?,
    )));

    // Show mini player whenever audio is playing (even if viewing same audiobook)
    final showMiniPlayer = audioState.hasAudio && audioState.playingAudiobookId != null;

    final bottomPadding = showMiniPlayer ? 90.0 : 0.0;

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(child: _buildBody(bottomPadding)),
            // Mini player at bottom when audio is playing
            if (showMiniPlayer) const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double bottomPadding) {
    if (_isLoading) {
      return const AudiobookDetailSkeleton();
    }

    if (_errorMessage != null) {
      return SafeArea(
        child: Column(
          children: [
            _buildSimpleAppBar(),
            Expanded(
              child: ErrorView(
                message: _errorMessage!,
                onRetry: _loadData,
              ),
            ),
          ],
        ),
      );
    }

    if (_audiobook == null) {
      return SafeArea(
        child: Column(
          children: [
            _buildSimpleAppBar(),
            Expanded(
              child: ErrorView.load(
                itemName: 'کتاب',
                onRetry: _loadData,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Transparent App Bar
            SliverAppBar(
              expandedHeight: 0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: _buildBackButton(),
              actions: [
                _buildWishlistButton(),
                _buildMoreButton(),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding + 100),
                child: Column(
                  children: [
                    // Hero Section with Cover
                    _buildHeroSection(),

                    // Info & Actions Section
                    _buildInfoSection(),

                    // Sections
                    _buildDescriptionSection(),
                    _buildAiSummarySection(),
                    _buildChaptersSection(),
                    _buildReviewsSection(),

                    // Recommendation sections (Audible-style)
                    if (_moreFromAuthor.isNotEmpty) _buildMoreFromAuthorSection(),
                    if (_youMayAlsoEnjoy.isNotEmpty) _buildYouMayAlsoEnjoySection(),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Fixed Action Button at Bottom
        // Show bottom action bar ONLY if NOT currently playing this audiobook
        () {
          final audioState = ref.watch(audioProvider.select((s) => (
            hasAudio: s.hasAudio,
            playingAudiobookId: s.audiobook?['id'] as int?,
            isPlaying: s.isPlaying,
          )));

          // Hide if currently playing THIS audiobook
          final isPlayingThisAlbum = audioState.hasAudio &&
              audioState.playingAudiobookId == widget.audiobookId &&
              audioState.isPlaying;

          if (isPlayingThisAlbum) {
            return const SizedBox.shrink();  // Hidden when playing same album
          }

          return _buildFixedActionButton();  // Show otherwise
        }(),
      ],
    );
  }

  Widget _buildSimpleAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded),
          ),
          const Expanded(
            child: Text(
              'جزئیات کتاب',
              style: AppTypography.appBarTitle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildWishlistButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _isTogglingWishlist ? null : _toggleWishlist,
        icon: _isTogglingWishlist
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                _isInWishlist ? Icons.favorite : Icons.favorite_border,
                color: _isInWishlist ? Colors.red : Colors.white,
                size: 22,
              ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.3),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 22),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'report') {
            _reportIssue();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 12),
                Text('گزارش مشکل', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final coverUrl = _audiobook!['cover_url'] as String?;
    final heroColor = (_dominantCoverColor ?? AppColors.primary).withValues(alpha:0.55);

    // Determine aspect ratio by content type:
    //   Books (audiobook/ebook): 2:3 portrait
    //   Music, podcasts, articles: 1:1 square
    final contentType = (_audiobook!['content_type'] as String?) ?? 'audiobook';
    final bool isSquareCover = ['music', 'podcast', 'article'].contains(contentType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final coverWidth = screenWidth * 0.52;
        final coverHeight = isSquareCover ? coverWidth : coverWidth * 1.5;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                heroColor,
                AppColors.background,
              ],
              stops: const [0.0, 0.75],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 48, bottom: 24),
              child: Center(
                child: Container(
                  width: coverWidth,
                  height: coverHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'cover_${widget.audiobookId}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: coverUrl != null
                          ? OptimizedCoverImage(
                              coverUrl: coverUrl,
                              width: coverWidth,
                              height: coverHeight,
                              fit: BoxFit.cover,
                              // borderRadius handled by parent ClipRRect
                            )
                          : _buildCoverPlaceholder(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.headphones_rounded, color: AppColors.textTertiary, size: 60),
      ),
    );
  }

  Widget _buildInfoSection() {
    final title = (_audiobook!['title_fa'] as String?) ?? '';
    final contentType = (_audiobook!['content_type'] as String?) ?? 'audiobook';
    final isMusic = contentType == 'music';
    final isPodcast = contentType == 'podcast';
    // Check if this book is branded as "پرستو"
    final isParastoBrand = (_audiobook!['is_parasto_brand'] as bool?) ?? false;
    // Get narrator/artist from correct metadata table (not profiles which is the uploader account)
    String narratorRaw = '';
    if (isMusic) {
      final musicMeta = _audiobook!['music_metadata'] as Map<String, dynamic>?;
      narratorRaw = (musicMeta?['artist_name'] as String?) ?? '';
    } else {
      final bookMeta = _audiobook!['book_metadata'] as Map<String, dynamic>?;
      narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
    }
    final narrator = isParastoBrand ? 'پرستو' : narratorRaw;

    // Get metadata from new tables if available, fallback to legacy columns
    String authorFa;
    String translatorFa;
    String artistName;
    String composer;
    String lyricist;
    String producer;
    String album;
    String genre;
    int? releaseYear;
    String featuredArtistsText;
    String archiveSource = '';
    String collectionSource = '';
    String publisher = ''; // From book_metadata.publisher
    String narratorNameFromMetadata = ''; // From book_metadata.narrator_name
    String label = ''; // From music_metadata.label (record label / studio)
    String coAuthors = ''; // From book_metadata.co_authors
    int? publicationYear; // From book_metadata.publication_year
    String isbn = ''; // From book_metadata.isbn

    if (isMusic && _metadata != null) {
      // Music metadata from music_metadata table
      artistName = (_metadata!['artist_name'] as String?) ?? '';
      composer = (_metadata!['composer'] as String?) ?? '';
      lyricist = (_metadata!['lyricist'] as String?) ?? '';
      producer = (_metadata!['producer'] as String?) ?? '';
      album = (_metadata!['album_title'] as String?) ?? '';
      genre = (_metadata!['genre'] as String?) ?? '';
      releaseYear = _metadata!['release_year'] as int?;
      featuredArtistsText = (_metadata!['featured_artists'] as String?) ?? '';
      label = (_metadata!['label'] as String?) ?? '';

      // Archive fields
      archiveSource = (_metadata!['archive_source'] as String?) ?? '';
      collectionSource = (_metadata!['collection_source'] as String?) ?? '';
      // Fallback to legacy author_fa if no artist_name
      if (artistName.isEmpty) {
        artistName = (_audiobook!['author_fa'] as String?) ?? '';
      }
      authorFa = '';
      translatorFa = '';
    } else if (!isMusic && _metadata != null) {
      // Book metadata from book_metadata table
      authorFa = (_metadata!['author_name'] as String?) ?? '';
      translatorFa = (_metadata!['translator'] as String?) ?? '';
      coAuthors = (_metadata!['co_authors'] as String?) ?? '';
      publicationYear = _metadata!['publication_year'] as int?;
      isbn = (_metadata!['isbn'] as String?) ?? '';
      // Fallback to legacy columns if metadata is empty
      if (authorFa.isEmpty) {
        authorFa = (_audiobook!['author_fa'] as String?) ?? '';
      }
      if (translatorFa.isEmpty) {
        translatorFa = (_audiobook!['translator_fa'] as String?) ?? '';
      }
      artistName = '';
      composer = '';
      lyricist = '';
      producer = '';
      album = '';
      genre = '';
      releaseYear = null;
      featuredArtistsText = '';

      // Archive fields for books
      archiveSource = (_metadata!['archive_source'] as String?) ?? '';
      collectionSource = (_metadata!['collection_source'] as String?) ?? '';
      publisher = (_metadata!['publisher'] as String?) ?? '';

      // Narrator name from book_metadata (typed by narrator/admin)
      narratorNameFromMetadata = (_metadata!['narrator_name'] as String?) ?? '';
    } else {
      // No metadata table data - use legacy columns
      authorFa = (_audiobook!['author_fa'] as String?) ?? '';
      translatorFa = (_audiobook!['translator_fa'] as String?) ?? '';
      artistName = isMusic ? authorFa : ''; // For music, author_fa is artist
      composer = '';
      lyricist = '';
      producer = '';
      album = '';
      genre = '';
      releaseYear = null;
      featuredArtistsText = '';
      if (isMusic) authorFa = ''; // Clear for music display
    }

    final category = (_audiobook!['categories']?['name_fa'] as String?) ?? '';
    final avgRating = (_audiobook!['avg_rating'] as num?)?.toDouble() ?? 0.0;
    // Use database review_count, or count from loaded reviews as fallback
    final reviewCount = (_audiobook!['review_count'] as int?) ?? _reviews.length;
    final totalDuration = _calculateTotalDuration();
    // Use actual chapter count from loaded chapters, or database chapter_count as fallback
    final chapterCount = _chapters.isNotEmpty
        ? _chapters.length
        : ((_audiobook!['chapter_count'] as int?) ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Title
          Text(
            AppStrings.localize(title),
            style: AppTypography.heroTitle,
            textAlign: TextAlign.center,
          ),

          // Content type badge (article, music, podcast — not for regular audiobooks)
          if (contentType != 'audiobook')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ContentTypeBadge.fromAudiobook(_audiobook!, compact: false),
            ),
          const SizedBox(height: 8),

          // MUSIC: Primary creator + collection label + album metadata inline
          if (isMusic) ...[
            // Primary creator - prominent display
            () {
              final primaryCreator = _getPrimaryCreator();

              // Fallback to first singer if no primary marked
              final displayCreator = primaryCreator ??
                                    _getCreatorByRole('singer') ??
                                    _getCreatorByRole('artist');

              final hasCreator = artistName.isNotEmpty || displayCreator != null;
              if (!hasCreator) return const SizedBox.shrink();

              return Column(
                children: [
                  // Creator name (larger, clickable)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      _buildTappableCreatorName(
                        name: displayCreator?['display_name'] as String? ?? artistName,
                        creatorId: displayCreator?['id'] as String?,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  // Collection label (if exists)
                  if (displayCreator != null &&
                      displayCreator['collection_label'] != null &&
                      (displayCreator['collection_label'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayCreator['collection_label'] as String,
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Archive source (از بایگانی)
                  if (archiveSource.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'از بایگانی: $archiveSource',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Collection source (از آرشیو)
                  if (collectionSource.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'از آرشیو: $collectionSource',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Publisher (ناشر)
                  if (publisher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ناشر: $publisher',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            }(),

            // Featured artists (if any)
            () {
              // Parse featured artists from metadata text field
              final featuredFromMetadata = featuredArtistsText.split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              // Get featured artists from linked creators - STRICT filtering
              final featuredFromCreators = _creators
                  .where((c) {
                    final role = (c['role'] as String?) ?? '';
                    // ONLY accept exact matches for featured artist roles
                    return role == 'featured_artist' || role == 'featured';
                  })
                  .map((c) => c['display_name'] as String)
                  .toList();

              // Combine both sources
              final allFeatured = {
                ...featuredFromMetadata,
                ...featuredFromCreators,
              }.toList(); // Remove duplicates

              // Log for debugging
              if (allFeatured.isNotEmpty) {
                AppLogger.d('Featured artists: ${allFeatured.join(', ')}');
              }

              if (allFeatured.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'feat. ${allFeatured.join(', ')}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }(),

            const SizedBox(height: 12),

            // Album + secondary creators inline
            () {
              final parts = <String>[];

              // Album
              if (album.isNotEmpty) {
                parts.add('آلبوم: $album');
              }

              // Composer (if not primary)
              final composerCreator = _getCreatorByRole('composer');
              if (composerCreator != null && composerCreator['is_primary'] != true) {
                parts.add('آهنگساز: ${composerCreator['display_name']}');
              } else if (composer.isNotEmpty) {
                parts.add('آهنگساز: $composer');
              }

              // Lyricist (if not primary)
              final lyricistCreator = _getCreatorByRole('lyricist');
              if (lyricistCreator != null && lyricistCreator['is_primary'] != true) {
                parts.add('شاعر: ${lyricistCreator['display_name']}');
              } else if (lyricist.isNotEmpty) {
                parts.add('شاعر: $lyricist');
              }

              // Producer (from metadata only, no creator role for producer)
              if (producer.isNotEmpty) {
                parts.add('تهیه‌کننده: $producer');
              }

              // Record label / studio
              if (label.isNotEmpty) {
                parts.add('ناشر: $label');
              }

              // Musician (if exists and not primary)
              final musicianCreator = _getCreatorByRole('musician');
              if (musicianCreator != null && musicianCreator['is_primary'] != true) {
                parts.add('نوازنده: ${musicianCreator['display_name']}');
              }

              if (parts.isEmpty) return const SizedBox.shrink();

              return Text(
                parts.join(' • '),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              );
            }(),

            // Genre (free text field)
            if (genre.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'سبک: $genre',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],

            // Music Categories (from database - clickable chips)
            if (_musicCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _musicCategories.map((catLink) {
                  final cat = catLink['music_categories'] as Map<String, dynamic>?;
                  if (cat == null) return const SizedBox.shrink();

                  final categoryName = (cat['name_fa'] as String?) ?? '';

                  final categoryId = cat['id'] as int?;

                  return InkWell(
                    onTap: () {
                      // Navigate to music screen filtered by this category
                      if (categoryId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MusicScreen(initialCategoryId: categoryId),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha:0.3)),
                      ),
                      child: Text(
                        AppStrings.localize(categoryName),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Release Year
            if (releaseYear != null) ...[
              const SizedBox(height: 4),
              Text(
                'سال انتشار: $releaseYear',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ],

          // BOOK or PODCAST: Author/Translator/Narrator (or Host for podcasts)
          if (!isMusic) ...[
            // For podcasts: show Host (میزبان) instead of Author (نویسنده)
            // For books: show Author
            () {
              final authorCreator = _getCreatorByRole('author');
              final hasAuthor = authorFa.isNotEmpty || authorCreator != null;
              if (!hasAuthor) return const SizedBox.shrink();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPodcast ? Icons.mic_rounded : Icons.edit_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  _buildTappableCreatorName(
                    name: authorCreator?['display_name'] as String? ?? authorFa,
                    creatorId: authorCreator?['id'] as String?,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500),
                    prefix: isPodcast ? 'میزبان: ' : null,
                  ),
                  if (!isPodcast) ...[
                    const SizedBox(width: 10),
                    AuthorFollowButton(authorName: authorFa),
                  ],
                ],
              );
            }(),

            // Translator - show ONLY for books (not podcasts)
            if (!isPodcast) () {
              final translatorCreator = _getCreatorByRole('translator');
              final hasTranslator = translatorFa.isNotEmpty || translatorCreator != null;
              if (!hasTranslator) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.translate_rounded, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    _buildTappableCreatorName(
                      name: translatorCreator?['display_name'] as String? ?? translatorFa,
                      creatorId: translatorCreator?['id'] as String?,
                      style: AppTypography.bodySmall,
                      prefix: 'ترجمه: ',
                    ),
                  ],
                ),
              );
            }(),

            // Narrator - show ONLY for audiobooks (not music, not podcasts)
            if (!isPodcast) () {
              // Hide for music - music doesn't have narrators
              if (isMusic) return const SizedBox.shrink();

              // Check for narrator name from book_metadata first (typed by narrator/admin)
              // Then fall back to linked creator
              final narratorCreator = _getCreatorByRole('narrator');
              final hasNarratorFromMetadata = narratorNameFromMetadata.isNotEmpty;
              final hasNarratorCreator = narratorCreator != null;

              if (!hasNarratorFromMetadata && !hasNarratorCreator) {
                return const SizedBox.shrink();
              }

              // Prefer metadata narrator name, fall back to creator
              final displayName = hasNarratorFromMetadata
                  ? narratorNameFromMetadata
                  : (narratorCreator!['display_name'] as String);
              final creatorId = hasNarratorFromMetadata ? null : (narratorCreator!['id'] as String);

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    _buildTappableCreatorName(
                      name: displayName,
                      creatorId: creatorId,
                      style: AppTypography.bodySmall,
                      prefix: 'گوینده: ',
                    ),
                  ],
                ),
              );
            }(),

            // Co-authors (for books) or Co-hosts (for podcasts)
            if (coAuthors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isPodcast ? 'میزبانان همکار: $coAuthors' : 'نویسندگان همکار: $coAuthors',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),

            // Publisher (ناشر)
            if (publisher.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'ناشر: $publisher',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),

            // Publication year
            if (publicationYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'سال نشر: ${FarsiUtils.toFarsiDigits(publicationYear)}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),

            // ISBN
            if (isbn.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'شابک: $isbn',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                ),
              ),

            // Archive source (از بایگانی) - for books
            if (archiveSource.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'از بایگانی: $archiveSource',
                  style: AppTypography.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Collection source (از آرشیو) - for books
            if (collectionSource.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'از آرشیو: $collectionSource',
                  style: AppTypography.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 16),

          // Meta Row: Rating, Duration, Chapters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Rating
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.warning,
                    value: avgRating > 0 ? FarsiUtils.toFarsiDigits(avgRating.toStringAsFixed(1)) : '-',
                    label: '${FarsiUtils.toFarsiDigits(reviewCount)} نظر',
                  ),
                ),
                const SizedBox(width: 24),
                _buildMetaDivider(),
                const SizedBox(width: 24),
                // Duration
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.primary,
                    value: totalDuration > 0 ? FarsiUtils.formatDurationLongFarsi(totalDuration) : '-',
                    label: 'مدت زمان',
                  ),
                ),
                const SizedBox(width: 24),
                _buildMetaDivider(),
                const SizedBox(width: 24),
                // Chapters
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.list_rounded,
                    iconColor: AppColors.secondary,
                    value: chapterCount > 0 ? FarsiUtils.toFarsiDigits(chapterCount) : '-',
                    label: (_audiobook!['content_type'] as String?) == 'music' ? 'آهنگ' : 'فصل',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Tag
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary.withValues(alpha:0.3)),
              ),
              child: Text(
                category,
                style: AppTypography.chip.copyWith(color: AppColors.secondary),
              ),
            ),
          const SizedBox(height: 16),

          // Share & Gift Actions
          _buildShareGiftActions(title, narrator),
          const SizedBox(height: 20),

          // Progress Card (if owned and has progress) - shows "در حال پخش" if currently playing
          if (_isOwned && _progress != null) _buildProgressCard(),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall,
        ),
      ],
    );
  }

  Widget _buildMetaDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.surfaceLight,
    );
  }

  Widget _buildShareGiftActions(String title, String narrator) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Share Button
        Flexible(
          child: _buildActionButton(
            icon: Icons.share_rounded,
            label: 'اشتراک‌گذاری',
            onTap: () => _shareBook(title, narrator),
          ),
        ),
        const SizedBox(width: 24),
        // Gift Button (Coming Soon)
        Flexible(
          child: _buildActionButton(
            icon: Icons.card_giftcard_rounded,
            label: 'هدیه دادن',
            onTap: () => _showGiftComingSoon(title, narrator),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _getShareText(String title, String narrator) {
    final buffer = StringBuffer();
    buffer.write('🎧 $title');
    if (narrator.isNotEmpty) {
      buffer.write(' - $narrator');
    }
    buffer.write('\n\nدر اپلیکیشن پرستو گوش کنید.');
    return buffer.toString();
  }

  void _shareBook(String title, String narrator) {
    final shareText = _getShareText(title, narrator);
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('کپی شد'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showGiftComingSoon(String title, String narrator) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _GiftBottomSheet(
        bookTitle: title,
        onContinue: (email, message) {
          // Build gift request text
          final buffer = StringBuffer();
          buffer.writeln('🎁 درخواست هدیه');
          buffer.writeln('کتاب: $title');
          buffer.writeln('ایمیل گیرنده: $email');
          if (message != null && message.isNotEmpty) {
            buffer.writeln('پیام: $message');
          }

          Clipboard.setData(ClipboardData(text: buffer.toString()));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('متن هدیه کپی شد. (پرداخت هدیه به‌زودی)'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard() {
    final percentage = (_progress!['completion_percentage'] as num?)?.toInt() ?? 0;
    final currentChapter = ((_progress!['current_chapter_index'] as int?) ?? 0) + 1;

    // Check if this audiobook is currently playing
    final audioState = ref.watch(audioProvider);
    final isCurrentlyPlaying = audioState.audiobook != null &&
        audioState.audiobook!['id'] == widget.audiobookId &&
        audioState.isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentlyPlaying
              ? [
                  AppColors.success.withValues(alpha:0.2),
                  AppColors.success.withValues(alpha:0.08),
                ]
              : [
                  AppColors.primary.withValues(alpha:0.15),
                  AppColors.primary.withValues(alpha:0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentlyPlaying
              ? AppColors.success.withValues(alpha:0.4)
              : AppColors.primary.withValues(alpha:0.3),
        ),
      ),
      child: Row(
        children: [
          // Progress Circle with optional playing animation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.surfaceLight,
                  color: isCurrentlyPlaying ? AppColors.success : AppColors.primary,
                  strokeWidth: 5,
                ),
              ),
              isCurrentlyPlaying
                  ? const Icon(Icons.graphic_eq_rounded, color: AppColors.success, size: 24)
                  : Text(
                      '${FarsiUtils.toFarsiDigits(percentage)}٪',
                      style: AppTypography.labelLarge,
                    ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentlyPlaying ? 'در حال پخش' : 'ادامه گوش دادن',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCurrentlyPlaying ? AppColors.success : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (_audiobook!['content_type'] as String?) == 'music'
                      ? 'آهنگ ${FarsiUtils.toFarsiDigits(currentChapter)} از ${FarsiUtils.toFarsiDigits(_chapters.length)}'
                      : 'فصل ${FarsiUtils.toFarsiDigits(currentChapter)} از ${FarsiUtils.toFarsiDigits(_chapters.length)}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isCurrentlyPlaying
                ? () => ref.read(audioProvider.notifier).togglePlayPause()
                : () => _playAudiobook(
                      chapterIndex: (_progress!['current_chapter_index'] as int?) ?? 0,
                      seekTo: _progress!['position_seconds'] as int?,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyPlaying ? AppColors.success : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
            label: Text(isCurrentlyPlaying ? 'مکث' : 'ادامه'),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedActionButton() {
    final isFree = _audiobook!['is_free'] == true;
    final price = (_audiobook!['price_toman'] as int?) ?? 0;

    // Check subscription status for access gate
    final subStatusAsync = ref.watch(subscriptionStatusProvider);
    final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;
    final isSubAvailable = ref.watch(subscriptionAvailableProvider);

    final accessResult = AccessGateService.checkAccess(
      isOwned: _isOwned,
      isFree: isFree,
      isSubscriptionActive: isSubActive,
      isSubscriptionAvailable: isSubAvailable,
    );

    // Determine if user has incomplete progress (for continue vs start logic)
    final hasIncompleteProgress = _isOwned &&
        _progress != null &&
        (_progress!['is_completed'] != true) &&
        ((_progress!['completion_percentage'] as num?)?.toInt() ?? 0) < 100;

    // Button text and action for owned books
    String ownedButtonLabel;
    VoidCallback ownedButtonAction;
    if (hasIncompleteProgress) {
      ownedButtonLabel = 'ادامه';
      ownedButtonAction = () => _playAudiobook(
        chapterIndex: (_progress!['current_chapter_index'] as int?) ?? 0,
        seekTo: _progress!['position_seconds'] as int?,
      );
    } else {
      ownedButtonLabel = 'شروع';
      ownedButtonAction = () => _playAudiobook(chapterIndex: 0);
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: accessResult.needsSubscription
            ? _buildSubscriptionCTA(isSubAvailable)
            : Row(
          children: [
            // Price/Status — for paid books: show price column
            if (!_isOwned && accessResult.needsPurchase) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatPrice(price),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      AppStrings.purchaseOnceForever,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],

            // Free badge — for free/claimable books: green "رایگان" pill on the left
            if (!_isOwned && accessResult.canAccess && !accessResult.needsPurchase) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha:0.4)),
                ),
                child: const Text(
                  'رایگان',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Action Button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: accessResult.canAccess
                      ? (_isOwned ? ownedButtonAction : () => _claimFreeAndPlay())
                      : _isPurchasing
                          ? null
                          : _purchase,
                  style: ElevatedButton.styleFrom(
                    // Free claimable: orange (افزودن); owned: gold (play); purchase: gold
                    backgroundColor: (!_isOwned && accessResult.canAccess && !accessResult.needsPurchase)
                        ? AppColors.secondary
                        : AppColors.primary,
                    foregroundColor: (!_isOwned && accessResult.canAccess && !accessResult.needsPurchase)
                        ? Colors.white
                        : AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: _isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          accessResult.canAccess
                              ? (_isOwned ? Icons.play_arrow : Icons.add_shopping_cart_rounded)
                              : Icons.shopping_cart_rounded,
                          size: 22,
                        ),
                  label: Text(
                    accessResult.canAccess
                        ? (_isOwned ? ownedButtonLabel : AppStrings.addToLibrary)
                        : AppStrings.buy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // Download Button (only for owned, on mobile)
            if (!kIsWeb && _isOwned && _chapters.isNotEmpty) ...[
              const SizedBox(width: 12),
              _buildDownloadButton(),
            ],
          ],
        ),
      ),
    );
  }

  /// Subscription CTA row for free content that requires active subscription.
  Widget _buildSubscriptionCTA(bool isSubAvailable) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge: "رایگان با اشتراک فعال"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            isSubAvailable
                ? AppStrings.freeWithActiveSubscription
                : AppStrings.iapUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSubAvailable ? AppColors.primary : AppColors.warning,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isSubAvailable ? _showPaywall : null,
            icon: const Icon(Icons.workspace_premium_rounded, size: 22),
            label: Text(
              AppStrings.subscribe,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
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
        ref.invalidate(subscriptionStatusProvider);
        ref.invalidate(hasPremiumProvider);
        // Reload data so ownership state refreshes
        _loadData();
      }
    });
  }

  /// Claim a free audiobook (after subscription is verified) and start playing.
  void _claimFreeAndPlay() async {
    final purchaseService = PurchaseService(Supabase.instance.client);
    final result = await purchaseService.purchaseAudiobook(
      context: context,
      audiobookId: widget.audiobookId,
      priceToman: 0,
      isFree: true,
    );
    if (result == PurchaseResult.success) {
      setState(() => _isOwned = true);
      ref.read(audioProvider.notifier).updateOwnershipAfterPurchase(widget.audiobookId);
      ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
      ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
      ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
      ref.invalidate(ownedItemsWithProgressProvider(ContentType.articles));
      ref.invalidate(ownedBooksWithProgressProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کتاب به کتابخانه شما اضافه شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildDownloadButton() {
    final downloadNotifier = ref.read(downloadProvider.notifier);
    final isFullyDownloaded = downloadNotifier.isAudiobookFullyDownloaded(
      widget.audiobookId,
      _chapters.length,
    );

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        onPressed: isFullyDownloaded
            ? () => _confirmDeleteAllDownloads(downloadNotifier)
            : () => _downloadAllChapters(downloadNotifier),
        icon: Icon(
          isFullyDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
          color: isFullyDownloaded ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = (_audiobook!['description_fa'] as String?) ?? '';
    if (description.isEmpty) return const SizedBox.shrink();

    // FIX: Use appropriate label based on content type (book vs music)
    final contentType = (_audiobook!['content_type'] as String?) ?? 'audiobook';
    final sectionTitle = contentType == 'music' ? 'درباره‌ی این اثر' : 'درباره‌ی این کتاب';

    final textStyle = AppTypography.bodyLarge.copyWith(
      color: AppColors.textSecondary,
      height: 1.8,
    );

    return _buildSection(
      title: sectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            firstChild: Text(
              AppStrings.localize(description),
              style: textStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              AppStrings.localize(description),
              style: textStyle,
            ),
            crossFadeState: _descriptionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppDurations.normal,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Text(
              _descriptionExpanded ? 'کمتر' : 'بیشتر...',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the AI summary section with a button to generate summary.
  /// This is an OPTIONAL feature - does NOT auto-load, requires user tap.
  Widget _buildAiSummarySection() {
    // Hide for music - only show for audiobooks
    if ((_audiobook!['content_type'] as String?) == 'music') return const SizedBox.shrink();

    // Only show if user is logged in (required for Edge Function auth)
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha:0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'خلاصهٔ دوخطی',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'با هوش مصنوعی',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh button (only show if summary exists)
                if (_aiSummary != null && !_isLoadingSummary)
                  IconButton(
                    onPressed: () => _fetchAiSummary(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.textTertiary,
                    tooltip: 'به‌روزرسانی خلاصه',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Content area
            if (_isLoadingSummary)
              // Loading state
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'در حال ساخت خلاصه...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_aiSummary != null)
              // Summary display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _aiSummary!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.7,
                  ),
                  textAlign: TextAlign.right,
                ),
              )
            else if (_summaryRateLimited)
              // Rate limit state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'شما به سقف درخواست روزانه رسیده‌اید.\nلطفاً فردا دوباره امتحان کنید.',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_summaryError)
              // Error state
              Column(
                children: [
                  const Text(
                    'مشکلی در ساخت خلاصه پیش آمد.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!kReleaseMode && _summaryErrorDetails != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _summaryErrorDetails!,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _fetchAiSummary,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('تلاش مجدد'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              )
            else
              // Initial state - show button to generate
              Center(
                child: OutlinedButton.icon(
                  onPressed: _fetchAiSummary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('نمایش خلاصه'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSummaryErrorDetails(BookSummaryResult result) {
    final code = result.errorCode ?? result.errorType ?? 'unknown';
    if (result.errorStatus != null) {
      return 'AI error: $code (${result.errorStatus})';
    }
    return 'AI error: $code';
  }

  Widget _buildChaptersSection() {
    if (_chapters.isEmpty) return const SizedBox.shrink();

    // Determine how many chapters to show
    final showAll = _chaptersExpanded || _chapters.length <= _initialChapterCount;
    final displayCount = showAll ? _chapters.length : _initialChapterCount;
    final hasMore = _chapters.length > _initialChapterCount;

    final isMusicContent = (_audiobook!['content_type'] as String?) == 'music';
    return _buildSection(
      title: isMusicContent ? 'فهرست آهنگ‌ها' : 'فهرست فصل‌ها',
      trailing: Text(
        isMusicContent
            ? '${FarsiUtils.toFarsiDigits(_chapters.length)} آهنگ'
            : '${FarsiUtils.toFarsiDigits(_chapters.length)} فصل',
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 13,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Chapter tiles — animated expand/collapse
            AnimatedSize(
              duration: AppDurations.slow,
              curve: AppCurves.decelerate,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: List.generate(displayCount, (index) {
                  final isLast = index == displayCount - 1 && showAll;
                  return Column(
                    children: [
                      _buildChapterTile(index),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: AppColors.surfaceLight,
                        ),
                    ],
                  );
                }),
              ),
            ),
            // Show more/less button
            if (hasMore) ...[
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.surfaceLight,
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _chaptersExpanded = !_chaptersExpanded;
                  });
                },
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _chaptersExpanded
                            ? 'نمایش کمتر'
                            : isMusicContent
                                ? 'نمایش همه ${FarsiUtils.toFarsiDigits(_chapters.length)} آهنگ'
                                : 'نمایش همه ${FarsiUtils.toFarsiDigits(_chapters.length)} فصل',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _chaptersExpanded ? 0.5 : 0.0,
                        duration: AppDurations.normal,
                        curve: AppCurves.snappy,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChapterTile(int i) {
    final ch = _chapters[i];
    final chapterId = ch['id'] as int;
    final currentChapterIndex = (_progress?['current_chapter_index'] as int?) ?? -1;
    final albumIsCompleted = _progress?['is_completed'] == true;
    final completionPercentage = (_progress?['completion_percentage'] as num?)?.toInt() ?? 0;

    // Chapter is "current" only if album is NOT fully completed
    final isCurrent = _progress != null && !albumIsCompleted && currentChapterIndex == i;

    // Chapter is completed if:
    // 1) Album is fully completed (is_completed=true OR completion_percentage >= 100), OR
    // 2) Album is in progress and this chapter is before the current chapter
    final isCompleted = _progress != null &&
        (albumIsCompleted || completionPercentage >= 100 || i < currentChapterIndex);

    final isPreview = ch['is_preview'] == true;
    final isFree = _audiobook!['is_free'] == true;
    // Allow playing if: owned, OR preview chapter, OR it's a free audiobook
    final canPlay = _isOwned || isPreview || isFree;
    final title = (ch['title_fa'] as String?) ??
        ((_audiobook!['content_type'] as String?) == 'music'
            ? 'آهنگ ${FarsiUtils.toFarsiDigits(i + 1)}'
            : 'فصل ${FarsiUtils.toFarsiDigits(i + 1)}');
    final duration = (ch['duration_seconds'] as int?) ?? 0;

    // Calculate chapter-level progress for current chapter
    double chapterProgress = 0.0;
    if (isCompleted) {
      chapterProgress = 1.0; // Fully completed chapters
    } else if (isCurrent && duration > 0) {
      final positionSeconds = (_progress!['position_seconds'] as int?) ?? 0;
      chapterProgress = (positionSeconds / duration).clamp(0.0, 1.0);
    }

    ref.watch(downloadProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    final downloadStatus = downloadNotifier.getStatus(widget.audiobookId, chapterId);
    final downloadProgress = downloadNotifier.getProgress(widget.audiobookId, chapterId);

    return InkWell(
      onTap: canPlay ? () => _playAudiobook(chapterIndex: i) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Chapter Number / Status Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primary
                    : isCompleted
                        ? AppColors.success.withValues(alpha:0.15)
                        : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isCurrent
                    ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)
                    : isCompleted
                        ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                        : Text(
                            FarsiUtils.toFarsiDigits(i + 1),
                            style: TextStyle(
                              color: canPlay ? AppColors.textPrimary : AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 12),

            // Title & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.localize(title),
                          style: TextStyle(
                            color: canPlay
                                ? (isCurrent ? AppColors.primary : AppColors.textPrimary)
                                : AppColors.textTertiary,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPreview && !_isOwned)
                        Container(
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!canPlay)
                        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                  // Chapter listening progress bar (for current chapter)
                  if (isCurrent && chapterProgress > 0 && downloadStatus != DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: chapterProgress,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.primary,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                  // Download progress bar (while downloading)
                  if (downloadStatus == DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.secondary,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ],
              ),
            ),

            // Duration & Download Status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (downloadStatus == DownloadStatus.downloaded)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: Icon(Icons.download_done_rounded, size: 16, color: AppColors.success),
                  ),
                Text(
                  Formatters.formatDuration(duration),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                // Download button on mobile
                if (!kIsWeb && canPlay) ...[
                  const SizedBox(width: 4),
                  _buildChapterDownloadButton(ch, downloadStatus, downloadNotifier),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterDownloadButton(
    Map<String, dynamic> chapter,
    DownloadStatus status,
    DownloadNotifier notifier,
  ) {
    final chapterId = chapter['id'] as int;
    IconData icon;
    Color color;
    VoidCallback? onPressed;

    switch (status) {
      case DownloadStatus.downloaded:
        icon = Icons.delete_outline_rounded;
        color = AppColors.textTertiary;
        onPressed = () => _confirmDeleteChapter(chapter, notifier);
        break;
      case DownloadStatus.downloading:
        icon = Icons.close_rounded;
        color = AppColors.warning;
        onPressed = () => notifier.cancelDownload(widget.audiobookId, chapterId);
        break;
      case DownloadStatus.failed:
        icon = Icons.refresh;
        color = AppColors.error;
        onPressed = () => _downloadChapter(chapter, notifier);
        break;
      case DownloadStatus.notDownloaded:
      default:
        icon = Icons.download_outlined;
        color = AppColors.textTertiary;
        onPressed = () => _downloadChapter(chapter, notifier);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildReviewsSection() {
    final avgRating = (_audiobook!['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (_audiobook!['review_count'] as int?) ?? 0;

    return _buildSection(
      title: 'نظرات شنوندگان',
      trailing: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ReviewsScreen(
              audiobookId: widget.audiobookId,
              audiobookTitle: (_audiobook!['title_fa'] as String?) ?? '',
              averageRating: avgRating,
              reviewCount: reviewCount,
            ),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('مشاهده همه'),
            SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 18),
          ],
        ),
      ),
      child: Column(
        children: [
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      avgRating > 0 ? FarsiUtils.toFarsiDigits(avgRating.toStringAsFixed(1)) : '-',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    RatingStars(rating: avgRating, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      '${FarsiUtils.toFarsiDigits(reviewCount)} نظر',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _isOwned
                      ? OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => WriteReviewScreen(
                                  audiobookId: widget.audiobookId,
                                  audiobookTitle: (_audiobook!['title_fa'] as String?) ?? '',
                                ),
                              ),
                            );
                            _loadData();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.rate_review_rounded, size: 20),
                          label: const Text('نوشتن نظر'),
                        )
                      : const Text(
                          'برای ثبت نظر، ابتدا کتاب را تهیه کنید',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reviews List
          if (_reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textTertiary),
                    SizedBox(height: 12),
                    Text(
                      'هنوز نظری ثبت نشده',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_reviews.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i < _reviews.length - 1 ? 12 : 0),
                child: ReviewCard(review: _reviews[i]),
              );
            }),
        ],
      ),
    );
  }

  /// "More from Author" section - shows other books by the same author
  Widget _buildMoreFromAuthorSection() {
    if (_moreFromAuthor.isEmpty) return const SizedBox.shrink();

    final authorName = (_audiobook?['author_fa'] as String?) ??
        (_audiobook?['author_en'] as String?) ??
        'این نویسنده';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بیشتر از $authorName',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 245,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _moreFromAuthor.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsetsDirectional.only(start: index < _moreFromAuthor.length - 1 ? 12 : 0),
                  child: _buildRelatedBookCard(_moreFromAuthor[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// "You May Also Enjoy" section - shows books from the same category
  Widget _buildYouMayAlsoEnjoySection() {
    if (_youMayAlsoEnjoy.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'شاید دوست داشته باشید',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 245,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _youMayAlsoEnjoy.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsetsDirectional.only(start: index < _youMayAlsoEnjoy.length - 1 ? 12 : 0),
                  child: _buildRelatedBookCard(_youMayAlsoEnjoy[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Card widget for related books in recommendation sections
  Widget _buildRelatedBookCard(Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
          ),
        );
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image — fixed 2:3 portrait aspect ratio (width 120 → height 180)
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book['cover_url'] != null
                    ? Image.network(
                        book['cover_url'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: Icon(Icons.auto_stories_rounded, size: 32, color: AppColors.textTertiary),
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: const Center(
                          child: Icon(Icons.auto_stories_rounded, size: 32, color: AppColors.textTertiary),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              AppStrings.localize((book['title_fa'] as String?) ?? ''),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Rating and price
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                const SizedBox(width: 2),
                Text(
                  FarsiUtils.toFarsiDigits(((book['avg_rating'] as num?) ?? 0).toStringAsFixed(1)),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
                const Spacer(),
                if (book['is_free'] == true)
                  const Text(
                    'رایگان',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.sectionTitle,
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _formatPrice(num price) {
    // Price is stored as USD
    if (price < 1) {
      return '\$${price.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
  }

  void _downloadChapter(Map<String, dynamic> chapter, DownloadNotifier notifier) {
    final url = _getChapterUrl(chapter);
    if (url != null && url.isNotEmpty) {
      final isFree = _audiobook!['is_free'] == true;
      final subStatusAsync = ref.read(subscriptionStatusProvider);
      final isSubActive = subStatusAsync.valueOrNull?.isActive ?? false;
      notifier.downloadChapter(
        audiobookId: widget.audiobookId,
        chapterId: chapter['id'] as int,
        url: url,
        chapterTitle: chapter['title_fa'] as String?,
        isOwned: _isOwned,
        isFree: isFree,
        isSubscriptionActive: isSubActive,
        isPreviewContent: chapter['is_preview'] == true,
      );
    }
  }

  String? _getChapterUrl(Map<String, dynamic> chapter) {
    if (chapter['audio_url'] != null) {
      return chapter['audio_url'] as String;
    }
    if (chapter['audio_storage_path'] != null) {
      final path = chapter['audio_storage_path'] as String;
      return Supabase.instance.client.storage.from(Env.audioBucket).getPublicUrl(path);
    }
    return null;
  }

  void _confirmDeleteChapter(Map<String, dynamic> chapter, DownloadNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف دانلود', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'آیا می‌خواهید فایل "${chapter['title_fa'] ?? 'این فصل'}" را حذف کنید؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteDownload(widget.audiobookId, chapter['id'] as int);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _downloadAllChapters(DownloadNotifier notifier) {
    for (final chapter in _chapters) {
      final chapterId = chapter['id'] as int;
      if (!notifier.isDownloaded(widget.audiobookId, chapterId)) {
        _downloadChapter(chapter, notifier);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('دانلود فصل‌ها شروع شد'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _confirmDeleteAllDownloads(DownloadNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف تمام دانلودها', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'آیا می‌خواهید تمام فایل‌های دانلود شده این کتاب را حذف کنید؟',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteAudiobookDownloads(widget.audiobookId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('دانلودها حذف شدند'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('حذف همه', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// Build a tappable creator name widget.
  /// If creator is linked (has id), tapping navigates to their profile.
  /// Otherwise, displays as static text (fallback for legacy data).
  Widget _buildTappableCreatorName({
    required String name,
    String? creatorId,
    required TextStyle style,
    String? prefix, // e.g., "گوینده: " or "ترجمه: "
  }) {
    final displayText = prefix != null ? '$prefix$name' : name;

    if (creatorId != null && creatorId.isNotEmpty) {
      // Creator is linked - make tappable
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CreatorProfileScreen(creatorId: creatorId),
            ),
          );
        },
        child: Text(
          displayText,
          style: style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary.withValues(alpha:0.5),
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      // No linked creator - static text
      return Text(
        displayText,
        style: style,
        textAlign: TextAlign.center,
      );
    }
  }

  /// Get creator by role from _creators list.
  /// Returns null if no creator with that role is linked.
  Map<String, dynamic>? _getCreatorByRole(String role) {
    for (final creator in _creators) {
      if (creator['role'] == role) {
        return creator;
      }
    }
    return null;
  }

  /// Get primary creator (marked with is_primary=true).
  /// Returns null if no primary creator is set.
  Map<String, dynamic>? _getPrimaryCreator() {
    try {
      for (final creator in _creators) {
        if (creator['is_primary'] == true) {
          return creator;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Bottom sheet for gift functionality with email and message input
class _GiftBottomSheet extends StatefulWidget {
  final String bookTitle;
  final void Function(String email, String? message) onContinue;

  const _GiftBottomSheet({
    required this.bookTitle,
    required this.onContinue,
  });

  @override
  State<_GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<_GiftBottomSheet> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isEmailValid = false;
  bool _showEmailError = false;
  bool _isVerifying = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    // Simple email regex for validation
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    final isValid = emailRegex.hasMatch(email);
    setState(() {
      _isEmailValid = isValid;
      _verifyError = null; // Clear verify error when email changes
      // Only show error after user has typed something
      if (email.isNotEmpty && !isValid) {
        _showEmailError = true;
      } else if (isValid) {
        _showEmailError = false;
      }
    });
  }

  Future<void> _verifyAndContinue() async {
    if (!_isEmailValid || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _isVerifying = false;
          _verifyError = 'لطفاً وارد حساب کاربری شوید';
        });
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'verify-gift-recipient',
        body: {'recipient_email': _emailController.text.trim()},
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        setState(() {
          _isVerifying = false;
          _verifyError = 'خطا در بررسی ایمیل';
        });
        return;
      }

      final ok = data['ok'] as bool? ?? false;
      final reason = data['reason'] as String?;

      if (ok) {
        // Email exists - proceed with gift flow
        widget.onContinue(
          _emailController.text.trim(),
          _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );
      } else if (reason == 'not_found') {
        setState(() {
          _isVerifying = false;
          _verifyError = 'این ایمیل در پرستو ثبت نیست';
        });
      } else {
        setState(() {
          _isVerifying = false;
          _verifyError = 'خطا در بررسی ایمیل';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verifyError = 'خطا در بررسی ایمیل';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            const Icon(
              Icons.card_giftcard_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'هدیه دادن',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Book title
            Text(
              widget.bookTitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Email field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'ایمیل گیرنده',
                hintText: 'example@email.com',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.email_rounded, color: AppColors.textSecondary),
                errorText: _showEmailError ? 'لطفاً ایمیل معتبر وارد کنید' : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Message field (optional)
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'پیام (اختیاری)',
                hintText: 'پیامی برای گیرنده بنویسید...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.message_rounded, color: AppColors.textSecondary),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            // Verify error message
            if (_verifyError != null) ...[
              const SizedBox(height: 8),
              Text(
                _verifyError!,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isEmailValid && !_isVerifying) ? _verifyAndContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha:0.3),
                      disabledForegroundColor: Colors.white.withValues(alpha:0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ادامه'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
