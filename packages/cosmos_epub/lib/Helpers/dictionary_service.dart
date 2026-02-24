import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dictionary entry with definition and metadata
class DictionaryEntry {
  final String word;
  final String? pronunciation;
  final String? partOfSpeech;
  final String definition;
  final String? example;
  final String source;
  final bool isFarsiToFarsi;

  const DictionaryEntry({
    required this.word,
    this.pronunciation,
    this.partOfSpeech,
    required this.definition,
    this.example,
    required this.source,
    this.isFarsiToFarsi = true,
  });

  factory DictionaryEntry.fromVajehyab(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] ?? '',
      pronunciation: json['pronunciation'],
      partOfSpeech: json['pos'],
      definition: json['meaning'] ?? json['definition'] ?? '',
      example: json['example'],
      source: 'واژه‌یاب',
      isFarsiToFarsi: true,
    );
  }

  factory DictionaryEntry.fromGlosbe(Map<String, dynamic> json, String word) {
    final meanings = json['tuc'] as List<dynamic>? ?? [];
    String definition = '';

    if (meanings.isNotEmpty) {
      final firstMeaning = meanings.first;
      if (firstMeaning['phrase'] != null) {
        definition = firstMeaning['phrase']['text'] ?? '';
      } else if (firstMeaning['meanings'] != null) {
        final meaningsList = firstMeaning['meanings'] as List<dynamic>;
        if (meaningsList.isNotEmpty) {
          definition = meaningsList.first['text'] ?? '';
        }
      }
    }

    return DictionaryEntry(
      word: word,
      definition: definition,
      source: 'Glosbe',
      isFarsiToFarsi: false,
    );
  }

  factory DictionaryEntry.fromFreeDict(Map<String, dynamic> json) {
    final meanings = json['meanings'] as List<dynamic>? ?? [];
    String definition = '';
    String? partOfSpeech;
    String? example;

    if (meanings.isNotEmpty) {
      final firstMeaning = meanings.first;
      partOfSpeech = firstMeaning['partOfSpeech'];
      final definitions = firstMeaning['definitions'] as List<dynamic>? ?? [];
      if (definitions.isNotEmpty) {
        definition = definitions.first['definition'] ?? '';
        example = definitions.first['example'];
      }
    }

    final phonetics = json['phonetics'] as List<dynamic>? ?? [];
    String? pronunciation;
    if (phonetics.isNotEmpty) {
      pronunciation = phonetics.first['text'];
    }

    return DictionaryEntry(
      word: json['word'] ?? '',
      pronunciation: pronunciation,
      partOfSpeech: partOfSpeech,
      definition: definition,
      example: example,
      source: 'Free Dictionary',
      isFarsiToFarsi: false,
    );
  }
}

/// Dictionary lookup result containing multiple entries
class DictionaryResult {
  final String word;
  final List<DictionaryEntry> farsiToFarsi;
  final List<DictionaryEntry> farsiToEnglish;
  final bool isLoading;
  final String? error;

