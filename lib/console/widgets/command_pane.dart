import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/lasa_engine.dart';
import '../../data/models.dart';
import '../../data/pb_client.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../console_controller.dart';
import '../expiry_parser.dart';

class CommandPane extends StatefulWidget {
  final ConsoleController controller;
  final AnimationController feedbackAnim;
  final bool isDesktop;
  final double paneHeight;
  final bool tl;
  final bool isHovered;

  const CommandPane({
    super.key,
    required this.controller,
    required this.feedbackAnim,
    required this.isDesktop,
    required this.paneHeight,
    required this.tl,
    required this.isHovered,
  });

  @override
  State<CommandPane> createState() => _CommandPaneState();
}

class _CommandPaneState extends State<CommandPane> {
  int? _hoveredBatch;

  ConsoleController get _c => widget.controller;

  // // Private Functions

  //Returns `(eyebrow, headline, hint)`
  (String, String, String) _resolveCopy(
    List<MedicineRecord> batches,
    int totalStock,
    int batchNum,
  ) {
    final tl = widget.tl;
    final cols = _c.activeCabinet?.cols ?? 4;

    if (_c.isLoading) {
      return ('', tl ? 'Naglo-\nload.' : 'Syncing\nNode.', '...');
    }

    if (_c.isOffline) {
      return (
        'POCKETBASE OFFLINE · ${PbClient.baseUrl}',
        tl ? 'Walang\nKoneksyon.' : 'Database\nOffline.',
        tl
            ? 'PINDUTIN ANG ARROW PARA SUBUKAN MULI'
            : 'CLICK ARROW TO RETRY CONNECTION',
      );
    }

    switch (_c.flow) {
      case PromptFlow.confirmDeleteBatch:
        final target = _c.activeBatch;
        final tag = '#${batchNum.toString().padLeft(2, '0')}';
        final units = target?.stock ?? 0;
        final label = target != null ? '${target.displayName} ${target.dosage}' : '';
        return (
          tl
              ? 'KUMPIRMAHIN ANG PAGBURA  //  $label · $units UNIT'
              : 'CONFIRM DELETION  //  $label · $units UNITS',
          tl ? 'Burahin ang\nBatch $tag?' : 'Delete\nBatch $tag?',
          tl ? 'HINDI NA ITO MAIBABALIK' : 'THIS ACTION CANNOT BE UNDONE',
        );
      case PromptFlow.confirmDeleteCabinet:
        final cabName = _c.activeCabinet?.name ?? '';
        final count = _c.cabBatchCount;
        final word = count == 1 ? 'BATCH' : (tl ? 'BATCH' : 'BATCHES');
        return (
          tl
              ? 'PERMANENTENG PAGBURA  //  KABINET $cabName · $count $word'
              : 'PERMANENT DELETION  //  CABINET $cabName · $count $word',
          tl ? 'Burahin ang\nKabinet $cabName?' : 'Delete\nCabinet $cabName?',
          tl ? 'HINDI NA ITO MAIBABALIK' : 'THIS ACTION CANNOT BE UNDONE',
        );
      case PromptFlow.newCabinetName:
        return (
          tl ? 'BAGONG KABINET · 01/02' : 'NEW CABINET · 01/02',
          tl ? 'Pangalan\nng Kabinet.' : 'Cabinet\nCode.',
          tl ? 'ILAGAY ANG PANGALAN NG KABINET' : 'ENTER CABINET CODE',
        );
      case PromptFlow.newCabinetGrid:
        return (
          '${tl ? "KABINET" : "CABINET"} ${_c.draftCabName} · 02/02',
          tl ? 'Bilang ng\nIstante.' : 'Shelf\nMatrix.',
          tl ? 'ILAGAY ANG ROW X BIN' : 'ENTER ROWS X BINS',
        );
      case PromptFlow.stockName:
      case PromptFlow.editName:
        final r = ((_c.selectedSlot ?? 0) ~/ cols) + 1;
        final b = ((_c.selectedSlot ?? 0) % cols) + 1;
        final step = _c.flow == PromptFlow.editName
            ? (tl ? 'BAGUHIN 01/04' : 'EDIT 01/04')
            : '01/06';
        return (
          '${_c.activeCabinet?.name} · R$r-B$b  //  $step',
          tl ? 'Pangalan\nng Gamot.' : 'Medicine\nName.',
          tl ? 'ILAGAY ANG PANGALAN NG GAMOT' : 'ENTER MEDICINE NAME',
        );
      case PromptFlow.stockBrand:
      case PromptFlow.editBrand:
        final step = _c.flow == PromptFlow.editBrand ? '02/04' : '02/06';
        return (
          '${_c.draftMedName}  //  $step',
          tl ? 'Tatak ng\nGamot.' : 'Brand\nName.',
          tl
              ? 'ILAGAY ANG TATAK (ENTER KUNG GENERIKO)'
              : 'ENTER BRAND (HIT ENTER FOR GENERIC)',
        );
      case PromptFlow.stockCategory:
      case PromptFlow.editCategory:
        final step = _c.flow == PromptFlow.editCategory ? '03/04' : '03/06';
        final brand = _c.draftBrand.isEmpty
            ? (tl ? 'GENERIKO' : 'GENERIC')
            : _c.draftBrand.toUpperCase();
        return (
          '${_c.draftMedName} · $brand  //  $step',
          tl ? 'Uri ng\nGamot.' : 'Drug\nCategory.',
          tl
              ? 'ILAGAY ANG URI (HAL. ANTIBIOTIC)'
              : 'ENTER CATEGORY (E.G. ANTIBIOTIC)',
        );
      case PromptFlow.stockDosage:
      case PromptFlow.editDosage:
        final step = _c.flow == PromptFlow.editDosage ? '04/04' : '04/06';
        return (
          '${_c.draftMedName}  //  $step',
          tl ? 'Sukat ng\nDosis.' : 'Dosage\nStrength.',
          tl ? 'ILAGAY ANG SUKAT NG DOSIS' : 'ENTER DOSAGE STRENGTH',
        );
      case PromptFlow.stockQty:
      case PromptFlow.addBatchQty:
      case PromptFlow.editBatchQty:
        final num = _c.flow == PromptFlow.editBatchQty ? batchNum : _c.nextBatchNum;
        final prefix = _c.flow == PromptFlow.stockQty ? '05/06  //  ' : '';
        return (
          '$prefix${_c.draftMedName} ${_c.draftDosage} · BATCH #${num.toString().padLeft(2, '0')}',
          tl ? 'Bilang\nng Unit.' : 'Batch\nUnits.',
          tl ? 'ILAGAY ANG BILANG NG UNIT' : 'ENTER UNIT QUANTITY',
        );
      case PromptFlow.stockExpiry:
      case PromptFlow.addBatchExpiry:
      case PromptFlow.editBatchExpiry:
        final num = _c.flow == PromptFlow.editBatchExpiry ? batchNum : _c.nextBatchNum;
        final prefix = _c.flow == PromptFlow.stockExpiry ? '06/06  //  ' : '';
        return (
          '${prefix}BATCH #${num.toString().padLeft(2, '0')} · ${_c.draftQty} UNITS',
          tl ? 'Petsa ng\nExpiry.' : 'Batch\nExpiry.',
          tl ? 'MM/YYYY O YYYY-MM-DD' : 'MM/YYYY OR YYYY-MM-DD',
        );
      case PromptFlow.idle:
        break;
    }

    if (batches.isNotEmpty) {
      final first = batches.first;
      final word = batches.length == 1 ? 'BATCH' : 'BATCHES';
      final brand = first.brandLabel(tl: tl).toUpperCase();
      final cat = first.categoryLabel(tl: tl).toUpperCase();
      final lasa = first.lasaGroup.isNotEmpty ? ' · CF. ${first.lasaGroup}' : '';
      return (
        '${first.coord(cols)} · $cat · $brand  //  $totalStock UNITS · ${batches.length} $word$lasa',
        '${first.displayName}\n${first.dosage}.',
        tl ? 'MAGHANAP NG GAMOT' : 'SEARCH MEDICINE',
      );
    }

    if (_c.cabinets.isEmpty) {
      return (
        tl ? 'WALANG KABINET' : 'NO CABINETS CONFIGURED',
        tl ? 'Unang\nKabinet.' : 'Setup\nCabinet.',
        tl ? 'PINDUTIN ANG + KABINET SA KANAN' : 'SELECT + CABINET ON THE RIGHT',
      );
    }

    final cab = _c.activeCabinet!;
    final count = _c.cabBatchCount;

    if (count == 0) {
      return (
        '${tl ? "KABINET" : "CABINET"} ${cab.name}  //  ${cab.rows}×${cab.cols}',
        tl ? 'Walang\nStok.' : 'Zero\nStock.',
        tl
            ? 'PUMILI NG SLOT SA KANAN PARA MAGLAGAY'
            : 'SELECT ANY SLOT ON THE RIGHT TO ASSIGN',
      );
    }

    final padCount = count.toString().padLeft(2, '0');
    return (
      '${tl ? "KABINET" : "CABINET"} ${cab.name}  //  ${cab.rows}×${cab.cols}',
      tl ? '$padCount\nBatch.' : '$padCount\n${count == 1 ? "Batch." : "Batches."}',
      tl ? 'MAGHANAP O PUMILI NG SLOT' : 'SEARCH OR SELECT A SLOT',
    );
  }

  // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final compact = !widget.isDesktop && widget.paneHeight < 360;
    final pad = widget.isDesktop ? 64.0 : (compact ? 24.0 : 32.0);
    final titleSize = widget.isDesktop ? 60.0 : (compact ? 38.0 : 46.0);
    final active = widget.isHovered ||
        _c.inputFocus.hasFocus ||
        _c.unitFocus.hasFocus ||
        _c.flow != PromptFlow.idle;

    final batches = _c.currentBatches;
    var totalStock = 0;
    for (final b in batches) {
      totalStock += b.stock;
    }
    final batchNum = _c.activeBatch?.batchNum ?? 1;

    final (eyebrow, headline, hint) = _resolveCopy(batches, totalStock, batchNum);

    Color eyebrowColor;
    if (_c.isOffline || _c.isConfirmingDelete) {
      eyebrowColor = Palette.scarletFire;
    } else if (batches.isNotEmpty) {
      eyebrowColor = ConsoleController.statusColor(
        batches.first.daysLeft,
        totalStock,
      );
    } else {
      eyebrowColor = Palette.darkCyan;
    }

    final canDeselect = !_c.isOffline &&
        !_c.isConfirmingDelete &&
        (_c.flow != PromptFlow.idle || _c.selectedSlot != null);

    final danger = _c.hasError || _c.isConfirmingDelete;

