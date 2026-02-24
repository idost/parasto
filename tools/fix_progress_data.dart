// ============================================================================
// ONE-TIME PROGRESS DATA CLEANUP TOOL
// ============================================================================
//
// PURPOSE:
// This script recalculates completion_percentage for all rows in the
// listening_progress table using the corrected album-level calculation logic.
//
// WHEN TO RUN:
// After deploying the fixed audio_provider.dart::_saveProgress() logic.
// Run ONCE to fix historical data. New data will be correct automatically.
//
// HOW TO RUN:
// 1. Make sure you have Dart SDK installed
// 2. Navigate to the myna_flutter directory
// 3. Run: dart run tools/fix_progress_data.dart
//
// PRECAUTIONS:
// - BACKUP YOUR DATABASE FIRST (via Supabase dashboard)
// - Test on a small subset first using DRY_RUN = true
// - Review the output before setting DRY_RUN = false
//
// WHAT IT DOES:
// 1. Fetches all listening_progress rows
// 2. For each row, fetches the audiobook's chapters with durations
// 3. Recalculates completion_percentage using the same logic as _saveProgress():
//    - Previous chapters: count as 100% listened
//    - Current chapter: use position_seconds, capped at chapter duration
//    - Future chapters: count as 0% listened
//    - Chapter completion threshold: 95% → counts as 100%
//    - Album near-completion threshold: 98% → displays as 100%
// 4. Updates the row if the new value differs significantly
//
// ============================================================================

import 'dart:io';
import 'package:supabase/supabase.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================

/// Set to true to preview changes without writing to database
const bool DRY_RUN = true;

/// Only process this many rows (set to -1 for all)
const int LIMIT = 10;

/// Completion threshold: if a chapter is ≥95% listened, count as fully complete
const double CHAPTER_COMPLETION_THRESHOLD = 0.95;

/// Near-completion threshold: if album is ≥98% complete, round to 100%
const double ALBUM_NEAR_COMPLETION_THRESHOLD = 0.98;

/// Minimum difference to trigger an update (avoid updating 45% → 45%)
const int MIN_DIFFERENCE_TO_UPDATE = 1;

// ============================================================================
// MAIN
// ============================================================================

