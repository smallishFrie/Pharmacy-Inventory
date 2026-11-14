import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

// // Private Functions

//Returns `(prefixLen, suffixLen)`
(int, int) _affixLengths(String a, String b) {
  final minLen = math.min(a.length, b.length);
  var p = 0;
  while (p < minLen && a.codeUnitAt(p) == b.codeUnitAt(p)) {
    p++;
  }

  var s = 0;
  while (s < (minLen - p) &&
      a.codeUnitAt(a.length - 1 - s) == b.codeUnitAt(b.length - 1 - s)) {
    s++;
  }
  return (p, s);
}

int _nearSuffix(String a, String b, int exactS) {
  if (exactS != 1 || a.length < 4 || b.length < 4) return exactS;
  if (a.codeUnitAt(a.length - 3) == b.codeUnitAt(b.length - 3)) return 2;
  return exactS;
}

double _charDice(String a, String b) {
  final counts = <int, int>{};
  for (var i = 0; i < a.length; i++) {
    final c = a.codeUnitAt(i);
    counts[c] = (counts[c] ?? 0) + 1;
  }

  var matches = 0;
  for (var i = 0; i < b.length; i++) {
    final c = b.codeUnitAt(i);
    final rem = counts[c] ?? 0;
    if (rem > 0) {
      counts[c] = rem - 1;
      matches++;
    }
  }
  return (2.0 * matches) / (a.length + b.length);
}

String _titleCase(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';

  final words = s.split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isNotEmpty) {
      words[i] = '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }
  }
  return words.join(' ');
}

String _upperSpan(String lower, int start, int end) {
  final s = start.clamp(0, lower.length);
  final e = end.clamp(s, lower.length);
  if (s == e) return _titleCase(lower);
  return '${lower.substring(0, s)}${lower.substring(s, e).toUpperCase()}${lower.substring(e)}';
}

(String, String) _alignWord(String wordA, String wordB) {
  final a = wordA.toLowerCase();
  final b = wordB.toLowerCase();

  if (a == b || a.length < 4 || b.length < 4) {
    return (_titleCase(a), _titleCase(b));
  }

  var (p, s) = _affixLengths(a, b);
  if (p == 1) p = 0;
  if (s == 1) s = 0;

  final minLen = math.min(a.length, b.length);
  var span = minLen - (p + s);

  if (span < 2) {
    final need = 2 - span;
    if (s >= p && s >= need) {
      s -= need;
      if (s == 1) s = 0;
    } else if (p >= need) {
      p -= need;
      if (p == 1) p = 0;
    } else {
      p = math.max(0, p - 1);
      s = math.max(0, s - 1);
    }
  }

  span = minLen - (p + s);
  if (span < 3 && p >= 5 && s <= 2) {
    s = 0;
    p = math.max(0, minLen - 4);
  }

  return (_upperSpan(a, p, a.length - s), _upperSpan(b, p, b.length - s));
}

// // Public API

class LasaEngine {
  LasaEngine._();