    return AnimatedBuilder(
      animation: widget.feedbackAnim,
      builder: (context, child) {
        final t = widget.feedbackAnim.value;
        final dx = (widget.feedbackAnim.isAnimating && _c.hasError)
            ? math.sin(t * math.pi * 6) * (1.0 - t) * 20.0
            : 0.0;
        final flash = widget.feedbackAnim.isAnimating
            ? Curves.easeOutCubic.transform(1.0 - t) * 0.24
            : 0.0;
        final flashColor = _c.hasSuccess ? Palette.darkCyan : Palette.scarletFire;

        return Container(
          color: Color.lerp(Palette.prussianBlue, flashColor, flash),
          padding: EdgeInsets.all(pad),
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildExitButton(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_c.canStepBack) ...[
                    _buildTopRightAction(
                      label: widget.tl ? '< BALIK' : '< BACK',
                      lineColor: Palette.darkCyan,
                      onTap: _c.stepBack,
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (canDeselect)
                    _buildTopRightAction(
                      label: widget.tl ? 'ISARA' : 'DESELECT',
                      lineColor: Palette.amberGlow,
                      onTap: _c.deselect,
                    ),
                ],
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: Motion.fadeSlide(
                        inMs: 360,
                        outMs: 220,
                        offset: const Offset(0.03, 0.0),
                        child: Text(
                          eyebrow,
                          key: ValueKey<String>(eyebrow),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: eyebrowColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                  Motion.fadeSlide(
                    inMs: 420,
                    outMs: 240,
                    offset: const Offset(0.0, 0.08),
                    child: KeyedSubtree(
                      key: ValueKey<String>(headline),
                      child: TallManText(
                        text: headline,
                        maxLines: 3,
                        overflow: TextOverflow.visible,
                        highlightColor: danger ? null : Palette.amberGlow,
                        baseStyle: TextStyle(
                          color: danger ? Palette.scarletFire : Palette.brightSnow,
                          fontSize: titleSize,
                          height: 0.95,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.2,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    reverseDuration: const Duration(milliseconds: 200),
                    switchInCurve: Motion.smooth,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.06),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: _buildActions(batches, totalStock, batchNum),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_c.isConfirmingDelete)
                SizedBox(
                  height: 22,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hint,
                      style: TextStyle(
                        color: Palette.scarletFire.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FishInput(
                        controller: _c.inputCtrl,
                        focusNode: _c.inputFocus,
                        candidates: _c.promptCandidates,
                        readOnly: _c.isOffline,
                        textInputAction: _c.isDosageStep
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: _c.submitCommand,
                        onChanged: (_) => _c.clearError(),
                        onEscape: _c.canStepBack ? _c.stepBack : _c.deselect,
                        hintText: hint,
                        style: const TextStyle(
                          color: Palette.brightSnow,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                        hintStyle: TextStyle(
                          color: _c.hasError ? Palette.scarletFire : Palette.slateMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                        cursorColor: Palette.amberGlow,
                        ghostColor: Palette.amberGlow.withValues(alpha: 0.45),
                        tabPillColor: Palette.amberGlow,
                      ),
                    ),
                    if (_c.isDosageStep) ...[
                      Container(
                        height: 18,
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: Palette.brightSnow.withValues(alpha: 0.22),
                      ),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _c.unitCtrl,
                          focusNode: _c.unitFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _c.submitCommand(),
                          style: const TextStyle(
                            color: Palette.amberGlow,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          cursorColor: Palette.amberGlow,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'mg',
                            hintStyle: TextStyle(
                              color: Palette.amberGlow.withValues(alpha: 0.45),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                    HoverRegion(
                      onTap: _c.submitCommand,
                      builder: (_, hovered) => Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 380),
                          curve: Motion.smooth,
                          offset: hovered
                              ? const Offset(0.28, 0)
                              : (active ? const Offset(0.16, 0) : Offset.zero),
                          child: Icon(
                            _c.isOffline ? Icons.refresh_sharp : Icons.arrow_forward_sharp,
                            color: _c.hasError ? Palette.scarletFire : Palette.amberGlow,
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
                color: danger
                    ? Palette.scarletFire
                    : (active
                        ? Palette.amberGlow
                        : Palette.brightSnow.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRightAction({
    required String label,
    required Color lineColor,
    required VoidCallback onTap,
  }) {
    return HoverRegion(
      onTap: onTap,
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
                color: hovered
                    ? Palette.brightSnow
                    : Palette.brightSnow.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
              child: Text(label),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Motion.smooth,
            height: 2,
            width: hovered ? 32 : 0,
            color: lineColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    List<MedicineRecord> batches,
    int totalStock,
    int batchNum,
  ) {
    if (_c.isOffline) return const SizedBox.shrink();

    if (_c.isConfirmingDelete) {
      return Padding(
        key: const ValueKey<String>('confirm_delete'),
        padding: const EdgeInsets.only(top: 28.0),
        child: Wrap(
          spacing: 28,
          runSpacing: 12,
          children: [
            _buildInlineAction(
              label: widget.tl ? 'OO, BURAHIN' : 'CONFIRM DELETE',
              color: Palette.scarletFire,
              onTap: _c.confirmDelete,
            ),
            _buildInlineAction(
              label: widget.tl ? 'KANSELAHIN' : 'CANCEL',
              color: Palette.brightSnow,
              onTap: _c.cancelDelete,
            ),
          ],
        ),
      );
    }

    if (batches.isNotEmpty && _c.flow == PromptFlow.idle) {
      final tag = batchNum.toString().padLeft(2, '0');
      return Padding(
        key: const ValueKey<String>('slot_actions'),
        padding: const EdgeInsets.only(top: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBatchTape(batches, totalStock),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildInlineAction(
                  label: '+ BATCH',
                  color: Palette.amberGlow,
                  onTap: _c.startAddBatch,
                ),
                _buildInlineAction(
                  label: widget.tl ? 'BAGUHIN #$tag' : 'EDIT #$tag',
                  color: Palette.darkCyan,
                  onTap: _c.startEditBatch,
                ),
                _buildInlineAction(
                  label: widget.tl ? 'DETALYE' : 'DETAILS',
                  color: Palette.brightSnow,
                  onTap: _c.startRename,
                ),
                _buildInlineAction(
                  label: widget.tl ? 'BURAHIN #$tag' : 'DELETE #$tag',
                  color: Palette.scarletFire,
                  onTap: _c.promptDeleteBatch,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBatchTape(List<MedicineRecord> batches, int totalStock) {
    final safeIdx = _c.selectedBatchIndex.clamp(0, math.max(0, batches.length - 1)).toInt();
    final reasonIdx = (_hoveredBatch != null && _hoveredBatch! < batches.length)
        ? _hoveredBatch!
        : safeIdx;
    final batch = batches[reasonIdx];
    final accent = ConsoleController.statusColor(batch.daysLeft, totalStock);
    final reason =
        '#${batch.batchNum.toString().padLeft(2, '0')} · ${ConsoleController.statusReason(batch, totalStock, tl: widget.tl)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < batches.length; i++)
              _buildBatchChip(batches[i], i, i == safeIdx, totalStock),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 16,
          width: double.infinity,
          child: Motion.fadeSlide(
            inMs: 360,
            outMs: 200,
            offset: const Offset(0.03, 0.0),
            child: Text(
              reason,
              key: ValueKey<String>(reason),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchChip(
    MedicineRecord batch,
    int index,
    bool selected,
    int totalStock,
  ) {
    final days = batch.daysLeft;
    final accent = ConsoleController.statusColor(days, totalStock);

    return HoverRegion(
      onTap: () => _c.selectBatch(index),
      onHover: (hovered) {
        setState(() {
          if (hovered) {
            _hoveredBatch = index;
          } else if (_hoveredBatch == index) {
            _hoveredBatch = null;
          }
        });
      },
      builder: (_, hovered) {
        var bgAlpha = 0.04;
        if (selected) {
          bgAlpha = 0.13;
        } else if (hovered) {
          bgAlpha = 0.08;
        }

        return AnimatedSlide(
          duration: const Duration(milliseconds: 360),
          curve: Motion.smooth,
          offset: hovered ? const Offset(0, -0.05) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Motion.smooth,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Palette.brightSnow.withValues(alpha: bgAlpha),
              border: Border(
                bottom: BorderSide(
                  color: (selected || hovered)
                      ? accent
                      : Palette.brightSnow.withValues(alpha: 0.16),
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '#${batch.batchNum.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                HoverRegion(
                  onTap: () => _c.adjustStock(batch, -1),
                  builder: (_, decHover) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Motion.smooth,
                      style: TextStyle(
                        color: decHover
                            ? (batch.stock <= 1 ? Palette.scarletFire : Palette.amberGlow)
                            : Palette.brightSnow.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                      child: const Text('−'),
                    ),
                  ),
                ),
                Text(
                  '${batch.stock}U',
                  style: const TextStyle(
                    color: Palette.brightSnow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                HoverRegion(
                  onTap: () => _c.adjustStock(batch, 1),
                  builder: (_, incHover) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Motion.smooth,
                      style: TextStyle(
                        color: incHover
                            ? Palette.amberGlow
                            : Palette.brightSnow.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                      child: const Text('+'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ExpiryParser.badge(batch, tl: widget.tl),
                  style: TextStyle(
                    color: (hovered || selected || days <= 30)
                        ? accent
                        : Palette.brightSnow.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInlineAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return HoverRegion(
      onTap: onTap,
      builder: (_, hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: Motion.smooth,
            offset: hovered ? const Offset(0.08, 0) : Offset.zero,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: Motion.smooth,
            height: 2,
            width: hovered ? 48 : 24,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton() {
    return HoverRegion(
      onTap: () => Navigator.of(context).pop(),
      builder: (_, hovered) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: Motion.smooth,
            offset: hovered ? const Offset(-0.22, 0) : Offset.zero,
            child: const Icon(
              Icons.arrow_back_sharp,
              color: Palette.brightSnow,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Motion.smooth,
            style: TextStyle(
              color: hovered ? Palette.brightSnow : Palette.slateMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
            child: const Text('GATEWAY'),
          ),
        ],
      ),
    );
  }
}