Future<void> main() async {
  print('');
  print('=' * 60);
  print('PROGRESS DATA CLEANUP TOOL');
  print('=' * 60);
  print('');
  print('Mode: ${DRY_RUN ? "DRY RUN (no changes will be made)" : "LIVE (will update database)"}');
  print('Limit: ${LIMIT == -1 ? "All rows" : "$LIMIT rows"}');
  print('');

  // Load environment variables from .env file
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('ERROR: .env file not found in current directory');
    print('Please run this script from the myna_flutter directory');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final envMap = <String, String>{};
  for (final line in envContent.split('\n')) {
    if (line.contains('=') && !line.startsWith('#')) {
      final parts = line.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        envMap[key] = value;
      }
    }
  }

  final supabaseUrl = envMap['SUPABASE_URL'];
  final supabaseServiceKey = envMap['SUPABASE_SERVICE_ROLE_KEY'] ?? envMap['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseServiceKey == null) {
    print('ERROR: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    print('For full access, add SUPABASE_SERVICE_ROLE_KEY to .env');
    exit(1);
  }

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseServiceKey);
  print('Connected!\n');

  // Fetch listening_progress rows
  print('Fetching listening_progress rows...');

  var query = supabase
      .from('listening_progress')
      .select('id, user_id, audiobook_id, current_chapter_index, position_seconds, completion_percentage, is_completed')
      .order('last_played_at', ascending: false);

  if (LIMIT > 0) {
    query = query.limit(LIMIT);
  }

  final progressRows = await query as List;
  print('Found ${progressRows.length} rows to process\n');

  if (progressRows.isEmpty) {
    print('No rows to process. Exiting.');
    exit(0);
  }

  // Process each row
  int processed = 0;
  int updated = 0;
  int skipped = 0;
  int errors = 0;

  for (final row in progressRows) {
    processed++;
    final progressId = row['id'];
    final audiobookId = row['audiobook_id'] as int;
    final currentChapterIndex = (row['current_chapter_index'] as int?) ?? 0;
    final positionSeconds = (row['position_seconds'] as int?) ?? 0;
    final oldPercentage = (row['completion_percentage'] as int?) ?? 0;
    final isCompleted = row['is_completed'] == true;

    print('[$processed/${progressRows.length}] Processing audiobook_id=$audiobookId...');

    try {
      // Fetch chapters for this audiobook
      final chaptersResponse = await supabase
          .from('chapters')
          .select('id, chapter_index, duration_seconds')
          .eq('audiobook_id', audiobookId)
          .order('chapter_index', ascending: true) as List;

      if (chaptersResponse.isEmpty) {
        print('  ⚠ No chapters found, skipping');
        skipped++;
        continue;
      }

      // Calculate new completion percentage using the same logic as _saveProgress()
      int completedSeconds = 0;
      int totalDuration = 0;

      for (int i = 0; i < chaptersResponse.length; i++) {
        final chapterDuration = (chaptersResponse[i]['duration_seconds'] as int?) ?? 0;
        totalDuration += chapterDuration;

        if (i < currentChapterIndex) {
          // Previous chapters: count as fully listened
          completedSeconds += chapterDuration;
        } else if (i == currentChapterIndex) {
          // Current chapter: use actual position, capped at duration
          final cappedPosition = chapterDuration > 0
              ? positionSeconds.clamp(0, chapterDuration)
              : positionSeconds;

          // Apply completion threshold: if ≥95% through, count as complete
          if (chapterDuration > 0) {
            final chapterProgress = cappedPosition / chapterDuration;
            if (chapterProgress >= CHAPTER_COMPLETION_THRESHOLD) {
              completedSeconds += chapterDuration; // Count as fully complete
            } else {
              completedSeconds += cappedPosition;
            }
          } else {
            completedSeconds += cappedPosition;
          }
        }
        // Future chapters: add 0 (not listened yet)
      }

      // Calculate percentage
      int newPercentage = 0;
      if (totalDuration > 0) {
        final rawPercentage = (completedSeconds * 100.0) / totalDuration;

        // Apply near-completion rounding: if ≥98%, show as 100%
        if (rawPercentage >= ALBUM_NEAR_COMPLETION_THRESHOLD * 100) {
          newPercentage = 100;
        } else {
          newPercentage = rawPercentage.round().clamp(0, 100);
        }
      }

      // If is_completed is true, ensure percentage is 100
      if (isCompleted && newPercentage < 100) {
        newPercentage = 100;
      }

      // Check if update is needed
      final difference = (newPercentage - oldPercentage).abs();
      if (difference < MIN_DIFFERENCE_TO_UPDATE) {
        print('  ⏭ No significant change: $oldPercentage% → $newPercentage% (diff=$difference)');
        skipped++;
        continue;
      }

      print('  📊 $oldPercentage% → $newPercentage% (chapters=${chaptersResponse.length}, totalDur=${totalDuration}s)');

      if (!DRY_RUN) {
        // Update the row
        await supabase
            .from('listening_progress')
            .update({'completion_percentage': newPercentage})
            .eq('id', progressId as Object);
        print('  ✅ Updated');
      } else {
        print('  🔍 Would update (DRY RUN)');
      }
      updated++;

    } catch (e) {
      print('  ❌ Error: $e');
      errors++;
    }
  }

  // Summary
  print('');
  print('=' * 60);
  print('SUMMARY');
  print('=' * 60);
  print('Total processed: $processed');
  print('Updated: $updated');
  print('Skipped (no change): $skipped');
  print('Errors: $errors');
  print('');
  if (DRY_RUN) {
    print('This was a DRY RUN. No changes were made.');
    print('To apply changes, set DRY_RUN = false and run again.');
  } else {
    print('Changes have been applied to the database.');
  }
  print('');
}
