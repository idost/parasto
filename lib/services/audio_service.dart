import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/app_logger.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(Supabase.instance.client);
});

class AudioService {
  final SupabaseClient _supabase;

  AudioService(this._supabase);

  Future<String?> getAudioUrl(String storagePath) async {
    try {
      final response = _supabase.storage
          .from(Env.audioBucket)
          .getPublicUrl(storagePath);
      return response;
    } catch (e) {
      AppLogger.e('Error getting audio URL', error: e);
      return null;
    }
  }
}
