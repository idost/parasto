import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Helpers/dictionary_service.dart';
import 'theme_colors.dart';

/// Apple Books-style Look Up / Dictionary sheet
/// Shows Farsi-Farsi and Farsi-English definitions for selected word
class AppleLookUpSheet extends StatefulWidget {
  final String word;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final String fontFamily;
  final VoidCallback onClose;
  final Function(String)? onSearchInBook;

  const AppleLookUpSheet({
    super.key,
    required this.word,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    this.fontFamily = 'IRANSans',
    required this.onClose,
    this.onSearchInBook,
  });

  @override
  State<AppleLookUpSheet> createState() => _AppleLookUpSheetState();
}

class _AppleLookUpSheetState extends State<AppleLookUpSheet> {
  DictionaryResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookupWord();
  }

  Future<void> _lookupWord() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await DictionaryService.lookup(widget.word);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'خطا در دریافت تعریف';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.backgroundColor.computeLuminance() < 0.5;
    final sheetBg = isDark ? cParastoSurface : Colors.white;
    final sheetText = isDark ? Colors.white : Colors.black;
    final subtleText = sheetText.withAlpha(153);
    final cardBg = isDark ? cParastoSurfaceLight : const Color(0xFFF2F2F7);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: subtleText.withAlpha(51),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with word and close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.word,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: sheetText,
                      fontFamily: widget.fontFamily,
                      package: 'cosmos_epub',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: subtleText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: subtleText.withAlpha(25)),

          // Dictionary content
          Expanded(
            child: _isLoading
                ? _buildLoadingState(subtleText)
                : _error != null
                    ? _buildErrorState(sheetText, subtleText)
                    : _buildDictionaryContent(
                        sheetText, subtleText, cardBg, isDark),
          ),

          // Action buttons at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(
                top: BorderSide(color: subtleText.withAlpha(25)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.search_rounded,
                      label: 'جستجو در کتاب',
                      accentColor: widget.accentColor,
                      isDark: isDark,
                      onTap: () {
                        if (widget.onSearchInBook != null) {
                          widget.onClose();
                          widget.onSearchInBook!(widget.word);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.language_rounded,
                      label: 'جستجو در وب',
                      accentColor: widget.accentColor,
                      isDark: isDark,
                      onTap: () => _searchWeb(widget.word),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color subtleText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'در حال جستجو...',
            style: TextStyle(
              fontSize: 14,
              color: subtleText,
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color sheetText, Color subtleText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: subtleText,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'خطا در دریافت تعریف',
            style: TextStyle(
              fontSize: 14,
              color: subtleText,
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _lookupWord,
            child: Text(
              'تلاش مجدد',
              style: TextStyle(
                color: widget.accentColor,
                fontFamily: widget.fontFamily,
                package: 'cosmos_epub',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryContent(
    Color sheetText,
    Color subtleText,
    Color cardBg,
    bool isDark,
  ) {
    final result = _result;
    final hasFarsiToFarsi = result != null && result.farsiToFarsi.isNotEmpty;
    final hasFarsiToEnglish = result != null && result.farsiToEnglish.isNotEmpty;

    if (!hasFarsiToFarsi && !hasFarsiToEnglish) {
      return _buildNoResultsState(sheetText, subtleText);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farsi-to-Farsi section
            if (hasFarsiToFarsi) ...[
              _SectionHeader(
                title: 'لغت‌نامه فارسی',
                icon: Icons.menu_book_rounded,
                isDark: isDark,
                fontFamily: widget.fontFamily,
              ),
              const SizedBox(height: 12),
              ...result!.farsiToFarsi.map((entry) => _buildDefinitionCard(
                    entry,
                    cardBg,
                    sheetText,
                    subtleText,
                    isDark,
                  )),
              const SizedBox(height: 24),
            ],

            // Farsi-to-English section
            if (hasFarsiToEnglish) ...[
              _SectionHeader(
                title: 'ترجمه انگلیسی',
                icon: Icons.translate_rounded,
                isDark: isDark,
                fontFamily: widget.fontFamily,
              ),
              const SizedBox(height: 12),
              ...result!.farsiToEnglish.map((entry) => _buildDefinitionCard(
                    entry,
                    cardBg,
                    sheetText,
                    subtleText,
                    isDark,
                    isEnglish: true,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(Color sheetText, Color subtleText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: subtleText,
          ),
          const SizedBox(height: 16),
          Text(
            'تعریفی یافت نشد',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: sheetText,
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'می‌توانید در وب جستجو کنید',
            style: TextStyle(
              fontSize: 14,
              color: subtleText,
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionCard(
    DictionaryEntry entry,
    Color cardBg,
    Color sheetText,
    Color subtleText,
    bool isDark, {
    bool isEnglish = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word with pronunciation and part of speech
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.word,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: sheetText,
                    fontFamily: widget.fontFamily,
                    package: 'cosmos_epub',
                  ),
                ),
              ),
              if (entry.partOfSpeech != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.partOfSpeech!,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.accentColor,
                      fontFamily: widget.fontFamily,
                      package: 'cosmos_epub',
                    ),
                  ),
                ),
            ],
          ),

          if (entry.pronunciation != null) ...[
            const SizedBox(height: 4),
            Text(
              '/${entry.pronunciation}/',
              style: TextStyle(
                fontSize: 14,
                color: subtleText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Definition
          Text(
            entry.definition,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: sheetText.withAlpha(230),
              fontFamily: isEnglish ? null : widget.fontFamily,
              package: isEnglish ? null : 'cosmos_epub',
            ),
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
          ),

          // Example
          if (entry.example != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(13)
                    : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  right: BorderSide(
                    color: widget.accentColor,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                entry.example!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: subtleText,
                  fontFamily: widget.fontFamily,
                  package: 'cosmos_epub',
                ),
              ),
            ),
          ],

          // Source
          const SizedBox(height: 12),
          Text(
            'منبع: ${entry.source}',
            style: TextStyle(
              fontSize: 11,
              color: subtleText.withAlpha(128),
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchWeb(String word) async {
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent('$word معنی')}'
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final String fontFamily;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            fontFamily: fontFamily,
            package: 'cosmos_epub',
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Look Up sheet
void showAppleLookUpSheet({
  required BuildContext context,
  required String word,
  required Color backgroundColor,
  required Color textColor,
  required Color accentColor,
  String fontFamily = 'IRANSans',
  Function(String)? onSearchInBook,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => AppleLookUpSheet(
      word: word,
      backgroundColor: backgroundColor,
      textColor: textColor,
      accentColor: accentColor,
      fontFamily: fontFamily,
      onClose: () => Navigator.pop(context),
      onSearchInBook: onSearchInBook,
    ),
  );
}
