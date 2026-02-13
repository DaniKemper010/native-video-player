/// A lightweight WebVTT parser for sidecar subtitle files
///
/// Parses standard WebVTT (.vtt) files into a list of [VttCue] objects
/// that can be rendered as a Flutter overlay on iOS.

/// Represents a single subtitle cue with start/end times and text
class VttCue {
  const VttCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// When the cue should appear
  final Duration start;

  /// When the cue should disappear
  final Duration end;

  /// The subtitle text (may contain newlines for multi-line cues)
  final String text;

  /// Returns true if this cue should be visible at the given position
  bool isActiveAt(Duration position) {
    return position >= start && position < end;
  }

  @override
  String toString() => 'VttCue($start -> $end: "$text")';
}

/// Parses WebVTT content into a list of cues
class VttParser {
  /// Parses a WebVTT string into a list of [VttCue] objects
  ///
  /// Supports standard WebVTT format including:
  /// - WEBVTT header (required)
  /// - Timestamp format: HH:MM:SS.mmm or MM:SS.mmm
  /// - Multi-line cue text
  /// - Basic HTML tag stripping (<b>, <i>, <u>, <c>, etc.)
  /// - NOTE blocks (skipped)
  /// - STYLE blocks (skipped)
  static List<VttCue> parse(String vttContent) {
    final List<VttCue> cues = <VttCue>[];

    // Normalize line endings
    final String normalized = vttContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> blocks = normalized.split('\n\n');

    if (blocks.isEmpty) {
      return cues;
    }

    // Verify WEBVTT header
    final String firstBlock = blocks.first.trim();
    if (!firstBlock.startsWith('WEBVTT')) {
      return cues;
    }

    // Process each block after the header
    for (int i = 1; i < blocks.length; i++) {
      final String block = blocks[i].trim();
      if (block.isEmpty) {
        continue;
      }

      // Skip NOTE and STYLE blocks
      if (block.startsWith('NOTE') || block.startsWith('STYLE')) {
        continue;
      }

      final VttCue? cue = _parseBlock(block);
      if (cue != null) {
        cues.add(cue);
      }
    }

    return cues;
  }

  /// Parses a single cue block
  static VttCue? _parseBlock(String block) {
    final List<String> lines = block.split('\n');
    if (lines.isEmpty) {
      return null;
    }

    int timestampLineIndex = 0;

    // Check if the first line is a cue identifier (no --> in it)
    if (!lines[0].contains('-->')) {
      timestampLineIndex = 1;
    }

    if (timestampLineIndex >= lines.length) {
      return null;
    }

    // Parse the timestamp line
    final String timestampLine = lines[timestampLineIndex];
    final List<String> parts = timestampLine.split('-->');
    if (parts.length != 2) {
      return null;
    }

    // Strip any positioning/alignment settings after the end timestamp
    final String startStr = parts[0].trim();
    final String endPart = parts[1].trim();
    // The end timestamp may be followed by settings like "align:start position:10%"
    final String endStr = endPart.split(RegExp(r'\s+')).first;

    final Duration? start = _parseTimestamp(startStr);
    final Duration? end = _parseTimestamp(endStr);

    if (start == null || end == null) {
      return null;
    }

    // Collect cue text (all lines after the timestamp line)
    final List<String> textLines = lines.sublist(timestampLineIndex + 1);
    if (textLines.isEmpty) {
      return null;
    }

    // Join text lines and strip HTML tags
    final String text = _stripHtmlTags(textLines.join('\n')).trim();
    if (text.isEmpty) {
      return null;
    }

    return VttCue(start: start, end: end, text: text);
  }

  /// Parses a VTT timestamp into a Duration
  ///
  /// Supports both HH:MM:SS.mmm and MM:SS.mmm formats
  static Duration? _parseTimestamp(String timestamp) {
    final String trimmed = timestamp.trim();

    // Try HH:MM:SS.mmm format
    final RegExpMatch? longMatch = RegExp(
      r'(\d{1,2}):(\d{2}):(\d{2})[.,](\d{3})',
    ).firstMatch(trimmed);

    if (longMatch != null) {
      return Duration(
        hours: int.parse(longMatch.group(1)!),
        minutes: int.parse(longMatch.group(2)!),
        seconds: int.parse(longMatch.group(3)!),
        milliseconds: int.parse(longMatch.group(4)!),
      );
    }

    // Try MM:SS.mmm format
    final RegExpMatch? shortMatch = RegExp(
      r'(\d{1,2}):(\d{2})[.,](\d{3})',
    ).firstMatch(trimmed);

    if (shortMatch != null) {
      return Duration(
        minutes: int.parse(shortMatch.group(1)!),
        seconds: int.parse(shortMatch.group(2)!),
        milliseconds: int.parse(shortMatch.group(3)!),
      );
    }

    return null;
  }

  /// Strips basic HTML/VTT tags from text
  static String _stripHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]+>'), '');
  }
}
