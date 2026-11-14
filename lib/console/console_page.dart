import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import 'console_controller.dart';
import 'widgets/command_pane.dart';
import 'widgets/matrix_pane.dart';

class ConsolePage extends StatefulWidget {
  const ConsolePage({super.key});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _feedbackCtrl;
  late final ConsoleController _ctrl;

  int _hoveredPane = 0;

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _ctrl = ConsoleController(
      onSuccess: () => _feedbackCtrl.forward(from: 0.0),
      onError: () => _feedbackCtrl.forward(from: 0.0),
    );
    _ctrl.sync(reconcileLasa: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final routeAnim =
        ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0);

    final slide = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.0, 0.72, curve: Motion.consolePanel),
      reverseCurve: const FlippedCurve(
        Interval(0.18, 1.0, curve: Motion.consolePanel),
      ),
    );

    final blueAnim = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.14, 0.78, curve: Motion.smooth),
      reverseCurve: const FlippedCurve(
        Interval(0.08, 0.72, curve: Motion.smooth),
      ),
    );

    final whiteAnim = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.38, 1.0, curve: Motion.smooth),
      reverseCurve: const FlippedCurve(
        Interval(0.0, 0.62, curve: Motion.smooth),
      ),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_ctrl, routeAnim]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Palette.prussianBlue,
          resizeToAvoidBottomInset: false,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 760;
              final p = slide.value;
              final b = blueAnim.value;
              final w = whiteAnim.value;

              if (isDesktop) {
                final targetRightW = constraints.maxWidth * 0.54;
                final rightW = targetRightW * p;
                final leftW = constraints.maxWidth - rightW;
                final targetLeftW = constraints.maxWidth * 0.46;

                return Row(
                  children: [
                    SizedBox(
                      width: leftW,
                      height: constraints.maxHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: targetLeftW,
                          maxWidth: math.max(leftW, targetLeftW),
                          child: RepaintBoundary(
                            child: MouseRegion(
                              onEnter: (_) {
                                if (_hoveredPane != 1) setState(() => _hoveredPane = 1);
                              },
                              onExit: (_) {
                                if (_hoveredPane == 1) setState(() => _hoveredPane = 0);
                              },
                              child: Opacity(
                                opacity: b,
                                child: Transform.translate(
                                  offset: Offset(-28.0 * (1.0 - b), 0.0),
                                  child: CommandPane(
                                    controller: _ctrl,
                                    feedbackAnim: _feedbackCtrl,
                                    isDesktop: true,
                                    paneHeight: constraints.maxHeight,
                                    tl: tl,
                                    isHovered: _hoveredPane == 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: rightW,
                      height: constraints.maxHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: targetRightW,
                          maxWidth: targetRightW,
                          child: Container(
                            color: Palette.brightSnow,
                            child: RepaintBoundary(
                              child: MouseRegion(
                                onEnter: (_) {
                                  if (_hoveredPane != 2) setState(() => _hoveredPane = 2);
                                },
                                onExit: (_) {
                                  if (_hoveredPane == 2) setState(() => _hoveredPane = 0);
                                },
                                child: Opacity(
                                  opacity: w,
                                  child: Transform.translate(
                                    offset: Offset(32.0 * (1.0 - w), 0.0),
                                    child: MatrixPane(
                                      controller: _ctrl,
                                      isDesktop: true,
                                      paneHeight: constraints.maxHeight,
                                      tl: tl,
                                      isHovered: _hoveredPane == 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final kbOpen = kbBottom > 0;
              final cmdFocused =
                  _ctrl.inputFocus.hasFocus || _ctrl.unitFocus.hasFocus;
              final dispFocused = _ctrl.dispenseFocus.hasFocus;
              final availH = math.max(220.0, constraints.maxHeight - kbBottom);

              var bottomRatio = 0.54;
              if (kbOpen && cmdFocused) {
                bottomRatio = 0.0;
              } else if (kbOpen && dispFocused) {
                bottomRatio = 0.68;
              }

              final targetBottomH = availH * bottomRatio;
              final bottomH = targetBottomH * p;
              final topH = availH - bottomH;
              final targetTopH = math.max(120.0, availH * (1.0 - bottomRatio));

              return Padding(
                padding: EdgeInsets.only(bottom: kbBottom),
                child: Column(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth,
                      height: topH,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: targetTopH,
                          maxHeight: math.max(topH, targetTopH),
                          child: RepaintBoundary(
                            child: Opacity(
                              opacity: b,
                              child: Transform.translate(
                                offset: Offset(0.0, -20.0 * (1.0 - b)),
                                child: CommandPane(
                                  controller: _ctrl,
                                  feedbackAnim: _feedbackCtrl,
                                  isDesktop: false,
                                  paneHeight: math.max(topH, targetTopH),
                                  tl: tl,
                                  isHovered: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (bottomH > 1.0)
                      SizedBox(
                        width: constraints.maxWidth,
                        height: bottomH,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: targetBottomH,
                            maxHeight: math.max(bottomH, targetBottomH),
                            child: Container(
                              color: Palette.brightSnow,
                              child: RepaintBoundary(
                                child: Opacity(
                                  opacity: w,
                                  child: Transform.translate(
                                    offset: Offset(0.0, 24.0 * (1.0 - w)),
                                    child: MatrixPane(
                                      controller: _ctrl,
                                      isDesktop: false,
                                      paneHeight: math.max(bottomH, targetBottomH),
                                      tl: tl,
                                      isHovered: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
