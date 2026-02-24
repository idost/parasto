import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:cosmos_epub/Helpers/highlights_manager.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/ebook_providers.dart';
import 'package:myna/providers/ebook_sync_provider.dart';
import 'package:myna/utils/app_logger.dart';

/// Full-screen EPUB reader using cosmos_epub
class EpubReaderScreen extends ConsumerStatefulWidget {
  const EpubReaderScreen({super.key});

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  final bool _isOpening = true;

  @override
  void initState() {
    super.initState();
    AppLogger.i('EpubReaderScreen.initState() - calling _openBook()');
    _openBook();
  }

  Future<void> _openBook() async {
    // ignore: avoid_print
    print('[EPUB_READER] _openBook() started');
    final state = ref.read(ebookReaderProvider);
    // ignore: avoid_print
    print('[EPUB_READER] localFilePath: ${state.localFilePath}');
    // ignore: avoid_print
    print('[EPUB_READER] ebook: ${state.ebook}');

    if (state.localFilePath == null) {
      // ignore: avoid_print
      print('[EPUB_READER] ERROR: No local file path for EPUB');
      AppLogger.e('No local file path for EPUB');
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Verify the file exists
    final file = File(state.localFilePath!);
    if (!await file.exists()) {
      // ignore: avoid_print
      print('[EPUB_READER] ERROR: EPUB file does not exist at: ${state.localFilePath}');
      AppLogger.e('EPUB file does not exist at: ${state.localFilePath}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فایل کتاب یافت نشد'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Check file size
    final fileSize = await file.length();
    // ignore: avoid_print
    print('[EPUB_READER] Opening EPUB: ${state.localFilePath}, size: $fileSize bytes');
    AppLogger.i('Opening EPUB: ${state.localFilePath}, size: $fileSize bytes');

    if (fileSize == 0) {
      // ignore: avoid_print
      print('[EPUB_READER] ERROR: EPUB file is empty');
      AppLogger.e('EPUB file is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فایل کتاب خالی است'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      // Ensure CosmosEpub is initialized
      // ignore: avoid_print
      print('[EPUB_READER] Ensuring CosmosEpub is initialized...');
      AppLogger.i('Ensuring CosmosEpub is initialized...');
      try {
        await CosmosEpub.initialize();
        // ignore: avoid_print
        print('[EPUB_READER] CosmosEpub initialized successfully');
        AppLogger.i('CosmosEpub initialized successfully');
      } catch (initError) {
        // ignore: avoid_print
        print('[EPUB_READER] CosmosEpub init warning: $initError');
        AppLogger.w('CosmosEpub already initialized or init error: $initError');
        // Continue anyway - might already be initialized
      }

      // Open the EPUB with cosmos_epub
      // ignore: avoid_print
      print('[EPUB_READER] Calling CosmosEpub.openLocalBook...');
      AppLogger.i('Calling CosmosEpub.openLocalBook...');
      // Get sync service for cloud sync
      final syncNotifier = ref.read(highlightSyncNotifierProvider.notifier);
      final isSyncAvailable = ref.read(isEbookSyncAvailableProvider);

      await CosmosEpub.openLocalBook(
        localPath: state.localFilePath!,
        context: context,
        bookId: state.cosmosBookId,
        onHighlightSync: isSyncAvailable
            ? (HighlightModel highlight, SyncOperation operation) async {
                // Sync highlight to Supabase in background
                AppLogger.d('Syncing highlight: ${operation.name} - ${highlight.id}');
                try {
                  switch (operation) {
                    case SyncOperation.add:
                    case SyncOperation.update:
                      await syncNotifier.uploadHighlight(highlight);
                      break;
                    case SyncOperation.delete:
                      await syncNotifier.deleteHighlight(highlight.id);
                      break;
                  }
                } catch (e) {
                  AppLogger.e('Failed to sync highlight', error: e);
                }
              }
            : null,
        onPageFlip: (int currentPage, int totalPages) {
          // Calculate completion percentage
          final completion = totalPages > 0 ? (currentPage / totalPages) * 100 : 0.0;

          // Update progress in our provider
          ref.read(ebookReaderProvider.notifier).updateProgress(
            chapterIndex: 0, // CosmosEpub doesn't expose chapter index directly
            scrollPercentage: completion,
            completionPercentage: completion,
          );

          AppLogger.d('EPUB Page: $currentPage / $totalPages (${completion.toStringAsFixed(1)}%)');
        },
        onLastPage: (int lastPageIndex) {
          AppLogger.i('Reached last page of EPUB');
          // Mark as 100% complete
          ref.read(ebookReaderProvider.notifier).updateProgress(
            chapterIndex: 0,
            scrollPercentage: 100.0,
            completionPercentage: 100.0,
          );
        },
      );

      AppLogger.i('CosmosEpub closed, returning to previous screen');
      // CosmosEpub opens its own screen, so when it returns, we close this screen too
      if (mounted) {
        ref.read(ebookReaderProvider.notifier).closeReader();
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error opening EPUB', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در باز کردن کتاب: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ebookReaderProvider);

    // Show loading while opening the book
    if (_isOpening || state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'در حال باز کردن کتاب...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (state.ebook?['title_fa'] as String?) ?? '',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (state.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () {
              ref.read(ebookReaderProvider.notifier).closeReader();
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(ebookReaderProvider.notifier).closeReader();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('بازگشت'),
              ),
            ],
          ),
        ),
      );
    }

    // This should not be reached as CosmosEpub handles its own UI
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  @override
  void dispose() {
    // Note: Don't use ref in dispose() - it's already disposed
    // Progress is saved in closeReader() which is called before navigation
    super.dispose();
  }
}

/// Settings bottom sheet for the EPUB reader
class EpubReaderSettingsSheet extends ConsumerWidget {
  const EpubReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ebookReaderSettingsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تنظیمات خواندن',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Font size
          const Text(
            'اندازه متن',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.text_decrease, color: AppColors.textPrimary),
                onPressed: () {
                  ref.read(ebookReaderSettingsProvider.notifier).decreaseFontSize();
                },
              ),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  onChanged: (value) {
                    ref.read(ebookReaderSettingsProvider.notifier).setFontSize(value);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase, color: AppColors.textPrimary),
                onPressed: () {
                  ref.read(ebookReaderSettingsProvider.notifier).increaseFontSize();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Theme selection
          const Text(
            'تم',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _buildThemeChip(context, ref, 'dark', 'تیره', Colors.grey[900]!),
              _buildThemeChip(context, ref, 'light', 'روشن', Colors.white),
              _buildThemeChip(context, ref, 'sepia', 'سپیا', const Color(0xFFF5E6D3)),
              _buildThemeChip(context, ref, 'grey', 'خاکستری', Colors.grey[700]!),
            ],
          ),

          const SizedBox(height: 24),

          // Brightness
          const Text(
            'روشنایی',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.brightness_low, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  value: settings.brightness,
                  min: 0.1,
                  max: 1.0,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  onChanged: (value) {
                    ref.read(ebookReaderSettingsProvider.notifier).setBrightness(value);
                  },
                ),
              ),
              const Icon(Icons.brightness_high, color: AppColors.textSecondary),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemeChip(
    BuildContext context,
    WidgetRef ref,
    String themeId,
    String label,
    Color color,
  ) {
    final settings = ref.watch(ebookReaderSettingsProvider);
    final isSelected = settings.theme == themeId;

    return GestureDetector(
      onTap: () {
        ref.read(ebookReaderSettingsProvider.notifier).setTheme(themeId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Bookmarks list bottom sheet
class EpubBookmarksSheet extends ConsumerWidget {
  const EpubBookmarksSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ebookReaderProvider);
    final bookmarks = state.bookmarks;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نشانک‌ها',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (bookmarks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      color: AppColors.textTertiary,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'هنوز نشانکی اضافه نکرده‌اید',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return ListTile(
                    leading: Icon(
                      bookmark.highlightedText != null
                          ? Icons.format_quote
                          : Icons.bookmark,
                      color: Color(int.parse(
                        bookmark.color?.replaceFirst('#', '0xFF') ?? '0xFFFFD700',
                      )),
                    ),
                    title: Text(
                      bookmark.highlightedText ?? 'فصل ${bookmark.chapterIndex + 1}',
                      style: const TextStyle(color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: bookmark.note != null
                        ? Text(
                            bookmark.note!,
                            style: const TextStyle(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () {
                        ref.read(ebookReaderProvider.notifier).removeBookmark(bookmark.id);
                      },
                    ),
                    onTap: () {
                      // TODO: Navigate to bookmark position
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
