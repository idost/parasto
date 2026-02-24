import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

/// A widget that displays ebook cover images with fallback handling
/// Handles both signed URLs and storage paths
class EbookCoverImage extends StatefulWidget {
  final String? coverUrl;
  final String? coverStoragePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const EbookCoverImage({
    super.key,
    this.coverUrl,
    this.coverStoragePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<EbookCoverImage> createState() => _EbookCoverImageState();
}

class _EbookCoverImageState extends State<EbookCoverImage> {
  String? _resolvedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  @override
  void didUpdateWidget(EbookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.coverStoragePath != widget.coverStoragePath) {
      _resolveUrl();
    }
  }

  Future<void> _resolveUrl() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    String? url = widget.coverUrl;

    // If URL doesn't contain a token (not signed) and we have storage path, try to get signed URL
    if ((url == null || !url.contains('token=')) &&
        widget.coverStoragePath != null &&
        widget.coverStoragePath!.isNotEmpty) {
      try {
        url = await Supabase.instance.client.storage
            .from('ebook-files')
            .createSignedUrl(widget.coverStoragePath!, 3600);
      } catch (e) {
        // Keep using original URL if signing fails
        debugPrint('Failed to sign cover URL: $e');
      }
    }

    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_hasError || _resolvedUrl == null || _resolvedUrl!.isEmpty) {
      child = const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(
          child: Icon(
            Icons.auto_stories,
            color: AppColors.textTertiary,
            size: 32,
          ),
        ),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        fit: widget.fit,
        placeholder: (context, url) => const ColoredBox(
          color: AppColors.surfaceLight,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          // On error, show fallback
          return const ColoredBox(
            color: AppColors.surfaceLight,
            child: Center(
              child: Icon(
                Icons.auto_stories,
                color: AppColors.textTertiary,
                size: 32,
              ),
            ),
          );
        },
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.borderRadius != null
          ? ClipRRect(
              borderRadius: widget.borderRadius!,
              child: child,
            )
          : child,
    );
  }
}
