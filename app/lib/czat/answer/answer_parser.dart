/// Tolerant extraction of the model's JSON object (lokalne-ai.md, "Zapas":
/// cut out the first `{...}`, ignore text around it and ``` fences).
library;

import 'dart:convert';

/// Returns the first JSON object in [raw] that has a `panels` key, or null.
///
/// Handles ``` fences, prose before/after, trailing commas and braces inside
/// strings. A truncated object (unbalanced braces) yields null so the caller
/// can retry.
Map<String, Object?>? parseModelJson(String raw) {
  var from = 0;
  while (true) {
    final start = raw.indexOf('{', from);
    if (start < 0) return null;
    final end = _balancedEnd(raw, start);
    if (end != null) {
      final obj = _decode(raw.substring(start, end + 1));
      if (obj != null && obj.containsKey('panels')) return obj;
    }
    from = start + 1;
  }
}

/// Index of the `}` closing the object that opens at [start], or null.
int? _balancedEnd(String s, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

Map<String, Object?>? _decode(String text) {
  for (final candidate in [text, _stripTrailingCommas(text)]) {
    try {
      final v = jsonDecode(candidate);
      if (v is Map) return Map<String, Object?>.from(v);
    } on FormatException {
      // try the repaired variant
    }
  }
  return null;
}

/// Removes commas that directly precede `}` or `]` (outside strings).
String _stripTrailingCommas(String s) {
  final out = StringBuffer();
  var inString = false;
  var escaped = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      out.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
      out.write(c);
    } else if (c == ',') {
      var j = i + 1;
      while (j < s.length && ' \t\r\n'.contains(s[j])) {
        j++;
      }
      if (j < s.length && (s[j] == '}' || s[j] == ']')) continue;
      out.write(c);
    } else {
      out.write(c);
    }
  }
  return out.toString();
}
