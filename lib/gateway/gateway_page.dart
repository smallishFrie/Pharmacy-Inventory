import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../catalog/catalog_page.dart';
import '../console/console_page.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  static final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(
    const Locale('en'),
  );

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage>
    with SingleTickerProviderStateMixin {
  static const String _passkey = '1728'; // Fuck, you found it...

  final TextEditingController _pinCtrl = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  late final AnimationController _shakeCtrl;

  int _hoveredPane = 0;
  int _expandingPane = 0;
  int _token = 0;

  bool _restoring = false;
  bool _showBlue = true;
  bool _showWhite = true;
  bool _pinError = false;
  bool _pinSuccess = false;
  bool _langHovered = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _pinFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pinFocus.removeListener(_onFocusChange);
    _pinCtrl.dispose();
    _pinFocus.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // // Private Functions

  //`fromPane`: 1 = Catalog, 2 = Console.
  Future<void> _restore(int fromPane, int token) async {
    if (!mounted || token != _token) return;

    setState(() {
      _hoveredPane = 0;
      _expandingPane = 0;
      _restoring = true;
      _showBlue = false;
      _showWhite = false;
      _pinError = false;
      _pinSuccess = false;
      _langHovered = false;
      _pinCtrl.clear();
    });

    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted || token != _token) return;
    setState(() {
      if (fromPane == 1) {
        _showWhite = true;
      } else {
        _showBlue = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted || token != _token) return;
    setState(() {
      _showWhite = true;
      _showBlue = true;
    });

    await Future.delayed(const Duration(milliseconds: 340));
    if (!mounted || token != _token) return;
    setState(() => _restoring = false);
  }

  Future<void> _openRoute(int pane, Widget page) async {
    if (_expandingPane != 0) return;
    final token = ++_token;

    _pinFocus.unfocus();
    setState(() {
      _restoring = false;
      _expandingPane = pane;
      _showBlue = false;
      _showWhite = false;
    });

    await Future.delayed(const Duration(milliseconds: 540));
    if (!mounted || token != _token) return;

    final route = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 760),
      reverseTransitionDuration: Duration(milliseconds: pane == 1 ? 380 : 640),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, _, _, child) => child,
    );

    await Navigator.of(context).push(route);
    await route.completed;
    await _restore(pane, token);
  }

  void _submitPin() {
    if (_expandingPane != 0) return;
    final input = _pinCtrl.text.trim();

    if (_passkey.isNotEmpty && input == _passkey) {
      _pinCtrl.clear();
      setState(() {
        _pinError = false;
        _pinSuccess = true;
      });
      _shakeCtrl.forward(from: 0.0);
      _openRoute(2, const ConsolePage());
    } else {
      setState(() {
        _pinError = true;
        _pinSuccess = false;
      });
      _pinCtrl.clear();
      _shakeCtrl.forward(from: 0.0);
      _pinFocus.requestFocus();
    }
  }

  // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final staffActive = !_restoring && (_hoveredPane == 2 || _pinFocus.hasFocus);
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Palette.brightSnow,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 760;
          final kbOpen = !isDesktop && kbBottom > 0;
          final availH = math.max(220.0, constraints.maxHeight - kbBottom);

          var ratioTarget = 0.50;
          if (_expandingPane == 1) {
            ratioTarget = 1.0;
          } else if (_expandingPane == 2) {
            ratioTarget = 0.0;
          } else if (kbOpen && _pinFocus.hasFocus) {
            ratioTarget = 0.14;
          } else if (!_restoring && _hoveredPane == 1) {
            ratioTarget = isDesktop ? 0.56 : 0.53;
          } else if (staffActive) {
            ratioTarget = isDesktop ? 0.44 : 0.47;
          }

          final expanding = _expandingPane != 0 || _restoring;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: ratioTarget),
            duration: Duration(milliseconds: expanding ? 540 : 380),
            curve: expanding ? Motion.panelExpand : Motion.panelSlide,
            builder: (context, ratio, _) {
              if (isDesktop) {
                final leftW = constraints.maxWidth * ratio;
                final rightW = constraints.maxWidth * (1.0 - ratio);
                final minW = constraints.maxWidth * 0.44;

                return Row(
                  children: [
                    SizedBox(
                      width: leftW,
                      height: constraints.maxHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: minW,
                          maxWidth: math.max(leftW, minW),
                          child: _buildPublicPane(
                            isDesktop: true,
                            paneHeight: constraints.maxHeight,
                            tl: tl,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: rightW,
                      height: constraints.maxHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: minW,
                          maxWidth: math.max(rightW, minW),
                          child: _buildStaffPane(
                            isDesktop: true,
                            paneHeight: constraints.maxHeight,
                            tl: tl,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final topH = availH * ratio;
              final bottomH = availH * (1.0 - ratio);
              final minTopH = kbOpen ? 60.0 : availH * 0.46;
              final minBotH = kbOpen ? availH * 0.72 : availH * 0.46;

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
                          minHeight: minTopH,
                          maxHeight: math.max(topH, minTopH),
                          child: _buildPublicPane(
                            isDesktop: false,
                            paneHeight: math.max(topH, minTopH),
                            tl: tl,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      height: bottomH,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.bottomCenter,
                          minHeight: minBotH,
                          maxHeight: math.max(bottomH, minBotH),
                          child: _buildStaffPane(
                            isDesktop: false,
                            paneHeight: math.max(bottomH, minBotH),
                            tl: tl,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLangSwitch(bool tl, double pad) {
    return HoverRegion(
      onHover: (v) {
        if (_expandingPane == 0 && !_restoring) setState(() => _langHovered = v);
      },
      onTap: () {
        if (_expandingPane == 0) {
          GatewayPage.localeNotifier.value =
              tl ? const Locale('en') : const Locale('tl');
        }
      },
      builder: (_, _) => Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, 72.0, 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangOption('EN', !tl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Motion.smooth,
                style: TextStyle(
                  color: Palette.prussianBlue.withValues(
                    alpha: _langHovered ? 0.45 : 0.22,
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                child: const Text('/'),
              ),
            ),
            _buildLangOption('TL', tl),
          ],
        ),
      ),
    );
  }

  Widget _buildLangOption(String label, bool selected) {
    final alpha = _langHovered ? 0.62 : 0.32;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 260),
          curve: Motion.smooth,
          style: TextStyle(
            color: selected
                ? Palette.prussianBlue
                : Palette.prussianBlue.withValues(alpha: alpha),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
          child: Text(label),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Motion.smooth,
          height: 2,
          width: selected ? 18 : (_langHovered ? 8 : 0),
          color: selected
              ? Palette.darkCyan
              : Palette.prussianBlue.withValues(alpha: 0.25),
        ),
      ],
    );
  }

  Widget _buildPublicPane({
    required bool isDesktop,
    required double paneHeight,
    required bool tl,
  }) {
    final highlighted =
        (!_restoring && _hoveredPane == 1 && !_langHovered) || _expandingPane == 1;
    final compact = !isDesktop && paneHeight < 340;
    final veryCompact = !isDesktop && paneHeight < 140;
    final pad = isDesktop ? 64.0 : (compact ? 20.0 : 32.0);
    final titleSize = isDesktop ? 64.0 : (compact ? 38.0 : 52.0);

    final title = tl ? 'Mga\nGamot.' : 'Find\nMedicine.';
    final action = tl ? 'LISTAHAN' : 'OPEN CATALOG';
    final visible = _showWhite && _expandingPane == 0;

    return MouseRegion(
      onEnter: (_) {
        if (_expandingPane == 0 && !_restoring) setState(() => _hoveredPane = 1);
      },
      onExit: (_) {
        if (_expandingPane == 0 && !_restoring && _hoveredPane == 1) {
          setState(() => _hoveredPane = 0);
        }
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openRoute(1, const CatalogPage()),
        child: Container(
          color: Palette.brightSnow,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: visible ? 420 : 280),
            curve: Motion.smooth,
            opacity: visible ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: Duration(milliseconds: visible ? 460 : 320),
              curve: Motion.smooth,
              offset: visible
                  ? Offset.zero
                  : (isDesktop ? const Offset(-0.04, 0.0) : const Offset(0.0, -0.04)),
              child: Stack(
                children: [
                  if (!veryCompact)
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(height: 20),
                          Motion.fadeSlide(
                            inMs: 320,
                            child: Text(
                              title,
                              key: ValueKey<String>(title),
                              style: TextStyle(
                                color: Palette.prussianBlue,
                                fontSize: titleSize,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2.2,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Motion.fadeSlide(
                                    inMs: 260,
                                    offset: Offset.zero,
                                    child: Text(
                                      action,
                                      key: ValueKey<String>(action),
                                      style: const TextStyle(
                                        color: Palette.prussianBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  AnimatedSlide(
                                    duration: const Duration(milliseconds: 360),
                                    curve: Motion.smooth,
                                    offset: highlighted
                                        ? const Offset(0.18, 0)
                                        : Offset.zero,
                                    child: const Icon(
                                      Icons.arrow_forward_sharp,
                                      color: Palette.darkCyan,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 380),
                                curve: Motion.smooth,
                                height: 3,
                                width: double.infinity,
                                color: highlighted
                                    ? Palette.darkCyan
                                    : Palette.prussianBlue.withValues(alpha: 0.12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildLangSwitch(tl, pad),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffPane({
    required bool isDesktop,
    required double paneHeight,
    required bool tl,
  }) {
    final active = !_restoring && (_hoveredPane == 2 || _pinFocus.hasFocus);
    final compact = !isDesktop && paneHeight < 340;
    final pad = isDesktop ? 64.0 : (compact ? 24.0 : 32.0);
    final titleSize = isDesktop ? 64.0 : (compact ? 40.0 : 52.0);
    final visible = _showBlue && _expandingPane == 0;

    String title;
    String hint;
    Color statusColor;
    Color barColor;

    if (_pinError) {
      title = tl ? 'Mali.' : 'Access\nDenied.';
      hint = tl ? 'MALING PASSKEY' : 'UNAUTHORIZED PASSKEY';
      statusColor = Palette.scarletFire;
      barColor = Palette.scarletFire;
    } else if (_pinSuccess) {
      title = tl ? 'Ok.' : 'Access\nGranted.';
      hint = tl ? 'BUKAS ANG TERMINAL' : 'TERMINAL UNLOCKED';
      statusColor = Palette.darkCyan;
      barColor = Palette.darkCyan;
    } else {
      title = tl ? 'Pang-\nKawani.' : 'Staff\nConsole.';
      hint = tl ? 'ILAGAY ANG PASSKEY' : 'ENTER PASSKEY';
      statusColor = Palette.brightSnow;
      barColor = active
          ? Palette.amberGlow
          : Palette.brightSnow.withValues(alpha: 0.15);
    }

    return MouseRegion(
      onEnter: (_) {
        if (_expandingPane == 0 && !_restoring) setState(() => _hoveredPane = 2);
      },
      onExit: (_) {
        if (_expandingPane == 0 && !_restoring && _hoveredPane == 2) {
          setState(() => _hoveredPane = 0);
        }
      },
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_expandingPane == 0) _pinFocus.requestFocus();
        },
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final t = _shakeCtrl.value;
            // `sin(6πt) * (1 - t)`
            final dx = (_shakeCtrl.isAnimating && _pinError)
                ? math.sin(t * math.pi * 6) * (1.0 - t) * 20.0
                : 0.0;
            final flash = _shakeCtrl.isAnimating
                ? Curves.easeOutCubic.transform(1.0 - t) * 0.24
                : 0.0;
            final flashColor = _pinSuccess ? Palette.darkCyan : Palette.scarletFire;

            return Container(
              color: Color.lerp(Palette.prussianBlue, flashColor, flash),
              padding: EdgeInsets.all(pad),
              child: Transform.translate(offset: Offset(dx, 0), child: child),
            );
          },
          child: AnimatedOpacity(
            duration: Duration(milliseconds: visible ? 400 : 280),
            curve: Motion.smooth,
            opacity: visible ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: Duration(milliseconds: visible ? 440 : 320),
              curve: Motion.smooth,
              offset: visible
                  ? Offset.zero
                  : (isDesktop ? const Offset(0.04, 0.0) : const Offset(0.0, 0.04)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 12),
                  Motion.fadeSlide(
                    inMs: 320,
                    child: Text(
                      title,
                      key: ValueKey<String>(title),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: titleSize,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.2,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pinCtrl,
                              focusNode: _pinFocus,
                              obscureText: true,
                              obscuringCharacter: '•',
                              enabled: _expandingPane == 0,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitPin(),
                              onChanged: (_) {
                                if (_pinError || _pinSuccess) {
                                  setState(() {
                                    _pinError = false;
                                    _pinSuccess = false;
                                  });
                                }
                              },
                              style: const TextStyle(
                                color: Palette.brightSnow,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 6,
                              ),
                              cursorColor: Palette.amberGlow,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: hint,
                                hintStyle: TextStyle(
                                  color: (_pinError || _pinSuccess)
                                      ? statusColor
                                      : Palette.brightSnow.withValues(alpha: 0.38),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          HoverRegion(
                            onTap: _submitPin,
                            builder: (_, hovered) => Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 360),
                                curve: Motion.smooth,
                                offset: hovered
                                    ? const Offset(0.28, 0)
                                    : ((active || _expandingPane == 2)
                                        ? const Offset(0.16, 0)
                                        : Offset.zero),
                                child: Icon(
                                  Icons.arrow_forward_sharp,
                                  color: (_pinError || _pinSuccess)
                                      ? statusColor
                                      : Palette.amberGlow,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 380),
                        curve: Motion.smooth,
                        height: 3,
                        width: double.infinity,
                        color: barColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
