import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// // Public API

class Motion {
  Motion._();

  static const Curve smooth       = Cubic(0.32, 0.08, 0.24, 1.0);
  static const Curve panelSlide   = Cubic(0.35, 0.0, 0.20, 1.0);
  static const Curve panelExpand  = Cubic(0.40, 0.0, 0.18, 1.0);
  static const Curve consolePanel = Cubic(0.35, 0.0, 0.18, 1.0);

  static Widget fadeSlide({
    required Widget child,
    Offset offset = const Offset(0.0, 0.06),
    int inMs = 340,
    int? outMs,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: inMs),
      reverseDuration: outMs != null ? Duration(milliseconds: outMs) : null,
      switchInCurve: smooth,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
      layoutBuilder: (current, prev) {
        return Stack(
          alignment: alignment,
          children: [...prev, if (current != null) current],
        );
      },
      child: child,
    );
  }

  // // Fuzzy Search

  //Returns `0.0 - 1.0`
  static double fuzzyScore(String query, String target) {
    final q = query.trim().toLowerCase();
    final t = target.trim().toLowerCase();
    if (q.isEmpty || t.isEmpty) return 0.0;
    if (q == t) return 1.0;

    final ratio = q.length / t.length;
    if (t.startsWith(q)) return 0.90 + 0.09 * ratio;
    if (t.contains(' $q') || t.contains('-$q')) return 0.80 + 0.09 * ratio;
    if (t.contains(q)) return 0.70 + 0.09 * ratio;

    var qi = 0;
    var streak = 0;
    var bonus = 0;
    for (var ti = 0; ti < t.length && qi < q.length; ti++) {
      if (t.codeUnitAt(ti) == q.codeUnitAt(qi)) {
        qi++;
        streak++;
        if (streak > 1) bonus += streak;
      } else {
        streak = 0;
      }
    }
    if (qi == q.length) {
      final b = (bonus * 0.02).clamp(0.0, 0.12);
      return 0.50 + 0.07 * ratio + b;
    }

    if (q.length >= 3 && t.length >= 3) {
      var hits = 0;
      final used = List<bool>.filled(t.length - 1, false);
      for (var i = 0; i < q.length - 1; i++) {
        final bg = q.substring(i, i + 2);
        for (var j = 0; j < t.length - 1; j++) {
          if (!used[j] && t.substring(j, j + 2) == bg) {
            used[j] = true;
            hits++;
            break;
          }
        }
      }
      final dice = (2.0 * hits) / ((q.length - 1) + (t.length - 1));
      if (dice >= 0.45) return 0.30 + 0.25 * dice;
    }

    return 0.0;
  }

  static String? bestGhostMatch(String query, Iterable<String> candidates) {
    final q = query.trim();
    if (q.isEmpty) return null;
    final lowerQ = q.toLowerCase();
    final trailingSpace = query.endsWith(' ');
    final batchSuffixRx = RegExp(r'\s\d+$');

    var hasExact = false;
    for (final raw in candidates) {
      if (raw.trim().toLowerCase() == lowerQ) {
        hasExact = true;
        break;
      }
    }

    String? best;
    var bestScore = 0.0;

    for (final raw in candidates) {
      final c = raw.trim();
      if (c.isEmpty) continue;
      final lowerC = c.toLowerCase();
      if (lowerC == lowerQ) continue;

      if (hasExact && !lowerC.startsWith('$lowerQ ')) continue;
      if (trailingSpace && !batchSuffixRx.hasMatch(lowerC)) continue;

      final s = fuzzyScore(q, c);
      if (s >= 0.48 && s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best;
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class HoverRegion extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;
  final MouseCursor cursor;

  const HoverRegion({
    super.key,
    required this.builder,
    this.onTap,
    this.onHover,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  bool _hovered = false;

  void _setHover(bool val) {
    if (_hovered == val) return;
    setState(() => _hovered = val);
    widget.onHover?.call(val);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder(context, _hovered);
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: widget.onTap == null
          ? content
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: content,
            ),
    );
  }
}

class FishInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Iterable<String> candidates;
  final String hintText;
  final TextStyle style;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Color ghostColor;
  final Color tabPillColor;
  final bool readOnly;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEscape;

  const FishInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.candidates,
    required this.hintText,
    required this.style,
    required this.hintStyle,
    required this.cursorColor,
    required this.ghostColor,
    required this.tabPillColor,
    this.readOnly = false,
    this.textInputAction = TextInputAction.done,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.onEscape,
  });

  void _accept(String match) {
    controller.value = TextEditingValue(
      text: match,
      selection: TextSelection.collapsed(offset: match.length),
    );
    onChanged?.call(match);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, val, _) {
        final raw = val.text;
        final ghost = readOnly ? null : Motion.bestGhostMatch(raw, candidates);
        final isPrefix =
            ghost != null && ghost.toLowerCase().startsWith(raw.toLowerCase());

        return Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;

            if (event.logicalKey == LogicalKeyboardKey.tab && ghost != null) {
              _accept(ghost);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                ghost != null &&
                val.selection.baseOffset == raw.length) {
              _accept(ghost);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape && onEscape != null) {
              onEscape!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (ghost != null && raw.isNotEmpty)
                      IgnorePointer(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          text: TextSpan(
                            style: style,
                            children: [
                              TextSpan(
                                text: raw,
                                style: style.copyWith(color: Colors.transparent),
                              ),
                              TextSpan(
                                text: isPrefix
                                    ? ghost.substring(raw.length)
                                    : '  → $ghost',
                                style: style.copyWith(color: ghostColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: readOnly,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      onSubmitted:
                          onSubmitted != null ? (_) => onSubmitted!() : null,
                      onChanged: onChanged,
                      style: style,
                      cursorColor: cursorColor,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: hintText,
                        hintStyle: hintStyle,
                      ),
                    ),
                  ],
                ),
              ),
              if (ghost != null && raw.isNotEmpty)
                HoverRegion(
                  onTap: () => _accept(ghost),
                  builder: (_, hovered) => Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Motion.smooth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tabPillColor.withValues(
                          alpha: hovered ? 0.22 : 0.12,
                        ),
                        border: Border.all(
                          color: tabPillColor.withValues(
                            alpha: hovered ? 0.65 : 0.35,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'TAB',
                        style: TextStyle(
                          color: tabPillColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
