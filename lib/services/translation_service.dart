import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Translation service for dynamic content (book titles, descriptions, etc.)
/// Uses Microsoft Azure Translator API for high-quality Farsi to Tajiki/English translation.
/// Includes local caching to minimize API calls.
///
/// Azure Translator is used because it provides true semantic translation for Tajiki (tg),
/// not just script transliteration. This is critical for proper Farsi → Tajiki translation.
///
/// Usage:
/// ```dart
/// final translationService = ref.read(translationServiceProvider);
/// final translated = await translationService.translate(text, targetLang: 'tg');
/// ```
final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

class TranslationService {
  static const String _cachePrefix = 'translation_cache_';
  static const int _maxCacheEntries = 500;

  final Dio _dio = Dio();

  // In-memory cache for faster access during session
  final Map<String, String> _memoryCache = {};

  /// Azure Translator API credentials
  String? _azureKey;
  String? _azureRegion;

  /// Initialize with Azure Translator credentials
  /// [azureKey] - Azure Cognitive Services subscription key
  /// [azureRegion] - Azure region (e.g., 'eastus', 'westeurope')
  void initialize(String azureKey, {String azureRegion = 'eastus'}) {
    _azureKey = azureKey;
    _azureRegion = azureRegion;
  }

  /// Check if the service is properly configured
  bool get isConfigured => _azureKey != null && _azureKey!.isNotEmpty;

  /// Translate text from Farsi to target language using Azure Translator
  /// [text] - The Farsi text to translate
  /// [targetLang] - Target language code: 'tg' for Tajiki, 'en' for English
  ///
  /// Returns the translated text, or original text if translation fails
  Future<String> translate(String? text, {required String targetLang}) async {
    if (text == null || text.isEmpty) return '';

    // Farsi doesn't need translation
    if (targetLang == 'fa') return text;

    // Check memory cache first
    final cacheKey = _getCacheKey(text, targetLang);
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // Check persistent cache
    final cachedResult = await _getFromCache(cacheKey);
    if (cachedResult != null) {
      _memoryCache[cacheKey] = cachedResult;
      return cachedResult;
    }

    // If no API key, return original text
    if (!isConfigured) {
      return text;
    }

    // Call Azure Translator API
    try {
      final translated = await _translateWithAzure(text, targetLang);

      // Cache the result
      await _saveToCache(cacheKey, translated);
      _memoryCache[cacheKey] = translated;

      return translated;
    } catch (e) {
      // On error, return original text
      return text;
    }
  }

  /// Translate multiple texts in batch (more efficient for API calls)
  /// Azure Translator supports up to 100 texts per request
  Future<List<String>> translateBatch(List<String?> texts, {required String targetLang}) async {
    if (texts.isEmpty) return [];

    // Farsi doesn't need translation
    if (targetLang == 'fa') {
      return texts.map((t) => t ?? '').toList();
    }

    final results = List<String>.filled(texts.length, '');
    final textsToTranslate = <String>[];
    final textsToTranslateIndices = <int>[];

    // Check cache for each text
    for (int i = 0; i < texts.length; i++) {
      final text = texts[i];
      if (text == null || text.isEmpty) {
        results[i] = '';
        continue;
      }

      final cacheKey = _getCacheKey(text, targetLang);

      // Check memory cache
      if (_memoryCache.containsKey(cacheKey)) {
        results[i] = _memoryCache[cacheKey]!;
        continue;
      }

      // Check persistent cache
      final cachedResult = await _getFromCache(cacheKey);
      if (cachedResult != null) {
        _memoryCache[cacheKey] = cachedResult;
        results[i] = cachedResult;
        continue;
      }

      // Need to translate
      textsToTranslate.add(text);
      textsToTranslateIndices.add(i);
      results[i] = text; // Placeholder, will be replaced
    }

    // If nothing to translate or not configured, return results
    if (textsToTranslate.isEmpty || !isConfigured) {
      return results;
    }

    // Batch translate using Azure (max 100 per request)
    try {
      // Split into chunks of 100 if needed
      const chunkSize = 100;
      for (int chunkStart = 0; chunkStart < textsToTranslate.length; chunkStart += chunkSize) {
        final chunkEnd = (chunkStart + chunkSize < textsToTranslate.length)
            ? chunkStart + chunkSize
            : textsToTranslate.length;
        final chunk = textsToTranslate.sublist(chunkStart, chunkEnd);
        final chunkIndices = textsToTranslateIndices.sublist(chunkStart, chunkEnd);

        final translated = await _translateBatchWithAzure(chunk, targetLang);

        // Update results and cache
        for (int i = 0; i < translated.length; i++) {
          final originalIndex = chunkIndices[i];
          final originalText = chunk[i];
          final translatedText = translated[i];

          results[originalIndex] = translatedText;

          final cacheKey = _getCacheKey(originalText, targetLang);
          await _saveToCache(cacheKey, translatedText);
          _memoryCache[cacheKey] = translatedText;
        }
      }
    } catch (e) {
      // On error, results already contain original text as fallback
    }

    return results;
  }

