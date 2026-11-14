import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import '../../data/lasa_engine.dart';
import '../../data/models.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../console_controller.dart';
import '../expiry_parser.dart';

class MatrixPane extends StatefulWidget {
  final ConsoleController controller;
  final bool isDesktop;
  final double paneHeight;
  final bool tl;
  final bool isHovered;

  const MatrixPane({
    super.key,
    required this.controller,
    required this.isDesktop,
    required this.paneHeight,
    required this.tl,
    required this.isHovered,
  });

  @override
  State<MatrixPane> createState() => _MatrixPaneState();
}

class _MatrixPaneState extends State<MatrixPane> {
  String? _lastCabId;
  double _slideDir = 1.0;

  ConsoleController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastCabId = _c.activeCabinet?.id;
    _c.addListener(_onCabChanged);
  }

  @override
  void didUpdateWidget(covariant MatrixPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCabChanged);
      widget.controller.addListener(_onCabChanged);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onCabChanged);
    super.dispose();
  }

  void _onCabChanged() {
    final curId = _c.activeCabinet?.id;
    if (curId != _lastCabId) {
      final oldIdx = _c.cabinets.indexWhere((c) => c.id == _lastCabId);
      final newIdx = _c.cabinets.indexWhere((c) => c.id == curId);
      if (oldIdx != -1 && newIdx != -1 && oldIdx != newIdx) {
        _slideDir = newIdx > oldIdx ? 1.0 : -1.0;
      } else {
        _slideDir = 1.0;
      }
      _lastCabId = curId;
    }
  }

  // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final compact = !widget.isDesktop && widget.paneHeight < 360;
    final pad = widget.isDesktop ? 64.0 : (compact ? 24.0 : 32.0);
    final batches = _c.currentBatches;

    var totalStock = 0;
    for (final b in batches) {
      totalStock += b.stock;
    }

    return Container(
      color: Palette.brightSnow,
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_c.isOffline)
            const SizedBox(height: 20)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: false,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final cab in _c.cabinets)
                            Padding(
                              padding: const EdgeInsets.only(right: 24.0),
                              child: _buildTab(
                                label: '${widget.tl ? "KAB" : "CAB"} ${cab.name}',
                                selected: _c.activeCabinet?.id == cab.id,
                                onTap: () => _c.selectCabinet(cab),
                              ),
                            ),
                          _buildTab(
                            label: widget.tl ? '+ KABINET' : '+ CABINET',
                            selected: _c.flow == PromptFlow.newCabinetName ||
                                _c.flow == PromptFlow.newCabinetGrid,
                            onTap: _c.startAddCabinet,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_c.activeCabinet != null) ...[
                  const SizedBox(width: 16),
                  _buildDeleteCabAction(),
                ],
              ],
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: (_c.activeCabinet?.rows ?? 3) > 5 ? 16.0 : 28.0,
              ),
              child: _buildViewport(),
            ),
          ),
          _buildDispenseBar(batches, totalStock),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return HoverRegion(
      onTap: onTap,
      builder: (_, hovered) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Motion.smooth,
            style: TextStyle(
              color: (selected || hovered) ? Palette.prussianBlue : Palette.slateMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Motion.smooth,
            height: 2,
            width: selected ? 28 : (hovered ? 14 : 0),
            color: selected ? Palette.darkCyan : Palette.prussianBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteCabAction() {
    final confirming = _c.flow == PromptFlow.confirmDeleteCabinet;
    final baseColor = Palette.scarletFire.withValues(alpha: 0.78);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Motion.smooth,
      switchOutCurve: Curves.easeInCubic,
      child: confirming
          ? const SizedBox.shrink()
          : HoverRegion(
              onTap: _c.promptDeleteCabinet,
              builder: (_, hovered) => Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 360),
                    curve: Motion.smooth,
                    offset: hovered ? const Offset(-0.06, 0) : Offset.zero,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      curve: Motion.smooth,
                      style: TextStyle(
                        color: hovered ? Palette.scarletFire : baseColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                      child: Text(
                        widget.tl ? 'BURAHIN ANG KABINET' : 'DELETE CABINET',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 360),
                    curve: Motion.smooth,
                    height: 2,
                    width: hovered ? 48 : 24,
                    color: hovered
                        ? Palette.scarletFire
                        : baseColor.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildViewport() {
    if (_c.isOffline) {
      return Center(
        child: HoverRegion(
          onTap: _c.sync,
          builder: (_, hovered) => AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Motion.smooth,
            style: TextStyle(
              color: hovered ? Palette.prussianBlue : Palette.slateMuted,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            child: Text(
              widget.tl
                  ? 'Offline ang PocketBase. Buksan ang server at pindutin ito.'
                  : 'PocketBase server is offline. Start server and click to retry.',
            ),
          ),
        ),
      );
    }

    final cab = _c.activeCabinet;
    if (cab == null) {
      return Center(
        child: HoverRegion(
          onTap: _c.startAddCabinet,
          builder: (_, hovered) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Motion.smooth,
                style: TextStyle(
                  color: hovered ? Palette.prussianBlue : Palette.slateMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                child: Text(
                  widget.tl
                      ? 'Pindutin ang + KABINET sa itaas.'
                      : 'Select + CABINET above to configure shelves.',
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Motion.smooth,
                height: 2,
                width: hovered ? 48 : 0,
                color: Palette.darkCyan,
              ),
            ],
          ),
        ),
      );
    }

    final key = ValueKey<String>('${cab.id}_${cab.rows}_${cab.cols}');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Motion.smooth,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final incoming = child.key == key;
        final begin = incoming
            ? Offset(0.035 * _slideDir, 0.0)
            : Offset(-0.035 * _slideDir, 0.0);

        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
      layoutBuilder: (current, prev) {
        return Stack(
          fit: StackFit.expand,
          children: [...prev, if (current != null) current],
        );
      },
      child: _CabinetGridViewport(
        key: key,
        cabinet: cab,
        controller: _c,
        isDesktop: widget.isDesktop,
        tl: widget.tl,
      ),
    );
  }

  Widget _buildDispenseBar(List<MedicineRecord> batches, int totalStock) {
    if (_c.isOffline) {
      return HoverRegion(
        onTap: _c.sync,
        builder: (_, hovered) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.tl
                      ? 'SUBUKAN MULING KUMONEKTA SA POCKETBASE'
                      : 'RETRY POCKETBASE CONNECTION',
                  style: const TextStyle(
                    color: Palette.scarletFire,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 360),
                  curve: Motion.smooth,
                  offset: hovered ? const Offset(0.18, 0) : Offset.zero,
                  child: const Icon(
                    Icons.refresh_sharp,
                    color: Palette.scarletFire,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 3,
              width: double.infinity,
              color: Palette.scarletFire,
            ),
          ],
        ),
      );
    }

    if (batches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          Container(
            height: 3,
            width: double.infinity,
            color: Palette.borderLight,
          ),
        ],
      );
    }

    final active = _c.dispenseFocus.hasFocus || widget.isHovered;
    final hint = widget.tl
        ? 'ILABAS NA UNIT ($totalStock SA SLOT)'
        : 'DISPENSE UNITS ($totalStock IN BIN)';

    Color barColor = Palette.borderLight;
    if (_c.hasDispenseError) {
      barColor = Palette.scarletFire;
    } else if (_c.dispenseFocus.hasFocus) {
      barColor = Palette.darkCyan;
    } else if (widget.isHovered) {
      barColor = Palette.prussianBlue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextField(
                controller: _c.dispenseCtrl,
                focusNode: _c.dispenseFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _c.submitDispense(),
                onChanged: (_) => _c.clearDispenseError(),
                style: const TextStyle(
                  color: Palette.prussianBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                cursorColor: Palette.darkCyan,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: _c.hasDispenseError
                        ? Palette.scarletFire
                        : Palette.slateMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            HoverRegion(
              onTap: _c.submitDispense,
              builder: (_, hovered) => Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 380),
                  curve: Motion.smooth,
                  offset: hovered
                      ? const Offset(0.28, 0)
                      : (active ? const Offset(0.16, 0) : Offset.zero),
                  child: Icon(
                    Icons.arrow_forward_sharp,
                    color: _c.hasDispenseError
                        ? Palette.scarletFire
                        : Palette.darkCyan,
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
    );
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class _CabinetGridViewport extends StatefulWidget {
  final CabinetRecord cabinet;
  final ConsoleController controller;
  final bool isDesktop;
  final bool tl;

  const _CabinetGridViewport({
    super.key,
    required this.cabinet,
    required this.controller,
    required this.isDesktop,
    required this.tl,
  });

  @override
  State<_CabinetGridViewport> createState() => _CabinetGridViewportState();
}

class _CabinetGridViewportState extends State<_CabinetGridViewport> {
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  int? _lastSlot;
  double _viewW = 0;
  double _viewH = 0;
  double _cellW = 0;
  double _cellH = 0;
  double _colPitch = 0;
  double _rowPitch = 0;

  @override
  void initState() {
    super.initState();
    _lastSlot = widget.controller.selectedSlot;
    widget.controller.addListener(_onSlotChanged);
  }

  @override
  void didUpdateWidget(covariant _CabinetGridViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSlotChanged);
      widget.controller.addListener(_onSlotChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSlotChanged);
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  void _onSlotChanged() {
    if (widget.controller.activeCabinet?.id != widget.cabinet.id) return;
    final slot = widget.controller.selectedSlot;
    final changed = slot != _lastSlot;
    _lastSlot = slot;

    if (changed && slot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSlot(slot);
      });
    }
  }

  void _scrollToSlot(int slot) {
    if (_colPitch <= 0 || _rowPitch <= 0) return;

    final r = slot ~/ widget.cabinet.cols;
    final c = slot % widget.cabinet.cols;

    if (_hScroll.hasClients && _hScroll.position.maxScrollExtent > 0) {
      final curX = _hScroll.offset;
      final left = c * _colPitch;
      final right = left + _cellW;
      if (left < curX || right > curX + _viewW) {
        final targetX = (left - (_viewW - _cellW) * 0.5).clamp(
          0.0,
          _hScroll.position.maxScrollExtent,
        );
        _hScroll.animateTo(
          targetX,
          duration: const Duration(milliseconds: 320),
          curve: Motion.smooth,
        );
      }
    }

    if (_vScroll.hasClients && _vScroll.position.maxScrollExtent > 0) {
      final curY = _vScroll.offset;
      final top = r * _rowPitch;
      final bottom = top + _cellH;
      if (top < curY || bottom > curY + _viewH) {
        final targetY = (top - (_viewH - _cellH) * 0.5).clamp(
          0.0,
          _vScroll.position.maxScrollExtent,
        );
        _vScroll.animateTo(
          targetY,
          duration: const Duration(milliseconds: 320),
          curve: Motion.smooth,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cab = widget.cabinet;

    return LayoutBuilder(
      builder: (context, constraints) {
        const liftPad = 4.0;
        final availW = math.max(1.0, constraints.maxWidth);
        final availH = math.max(1.0, constraints.maxHeight - liftPad);

        final denseCols = cab.cols > 4;
        final denseRows = cab.rows > 4;
        final colGap = denseCols ? 12.0 : 20.0;
        final rowGap = cab.rows > 6 ? 10.0 : (denseRows ? 12.0 : 20.0);

        final minW = widget.isDesktop ? 128.0 : 104.0;
        final minH = widget.isDesktop ? 78.0 : 66.0;

        var hScroll = ((availW - colGap * (cab.cols - 1)) / cab.cols) < minW;
        var vScroll = ((availH - rowGap * (cab.rows - 1)) / cab.rows) < minH;

        final gridW = math.max(1.0, availW - (vScroll ? 16.0 : 0.0));
        final gridH = math.max(1.0, availH - (hScroll ? 16.0 : 0.0));

        final fitW = (gridW - colGap * (cab.cols - 1)) / cab.cols;
        final fitH = (gridH - rowGap * (cab.rows - 1)) / cab.rows;

        hScroll = fitW < minW;
        vScroll = fitH < minH;

        final cellW = math.max(minW, fitW);
        final cellH = math.max(minH, fitH);

        final colPitch = cellW + colGap;
        final rowPitch = cellH + rowGap;
        final totalW = cellW * cab.cols + colGap * (cab.cols - 1);

        final vPad = cellH < 86 ? 8.0 : (denseRows ? 10.0 : 14.0);
        final hPad = cellW < 140 ? 10.0 : 14.0;

        _viewW = gridW;
        _viewH = gridH;
        _cellW = cellW;
        _cellH = cellH;
        _colPitch = colPitch;
        _rowPitch = rowPitch;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: RawScrollbar(
            controller: _hScroll,
            thumbVisibility: hScroll,
            thickness: 5.0,
            radius: Radius.zero,
            thumbColor: Palette.prussianBlue.withValues(alpha: 0.28),
            padding: EdgeInsets.only(right: vScroll ? 16.0 : 0.0),
            notificationPredicate: (n) => n.depth == 0,
            child: RawScrollbar(
              controller: _vScroll,
              thumbVisibility: vScroll,
              thickness: 5.0,
              radius: Radius.zero,
              thumbColor: Palette.prussianBlue.withValues(alpha: 0.28),
              padding: EdgeInsets.only(
                top: liftPad,
                bottom: hScroll ? 16.0 : 0.0,
              ),
              notificationPredicate: (n) => n.depth == 1,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: vScroll ? 16.0 : 0.0,
                    bottom: hScroll ? 16.0 : 0.0,
                  ),
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.only(top: liftPad),
                      child: SizedBox(
                        width: gridW,
                        height: gridH,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          physics: hScroll
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: totalW,
                            height: gridH,
                            child: ListView.builder(
                              controller: _vScroll,
                              addRepaintBoundaries: false,
                              physics: vScroll
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: cab.rows,
                              itemExtentBuilder: (i, _) =>
                                  i < cab.rows - 1 ? rowPitch : cellH,
                              itemBuilder: (context, r) {
                                return ListenableBuilder(
                                  listenable: _hScroll,
                                  builder: (context, _) {
                                    final scrollX =
                                        _hScroll.hasClients ? _hScroll.offset : 0.0;

                                    final c0 = math.max(
                                      0,
                                      (scrollX / colPitch).floor() - 2,
                                    );
                                    final c1 = math.min(
                                      cab.cols - 1,
                                      ((scrollX + gridW) / colPitch).ceil() + 2,
                                    );

                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: SizedBox(
                                        width: totalW,
                                        height: cellH,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            for (var c = c0; c <= c1; c++)
                                              Positioned(
                                                key: ValueKey<int>(r * cab.cols + c),
                                                left: c * colPitch,
                                                top: 0,
                                                width: cellW,
                                                height: cellH,
                                                child: RepaintBoundary(
                                                  child: _buildCell(
                                                    cab: cab,
                                                    r: r,
                                                    c: c,
                                                    denseCols: denseCols,
                                                    denseRows: cellH < 90,
                                                    hPad: hPad,
                                                    vPad: vPad,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell({
    required CabinetRecord cab,
    required int r,
    required int c,
    required bool denseCols,
    required bool denseRows,
    required double hPad,
    required double vPad,
  }) {
    final slot = r * cab.cols + c;
    final batches = widget.controller.slotBatches(slot);

    return _BinCell(
      row: r,
      col: c,
      batches: batches,
      selected: widget.controller.selectedSlot == slot,
      denseCols: denseCols,
      denseRows: denseRows,
      isDesktop: widget.isDesktop,
      tl: widget.tl,
      hPad: hPad,
      vPad: vPad,
      onTap: () {
        if (batches.isNotEmpty) {
          widget.controller.selectSlot(slot);
        } else {
          widget.controller.startStockSlot(slot);
        }
      },
    );
  }
}

class _BinCell extends StatefulWidget {
  final int row;
  final int col;
  final List<MedicineRecord> batches;
  final bool selected;
  final bool denseCols;
  final bool denseRows;
  final bool isDesktop;
  final bool tl;
  final double hPad;
  final double vPad;
  final VoidCallback onTap;

  const _BinCell({
    required this.row,
    required this.col,
    required this.batches,
    required this.selected,
    required this.denseCols,
    required this.denseRows,
    required this.isDesktop,
    required this.tl,
    required this.hPad,
    required this.vPad,
    required this.onTap,
  });

  @override
  State<_BinCell> createState() => _BinCellState();
}

class _BinCellState extends State<_BinCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selCtrl;

  @override
  void initState() {
    super.initState();
    _selCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _BinCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _selCtrl.forward();
      } else {
        _selCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _selCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.batches.isNotEmpty ? widget.batches.first : null;
    var totalStock = 0;
    for (final b in widget.batches) {
      totalStock += b.stock;
    }

    final days = first?.daysLeft;
    final expired = days != null && days < 0;
    final warning = first != null && !expired && (days! <= 30 || totalStock <= 15);

    final accent = first == null
        ? Palette.darkCyan
        : ConsoleController.statusColor(days!, totalStock);

    final baseCoord = widget.denseCols
        ? 'R${widget.row + 1}·B${widget.col + 1}'
        : 'R${widget.row + 1} · B${widget.col + 1}';
    final coordText = first != null ? '$baseCoord · ${totalStock}U' : baseCoord;

    final reason = first != null
        ? ConsoleController.statusReason(first, totalStock, tl: widget.tl)
        : null;

    final labelSize = widget.denseRows ? 13.0 : (widget.isDesktop ? 18.0 : 15.0);

    Color badgeBg = Palette.brightSnow.withValues(alpha: 0.0);
    Color badgeFg = Palette.slateMuted;
    if (expired) {
      badgeBg = Palette.scarletFire;
      badgeFg = Palette.brightSnow;
    } else if (warning) {
      badgeBg = Palette.amberGlow;
      badgeFg = Palette.prussianBlue;
    }

    return HoverRegion(
      onTap: widget.onTap,
      builder: (_, hovered) {
        final highlighted = widget.selected || hovered;
        final lift = highlighted ? -3.0 : 0.0;

        Color coordColor = Palette.slateMuted;
        if (widget.selected) {
          coordColor = accent;
        } else if (hovered) {
          coordColor = Palette.prussianBlue;
        }

        Color emptyColor = Palette.borderLight;
        if (widget.selected) {
          emptyColor = Palette.darkCyan;
        } else if (hovered) {
          emptyColor = Palette.slateMuted;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: lift),
          duration: const Duration(milliseconds: 220),
          curve: Motion.smooth,
          builder: (_, dy, child) => Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
          child: AnimatedBuilder(
            animation: _selCtrl,
            builder: (context, _) {
              final selT = Motion.smooth.transform(_selCtrl.value);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Motion.smooth,
                decoration: BoxDecoration(
                  color: highlighted ? Palette.pureWhite : Palette.brightSnow,
                  boxShadow: highlighted
                      ? [
                          BoxShadow(
                            color: Palette.prussianBlue.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: Stack(
                  children: [
                    if (selT > 0.0)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: selT,
                          child: Container(color: accent.withValues(alpha: 0.08)),
                        ),
                      ),
                    if (selT > 0.0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.topCenter,
                          heightFactor: selT,
                          child: Container(width: 3.0, color: accent),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              widget.hPad,
                              widget.vPad,
                              widget.hPad,
                              math.max(4.0, widget.vPad * 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        coordText,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          color: coordColor,
                                          fontSize: widget.denseCols ? 9 : 11,
                                          height: 1.1,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: widget.denseCols ? 0.3 : 0.8,
                                        ),
                                      ),
                                    ),
                                    if (first != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        color: badgeBg,
                                        child: Text(
                                          ExpiryParser.badge(first, tl: widget.tl),
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: badgeFg,
                                            fontSize: widget.denseCols ? 8.5 : 9.5,
                                            height: 1.0,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: first != null
                                          ? TallManText(
                                              text: first.displayName,
                                              highlightColor: Palette.darkCyan,
                                              baseStyle: TextStyle(
                                                color: Palette.prussianBlue,
                                                fontSize: labelSize,
                                                height: 1.0,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5,
                                              ),
                                            )
                                          : Text(
                                              highlighted
                                                  ? (widget.tl ? '+ ILAGAY' : '+ ASSIGN')
                                                  : '—',
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: emptyColor,
                                                fontSize: labelSize,
                                                height: 1.0,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                if (reason != null && !widget.denseRows)
                                  AnimatedSlide(
                                    duration: const Duration(milliseconds: 360),
                                    curve: Motion.smooth,
                                    offset: hovered ? Offset.zero : const Offset(0, 0.25),
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 260),
                                      curve: Curves.easeOutCubic,
                                      opacity: hovered ? 1.0 : 0.0,
                                      child: Text(
                                        reason,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: widget.denseCols ? 8 : 9,
                                          height: 1.1,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (first != null)
                          Row(
                            children: [
                              for (var i = 0; i < widget.batches.length; i++)
                                Flexible(
                                  flex: math.max(widget.batches[i].stock, 1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Motion.smooth,
                                    margin: EdgeInsets.only(
                                      right: i < widget.batches.length - 1 ? 2.0 : 0.0,
                                    ),
                                    height: highlighted ? 4.0 : 3.0,
                                    color: ConsoleController.statusColor(
                                      widget.batches[i].daysLeft,
                                      totalStock,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Motion.smooth,
                            height: highlighted ? 4.0 : 3.0,
                            width: double.infinity,
                            color: emptyColor,
                          ),
                      ],
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
