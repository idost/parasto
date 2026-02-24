#!/usr/bin/env dart
// CC-PARASTO-FA-STRINGS-012: Export all hard-coded Persian/Farsi UI strings
//
// This script scans lib/**/*.dart files for string literals containing
// Persian/Arabic Unicode characters and exports them to CSV for review.
//
// Usage: dart tools/export_farsi_strings.dart

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() async {
  print('🔍 Scanning for Persian/Farsi strings...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Error: lib/ directory not found');
    exit(1);
  }

  final strings = <FarsiString>[];
  final duplicates = <String, List<FarsiString>>{};

  // Scan all .dart files
  await for (final file in libDir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final found = await extractStringsFromFile(file);
      strings.addAll(found);
    }
  }

  print('✓ Found ${strings.length} Persian/Farsi strings\n');

  // Sort by file, then line
  strings.sort((a, b) {
    final fileCompare = a.file.compareTo(b.file);
    return fileCompare != 0 ? fileCompare : a.line.compareTo(b.line);
  });

  // Find duplicates
  final textToStrings = <String, List<FarsiString>>{};
  for (final str in strings) {
    textToStrings.putIfAbsent(str.text, () => []).add(str);
  }
  for (final entry in textToStrings.entries) {
    if (entry.value.length > 1) {
      duplicates[entry.key] = entry.value;
    }
  }

  // Generate CSV
  await generateCsv(strings);

  // Generate report
  generateReport(strings, duplicates);
}

class FarsiString {
  final String id;
  final String text;
  final String file;
  final int line;
  final String context;

  FarsiString({
    required this.id,
    required this.text,
    required this.file,
    required this.line,
    required this.context,
  });

  String toCsvRow() {
    // Escape quotes and commas for CSV
    String escape(String s) => '"${s.replaceAll('"', '""')}"';
    return '${escape(id)},${escape(text)},${escape(file)},$line,${escape(context)}';
  }
}

Future<List<FarsiString>> extractStringsFromFile(File file) async {
  final strings = <FarsiString>[];
  final lines = await file.readAsLines();
  final relativePath = file.path.replaceFirst(RegExp(r'^.*lib/'), 'lib/');

  for (var i = 0; i < lines.length; i++) {
    final lineNum = i + 1;
    final line = lines[i];

    // Find all string literals in this line
    final matches = extractStringsFromLine(line);

    for (final match in matches) {
      if (containsFarsi(match)) {
        final context = extractContext(line, match);
        final id = generateId(relativePath, lineNum, match);

        strings.add(FarsiString(
          id: id,
          text: match,
          file: relativePath,
          line: lineNum,
          context: context,
        ));
      }
    }
  }

  return strings;
}

List<String> extractStringsFromLine(String line) {
  final strings = <String>[];

  // Match single-quoted strings: 'text'
  final singleQuoteRegex = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
  for (final match in singleQuoteRegex.allMatches(line)) {
    final content = match.group(1);
    if (content != null && content.isNotEmpty) {
      strings.add(unescapeString(content));
    }
  }

  // Match double-quoted strings: "text"
  final doubleQuoteRegex = RegExp(r'"([^"\\]*(?:\\.[^"\\]*)*)"');
  for (final match in doubleQuoteRegex.allMatches(line)) {
    final content = match.group(1);
    if (content != null && content.isNotEmpty) {
      strings.add(unescapeString(content));
    }
  }

  return strings;
}

String unescapeString(String s) {
  return s
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t');
}

bool containsFarsi(String text) {
  // Persian/Arabic Unicode ranges:
  // 0600-06FF: Arabic
  // 0750-077F: Arabic Supplement
  // 08A0-08FF: Arabic Extended-A
  // FB50-FDFF: Arabic Presentation Forms-A
  // FE70-FEFF: Arabic Presentation Forms-B

  // Also check for Persian punctuation: « » ٪ ، ؛

  for (final char in text.runes) {
    if ((char >= 0x0600 && char <= 0x06FF) ||
        (char >= 0x0750 && char <= 0x077F) ||
        (char >= 0x08A0 && char <= 0x08FF) ||
        (char >= 0xFB50 && char <= 0xFDFF) ||
        (char >= 0xFE70 && char <= 0xFEFF)) {
      return true;
    }
  }

  return false;
}