  const DictionaryResult({
    required this.word,
    this.farsiToFarsi = const [],
    this.farsiToEnglish = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasResults => farsiToFarsi.isNotEmpty || farsiToEnglish.isNotEmpty;
  bool get hasError => error != null;

  DictionaryResult copyWith({
    String? word,
    List<DictionaryEntry>? farsiToFarsi,
    List<DictionaryEntry>? farsiToEnglish,
    bool? isLoading,
    String? error,
  }) {
    return DictionaryResult(
      word: word ?? this.word,
      farsiToFarsi: farsiToFarsi ?? this.farsiToFarsi,
      farsiToEnglish: farsiToEnglish ?? this.farsiToEnglish,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Dictionary service for Persian word lookups
/// Supports Farsi-to-Farsi and Farsi-to-English translations
class DictionaryService {
  static const _perApiTimeout = Duration(seconds: 8);
  static const _overallTimeout = Duration(seconds: 12); // Overall timeout for entire lookup
  static const _maxCacheSize = 100; // Limit cache to prevent memory issues

  // Simple in-memory cache with size limit
  static final Map<String, DictionaryResult> _cache = {};
  static final List<String> _cacheKeys = []; // Track insertion order for LRU

  /// Look up a word in both Farsi-Farsi and Farsi-English dictionaries
  static Future<DictionaryResult> lookup(String word) async {
    // Normalize the word
    final normalizedWord = _normalizeWord(word);

    // Check cache first
    if (_cache.containsKey(normalizedWord)) {
      return _cache[normalizedWord]!;
    }

    try {
      // Run both lookups in parallel with overall timeout
      final results = await Future.wait([
        _lookupFarsiToFarsi(normalizedWord),
        _lookupFarsiToEnglish(normalizedWord),
      ]).timeout(_overallTimeout);

      final farsiToFarsi = results[0];
      final farsiToEnglish = results[1];

      final result = DictionaryResult(
        word: normalizedWord,
        farsiToFarsi: farsiToFarsi,
        farsiToEnglish: farsiToEnglish,
      );

      // Cache the result with LRU eviction
      _addToCache(normalizedWord, result);

      return result;
    } catch (e) {
      // Return error result instead of crashing
      return DictionaryResult(
        word: normalizedWord,
        error: 'خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
    }
  }

  /// Add to cache with LRU eviction when cache is full
  static void _addToCache(String key, DictionaryResult result) {
    // Remove oldest entries if cache is full
    while (_cacheKeys.length >= _maxCacheSize) {
      final oldestKey = _cacheKeys.removeAt(0);
      _cache.remove(oldestKey);
    }

    _cache[key] = result;
    _cacheKeys.add(key);
  }

  /// Normalize Persian word (remove diacritics, normalize characters)
  static String _normalizeWord(String word) {
    return word
        .trim()
        // Remove Arabic diacritics (tashkeel)
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        // Normalize Arabic/Persian characters
        .replaceAll('ك', 'ک')
        .replaceAll('ي', 'ی')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا');
  }

  /// Look up word in Farsi-to-Farsi dictionaries
  static Future<List<DictionaryEntry>> _lookupFarsiToFarsi(String word) async {
    final entries = <DictionaryEntry>[];

    try {
      // Try Vajehyab-like API (free Persian dictionary)
      // Note: This is a placeholder - in production use actual API
      final vajehyabResult = await _queryVajehyab(word);
      if (vajehyabResult != null) {
        entries.add(vajehyabResult);
      }
    } catch (e) {
      // Silently fail, we have fallbacks
    }

    // Fallback: Try Wiktionary Persian
    if (entries.isEmpty) {
      try {
        final wikiResult = await _queryWiktionaryPersian(word);
        if (wikiResult != null) {
          entries.add(wikiResult);
        }
      } catch (e) {
        // Silently fail
      }
    }

    return entries;
  }

  /// Look up word in Farsi-to-English dictionaries
  static Future<List<DictionaryEntry>> _lookupFarsiToEnglish(String word) async {
    final entries = <DictionaryEntry>[];

    try {
      // Try Glosbe API (free multilingual dictionary)
      final glosbeResult = await _queryGlosbe(word, 'fa', 'en');
      if (glosbeResult != null) {
        entries.add(glosbeResult);
      }
    } catch (e) {
      // Silently fail
    }

    return entries;
  }

  /// Query Vajehyab-style API for Persian definitions
  static Future<DictionaryEntry?> _queryVajehyab(String word) async {
    try {
      // Using a free Persian dictionary API
      // vajehyab.com doesn't have a public API, so we use alternatives

      // Try Farsidic API (if available)
      final url = Uri.parse(
        'https://api.farsidic.com/api/v1/lookup?q=${Uri.encodeComponent(word)}'
      );

      final response = await http.get(url).timeout(_perApiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          return DictionaryEntry(
            word: word,
            definition: result['definition'] ?? result['meaning'] ?? '',
            source: 'فرهنگ فارسی',
            isFarsiToFarsi: true,
          );
        }
      }
    } catch (e) {
      // API not available, try fallback
    }

    return null;
  }

  /// Query Persian Wiktionary for definitions
  static Future<DictionaryEntry?> _queryWiktionaryPersian(String word) async {
    try {
      final url = Uri.parse(
        'https://fa.wiktionary.org/w/api.php?'
        'action=query&format=json&prop=extracts&exintro=true&explaintext=true&'
        'titles=${Uri.encodeComponent(word)}'
      );

      final response = await http.get(url).timeout(_perApiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final page = pages.values.first;
          final extract = page['extract'] as String?;

          if (extract != null && extract.isNotEmpty && !page.containsKey('missing')) {
            // Clean up the extract
            String definition = extract
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .take(3)
                .join('\n');

            if (definition.length > 500) {
              definition = '${definition.substring(0, 500)}...';
            }

            return DictionaryEntry(
              word: word,
              definition: definition,
              source: 'ویکی‌واژه',
              isFarsiToFarsi: true,
            );
          }
        }
      }
    } catch (e) {
      // Silently fail
    }

    return null;
  }

  /// Query Glosbe API for translations
  static Future<DictionaryEntry?> _queryGlosbe(
    String word,
    String fromLang,
    String toLang,
  ) async {
    try {
      final url = Uri.parse(
        'https://glosbe.com/gapi/translate?'
        'from=$fromLang&dest=$toLang&format=json&'
        'phrase=${Uri.encodeComponent(word)}'
      );

      final response = await http.get(url).timeout(_perApiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tuc = data['tuc'] as List<dynamic>?;

        if (tuc != null && tuc.isNotEmpty) {
          final translations = <String>[];

          for (final entry in tuc.take(5)) {
            if (entry['phrase'] != null) {
              translations.add(entry['phrase']['text']);
            }
          }

          if (translations.isNotEmpty) {
            return DictionaryEntry(
              word: word,
              definition: translations.join('، '),
              source: 'Glosbe',
              isFarsiToFarsi: false,
            );
          }
        }
      }
    } catch (e) {
      // Silently fail
    }

    return null;
  }

  /// Clear the cache
  static void clearCache() {
    _cache.clear();
  }
}