  /// Call Microsoft Azure Translator API for single text
  Future<String> _translateWithAzure(String text, String targetLang) async {
    final response = await _dio.post<List<dynamic>>(
      'https://api.cognitive.microsofttranslator.com/translate',
      queryParameters: {
        'api-version': '3.0',
        'from': 'fa',
        'to': targetLang,
      },
      options: Options(
        headers: {
          'Ocp-Apim-Subscription-Key': _azureKey,
          'Ocp-Apim-Subscription-Region': _azureRegion,
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode([
        {'Text': text},
      ]),
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data!;
      if (data.isNotEmpty) {
        final translations = data[0]['translations'] as List<dynamic>;
        if (translations.isNotEmpty) {
          return translations[0]['text'] as String;
        }
      }
    }

    throw Exception('Azure translation failed: ${response.statusCode}');
  }

  /// Batch translate using Microsoft Azure Translator API
  Future<List<String>> _translateBatchWithAzure(List<String> texts, String targetLang) async {
    final requestBody = texts.map((text) => {'Text': text}).toList();

    final response = await _dio.post<List<dynamic>>(
      'https://api.cognitive.microsofttranslator.com/translate',
      queryParameters: {
        'api-version': '3.0',
        'from': 'fa',
        'to': targetLang,
      },
      options: Options(
        headers: {
          'Ocp-Apim-Subscription-Key': _azureKey,
          'Ocp-Apim-Subscription-Region': _azureRegion,
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data!;
      return data.map<String>((item) {
        final translations = item['translations'] as List<dynamic>;
        if (translations.isNotEmpty) {
          return translations[0]['text'] as String;
        }
        return '';
      }).toList();
    }

    throw Exception('Azure batch translation failed: ${response.statusCode}');
  }

  String _getCacheKey(String text, String targetLang) {
    // Use hash + length to reduce collision risk (hashCode alone can collide)
    final hash = text.hashCode.toRadixString(16);
    return '${targetLang}_${hash}_${text.length}';
  }

  Future<String?> _getFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_cachePrefix$key');
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToCache(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);

      // Simple cache size management - track keys
      final cacheKeys = prefs.getStringList('${_cachePrefix}keys') ?? [];
      if (!cacheKeys.contains(key)) {
        cacheKeys.add(key);

        // If cache is too large, remove oldest entries
        if (cacheKeys.length > _maxCacheEntries) {
          final keysToRemove = cacheKeys.sublist(0, cacheKeys.length - _maxCacheEntries);
          for (final oldKey in keysToRemove) {
            await prefs.remove('$_cachePrefix$oldKey');
          }
          cacheKeys.removeRange(0, keysToRemove.length);
        }

        await prefs.setStringList('${_cachePrefix}keys', cacheKeys);
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Clear all cached translations
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = prefs.getStringList('${_cachePrefix}keys') ?? [];

      for (final key in cacheKeys) {
        await prefs.remove('$_cachePrefix$key');
      }
      await prefs.remove('${_cachePrefix}keys');

      _memoryCache.clear();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Pre-cache translations for a list of texts
  /// Call this when loading data to pre-translate in background
  Future<void> preCacheTranslations(List<String?> texts, {required String targetLang}) async {
    if (targetLang == 'fa') return;
    await translateBatch(texts, targetLang: targetLang);
  }
}