  static String normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  }

  static bool hasTallMan(String text) {
    return RegExp(r'[a-z][A-Z]{2,}|[A-Z]{2,}[a-z]').hasMatch(text);
  }

  static String phonetic(String raw) {
    var s = normalize(raw);
    if (s.isEmpty) return '';

    if (s.startsWith('x')) s = 'z${s.substring(1)}';
    if (s.startsWith('ps')) s = 's${s.substring(2)}';
    if (s.startsWith('rh')) s = 'r${s.substring(2)}';

    // English sucks so...
    s = s
        .replaceAll('ph', 'f')
        .replaceAll('ch', 'k')
        .replaceAll('sh', 'x')
        .replaceAll('th', 't')
        .replaceAll('qu', 'kw')
        .replaceAll('ck', 'k')
        .replaceAll('dg', 'j')
        .replaceAll('ae', 'e')
        .replaceAll('oe', 'e')
        .replaceAll('ou', 'u')
        .replaceAll('y', 'i')
        .replaceAll('x', 'ks');

    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final next = i + 1 < s.length ? s[i + 1] : '';
      if (ch == 'c') {
        buf.write((next == 'e' || next == 'i') ? 's' : 'k');
      } else if (ch == 'g') {
        buf.write((next == 'e' || next == 'i') ? 'j' : 'g');
      } else {
        buf.write(ch);
      }
    }

    var out = buf.toString().replaceAllMapped(
          RegExp(r'(.)\1+'),
          (m) => m.group(1)!,
        );

    if (out.endsWith('e')) {
      out = out.substring(0, out.length - 1);
    }

    return out;
  }

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final jp1 = j + 1;
        curr[jp1] = math.min(
          math.min(curr[j] + 1, prev[jp1] + 1),
          prev[j] + cost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  // Sørensen-Dice: `2 * |A ∩ B| / (|A| + |B|)`
  static double dice(String a, String b) {
    if (a.length < 2 || b.length < 2) return a == b ? 1.0 : 0.0;
    final bgA = <String>[];
    final bgB = <String>[];

    for (var i = 0; i < a.length - 1; i++) {
      bgA.add(a.substring(i, i + 2));
    }
    for (var i = 0; i < b.length - 1; i++) {
      bgB.add(b.substring(i, i + 2));
    }

    final used = List<bool>.filled(bgB.length, false);
    var matches = 0;
    for (final bg in bgA) {
      for (var j = 0; j < bgB.length; j++) {
        if (!used[j] && bgB[j] == bg) {
          used[j] = true;
          matches++;
          break;
        }
      }
    }
    return (2.0 * matches) / (bgA.length + bgB.length);
  }

  //Returns `0-1`
  static double similarity(String rawA, String rawB) {
    final a = normalize(rawA);
    final b = normalize(rawB);
    if (a.length < 4 || b.length < 4 || a == b) return 0.0;

    final phonA = phonetic(a);
    final phonB = phonetic(b);

    final maxLen = math.max(a.length, b.length);
    final phonMax = math.max(phonA.length, phonB.length);

    final diceSim = dice(a, b);
    final editSim = 1.0 - (levenshtein(a, b) / maxLen);
    final phonSim = phonMax > 0 ? 1.0 - (levenshtein(phonA, phonB) / phonMax) : 0.0;
    final charSim = _charDice(a, b);

    return ((diceSim + editSim + phonSim + charSim) / 4.0).clamp(0.0, 1.0);
  }

  static bool isPair(String rawA, String rawB) {
    final a = normalize(rawA);
    final b = normalize(rawB);
    if (a.length < 4 || b.length < 4 || a == b) return false;

    final (p, s) = _affixLengths(a, b);
    final (pp, _) = _affixLengths(phonetic(a), phonetic(b));
    final effP = math.max(p, pp);

    return (effP >= 2 || s >= 4) && similarity(a, b) >= 0.54;
  }

  //Returns `(TallManA, TallManB)`
  static (String, String) alignPair(String rawA, String rawB) {
    final wordsA = rawA.trim().split(RegExp(r'\s+'));
    final wordsB = rawB.trim().split(RegExp(r'\s+'));
    if (wordsA.isEmpty || wordsB.isEmpty) return (rawA.trim(), rawB.trim());

    if (wordsA.first.toLowerCase() != wordsB.first.toLowerCase() ||
        wordsA.length == 1 ||
        wordsB.length == 1) {
      final (firstA, firstB) = _alignWord(wordsA[0], wordsB[0]);
      wordsA[0] = firstA;
      wordsB[0] = firstB;
      for (var i = 1; i < wordsA.length; i++) {
        wordsA[i] = _titleCase(wordsA[i]);
      }
      for (var i = 1; i < wordsB.length; i++) {
        wordsB[i] = _titleCase(wordsB[i]);
      }
      return (wordsA.join(' '), wordsB.join(' '));
    }

    final (secA, secB) = _alignWord(wordsA[1], wordsB[1]);
    wordsA[0] = _titleCase(wordsA[0]);
    wordsB[0] = _titleCase(wordsB[0]);
    wordsA[1] = secA;
    wordsB[1] = secB;
    for (var i = 2; i < wordsA.length; i++) {
      wordsA[i] = _titleCase(wordsA[i]);
    }
    for (var i = 2; i < wordsB.length; i++) {
      wordsB[i] = _titleCase(wordsB[i]);
    }
    return (wordsA.join(' '), wordsB.join(' '));
  }

  static LasaEvaluation evaluate(
    String candidate,
    Iterable<String> existingNames,
  ) {
    final target = candidate.trim();
    if (target.isEmpty) {
      return const LasaEvaluation(
        displayName: '',
        isLasa: false,
        counterpart: '',
        similarity: 0.0,
      );
    }

    String? bestMatch;
    var bestScore = 0.0;

    for (final other in existingNames) {
      if (!isPair(target, other)) continue;
      final score = similarity(target, other);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = other.trim();
      }
    }

    if (bestMatch != null) {
      final (outA, outB) = alignPair(target, bestMatch);
      return LasaEvaluation(
        displayName: outA,
        isLasa: true,
        counterpart: outB,
        similarity: bestScore,
      );
    }

    return LasaEvaluation(
      displayName: _titleCase(target),
      isLasa: false,
      counterpart: '',
      similarity: 0.0,
    );
  }

  static List<MedicineRecord> enrich(List<MedicineRecord> records) {
    if (records.isEmpty) return records;

    final names = <String>{};
    for (final r in records) {
      names.add(r.name.trim());
    }

    final evals = <String, LasaEvaluation>{};
    for (final name in names) {
      final norm = normalize(name);
      final others = <String>[];
      for (final n in names) {
        if (normalize(n) != norm) others.add(n);
      }
      evals[name] = evaluate(name, others);
    }

    final out = <MedicineRecord>[];
    for (final r in records) {
      final ev = evals[r.name.trim()];
      out.add(
        r.withLasa(
          displayName: ev?.displayName ?? r.name,
          isLasa: ev?.isLasa ?? false,
          lasaGroup: ev?.counterpart ?? '',
        ),
      );
    }
    return out;
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class TallManText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color? highlightColor;
  final int maxLines;
  final TextOverflow overflow;

  const TallManText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.highlightColor,
    this.maxLines = 1,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    if (!LasaEngine.hasTallMan(text) || highlightColor == null) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: baseStyle,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    for (final m in RegExp(r'[A-Z]{2,}').allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: baseStyle.copyWith(color: highlightColor),
        ),
      );
      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

// // Types

class LasaEvaluation {
  final String displayName;
  final bool isLasa;
  final String counterpart;
  final double similarity;

  const LasaEvaluation({
    required this.displayName,
    required this.isLasa,
    required this.counterpart,
    required this.similarity,
  });
}