String extractContext(String line, String text) {
  // Try to determine the widget or context
  final trimmed = line.trim();

  // Check for common widgets
  if (trimmed.startsWith('Text(')) return 'Text';
  if (trimmed.contains('SnackBar(')) return 'SnackBar';
  if (trimmed.contains('AlertDialog(')) return 'AlertDialog';
  if (trimmed.contains('title:')) return 'title';
  if (trimmed.contains('label:')) return 'label';
  if (trimmed.contains('hintText:')) return 'hintText';
  if (trimmed.contains('labelText:')) return 'labelText';
  if (trimmed.contains('helperText:')) return 'helperText';
  if (trimmed.contains('errorText:')) return 'errorText';
  if (trimmed.contains('message:')) return 'message';
  if (trimmed.contains('content:')) return 'content';
  if (trimmed.contains('AppBar(')) return 'AppBar';
  if (trimmed.contains('TextButton(')) return 'TextButton';
  if (trimmed.contains('ElevatedButton(')) return 'ElevatedButton';
  if (trimmed.contains('OutlinedButton(')) return 'OutlinedButton';
  if (trimmed.contains('IconButton(')) return 'IconButton';
  if (trimmed.contains('FloatingActionButton(')) return 'FloatingActionButton';
  if (trimmed.contains('Tooltip(')) return 'Tooltip';
  if (trimmed.contains('Chip(')) return 'Chip';
  if (trimmed.contains('ListTile(')) return 'ListTile';
  if (trimmed.contains('TextField(')) return 'TextField';
  if (trimmed.contains('TextFormField(')) return 'TextFormField';
  if (trimmed.contains('DropdownMenuItem(')) return 'DropdownMenuItem';
  if (trimmed.contains('RadioListTile(')) return 'RadioListTile';
  if (trimmed.contains('SwitchListTile(')) return 'SwitchListTile';
  if (trimmed.contains('CheckboxListTile(')) return 'CheckboxListTile';
  if (trimmed.contains('showDialog(')) return 'Dialog';
  if (trimmed.contains('showModalBottomSheet(')) return 'BottomSheet';

  // Default: show first 50 chars of line
  return trimmed.length > 50 ? '${trimmed.substring(0, 47)}...' : trimmed;
}

String generateId(String file, int line, String text) {
  // Generate stable ID: first 12 chars of SHA256 hash of file+line+text
  final input = '$file:$line:$text';
  final bytes = utf8.encode(input);
  final hash = sha256.convert(bytes);
  return hash.toString().substring(0, 12);
}

Future<void> generateCsv(List<FarsiString> strings) async {
  final file = File('farsi_strings_inventory.csv');
  final sink = file.openWrite();

  // Write header
  sink.writeln('id,original_text,file,line,widget_or_context');

  // Write rows
  for (final str in strings) {
    sink.writeln(str.toCsvRow());
  }

  await sink.flush();
  await sink.close();

  print('✓ Exported to: farsi_strings_inventory.csv\n');
}

void generateReport(List<FarsiString> strings, Map<String, List<FarsiString>> duplicates) {
  print('=' * 60);
  print('REPORT: Persian/Farsi String Inventory');
  print('=' * 60);
  print('');

  // Total count
  print('📊 Total Strings: ${strings.length}');
  print('');

  // Count by file
  final fileCount = <String, int>{};
  for (final str in strings) {
    fileCount[str.file] = (fileCount[str.file] ?? 0) + 1;
  }

  // Top 10 files
  final sortedFiles = fileCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('📁 Top 10 Files by String Count:');
  print('-' * 60);
  for (var i = 0; i < 10 && i < sortedFiles.length; i++) {
    final entry = sortedFiles[i];
    print('${(i + 1).toString().padLeft(2)}. ${entry.value.toString().padLeft(3)} strings - ${entry.key}');
  }
  print('');

  // Duplicates
  print('🔄 Duplicate Strings:');
  print('-' * 60);
  if (duplicates.isEmpty) {
    print('   No duplicates found.');
  } else {
    print('   Found ${duplicates.length} unique strings that appear multiple times:');
    print('');

    final sortedDuplicates = duplicates.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    var count = 0;
    for (final entry in sortedDuplicates) {
      if (count >= 10) break; // Show top 10
      count++;

      final text = entry.key.length > 40 ? '${entry.key.substring(0, 37)}...' : entry.key;
      print('   "${text}"');
      print('   → Appears ${entry.value.length} times in:');
      for (final str in entry.value) {
        print('      - ${str.file}:${str.line}');
      }
      print('');
    }

    if (sortedDuplicates.length > 10) {
      print('   ... and ${sortedDuplicates.length - 10} more duplicates');
    }
  }
  print('');

  print('✅ Export complete!');
  print('=' * 60);
}
