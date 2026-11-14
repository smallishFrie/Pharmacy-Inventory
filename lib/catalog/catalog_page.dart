import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/lasa_engine.dart';
import '../data/models.dart';
import '../data/pb_client.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<_CatalogItem> _items = [];
  _GroupMode _mode = _GroupMode.category;
  String? _activeGroup;

  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_refresh);
    _searchCtrl.addListener(_refresh);
    _load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_refresh);
    _searchCtrl.removeListener(_refresh);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // // Private Functions

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });

    try {
      final cabs = await PbClient.getCabinets();
      final meds = await PbClient.getMedicines();

      final colMap = <String, int>{};
      for (final c in cabs) {
        colMap[c.name] = c.cols;
      }

      final grouped = <String, List<MedicineRecord>>{};
      for (final m in meds) {
        final key =
            '${LasaEngine.normalize(m.name)}_${m.dosage.toLowerCase()}_${m.brand.toLowerCase()}';
        (grouped[key] ??= []).add(m);
      }

      final built = <_CatalogItem>[];
      for (final batches in grouped.values) {
        batches.sort((a, b) => a.expiry.compareTo(b.expiry));

        MedicineRecord? firstValid;
        var validUnits = 0;
        for (final b in batches) {
          if (b.daysLeft >= 0) {
            firstValid ??= b;
            validUnits += b.stock;
          }
        }

        final rep = firstValid ?? batches.first;
        final cols = colMap[rep.cabinet] ?? 4;

        built.add(
          _CatalogItem(
            name: rep.displayName,
            dosage: rep.dosage,
            coord: rep.coord(cols),
            units: validUnits,
            firstBatch: rep,
          ),
        );
      }

      built.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _items = built;
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
    }
  }

  String _groupKeyFor(_CatalogItem item, bool tl) {
    switch (_mode) {
      case _GroupMode.category:
        return item.firstBatch.categoryLabel(tl: tl).toUpperCase();
      case _GroupMode.brand:
        return item.firstBatch.brandLabel(tl: tl).toUpperCase();
      case _GroupMode.az:
        final clean = item.name.trim();
        if (clean.isEmpty) return '#';
        final ch = clean[0].toUpperCase();
        return RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#';
    }
  }

  List<String> _allGroups(bool tl) {
    final set = <String>{};
    for (final item in _items) {
      set.add(_groupKeyFor(item, tl));
    }
    final list = set.toList()..sort();
    return list;
  }

  Iterable<String> _autocompleteCandidates(bool tl) {
    final out = <String>{};
    for (final item in _items) {
      out.add(item.name);
      out.add(item.firstBatch.categoryLabel(tl: tl));
      out.add(item.firstBatch.brandLabel(tl: tl));
    }
    return out;
  }

  double _itemScore(String q, _CatalogItem item, bool tl) {
    final sName = Motion.fuzzyScore(q, item.name);
    final sBrand = Motion.fuzzyScore(q, item.firstBatch.brandLabel(tl: tl));
    final sCat = Motion.fuzzyScore(q, item.firstBatch.categoryLabel(tl: tl));
    return math.max(sName, math.max(sBrand, sCat));
  }

  List<_CatalogItem> _filteredItems(bool tl) {
    final q = _searchCtrl.text.trim();
    final scored = <(_CatalogItem, double)>[];

    for (final item in _items) {
      if (_activeGroup != null && _groupKeyFor(item, tl) != _activeGroup) {
        continue;
      }
      if (q.isEmpty) {
        scored.add((item, 1.0));
      } else {
        final s = _itemScore(q, item, tl);
        if (s >= 0.42) scored.add((item, s));
      }
    }

    scored.sort((a, b) {
      final aAvail = a.$1.units > 0 ? 1 : 0;
      final bAvail = b.$1.units > 0 ? 1 : 0;
      if (aAvail != bAvail) return bAvail.compareTo(aAvail);

      if (q.isNotEmpty) {
        final cmp = b.$2.compareTo(a.$2);
        if (cmp != 0) return cmp;
      }
      return a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });

    return [for (final entry in scored) entry.$1];
  }

  // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width > 760;
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final kbOpen = kbBottom > 0;
    final tl = Localizations.localeOf(context).languageCode == 'tl';

    final hPad = isDesktop ? 64.0 : 28.0;
    final topPad = isDesktop ? 64.0 : (kbOpen ? 20.0 : 32.0);
    final botPad = kbOpen ? kbBottom + 16.0 : (isDesktop ? 64.0 : 32.0);

    final routeAnim =
        ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0);
    final entryAnim = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.28, 1.0, curve: Motion.smooth),
      reverseCurve: const FlippedCurve(Motion.smooth),
    );

    final visible = _filteredItems(tl);
    final groups = _allGroups(tl);
    final count = visible.length.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Palette.brightSnow,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: entryAnim,
        builder: (context, child) {
          final t = entryAnim.value;
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(-24.0 * (1.0 - t), 0.0),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, botPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildExitButton(),
                  if (!_offline && _items.isNotEmpty) _buildModeSwitch(tl),
                ],
              ),
              if (!kbOpen && !_offline && groups.isNotEmpty) ...[
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTab(
                        label: tl ? 'LAHAT' : 'ALL',
                        selected: _activeGroup == null,
                        onTap: () => setState(() => _activeGroup = null),
                      ),
                      for (final g in groups)
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0),
                          child: _buildTab(
                            label: g,
                            selected: _activeGroup == g,
                            onTap: () => setState(() => _activeGroup = g),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: kbOpen ? 16.0 : 28.0),
              Text(
                tl
                    ? 'DIREKTORYO NG GAMOT  //  $count NAKALISTA'
                    : 'MEDICINE DIRECTORY  //  $count LISTED',
                style: const TextStyle(
                  color: Palette.darkCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody(visible, isDesktop, tl)),
              const SizedBox(height: 18),
              _buildSearchBar(tl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch(bool tl) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildModeOption(
          label: tl ? 'URI' : 'TYPE',
          mode: _GroupMode.category,
        ),
        const SizedBox(width: 18),
        _buildModeOption(
          label: tl ? 'TATAK' : 'BRAND',
          mode: _GroupMode.brand,
        ),
        const SizedBox(width: 18),
        _buildModeOption(
          label: 'A–Z',
          mode: _GroupMode.az,
        ),
      ],
    );
  }

  Widget _buildModeOption({required String label, required _GroupMode mode}) {
    final selected = _mode == mode;
    return HoverRegion(
      onTap: () {
        if (_mode == mode) return;
        setState(() {
          _mode = mode;
          _activeGroup = null;
        });
      },
      builder: (_, hovered) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? Palette.darkCyan
                  : (hovered ? Palette.prussianBlue : Palette.slateMuted),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Motion.smooth,
            height: 2,
            width: selected ? 20 : (hovered ? 10 : 0),
            color: Palette.darkCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<_CatalogItem> items, bool isDesktop, bool tl) {
    if (_loading) {
      return Center(
        child: Text(
          tl ? 'NAGLO-LOAD...' : 'LOADING CATALOG...',
          style: const TextStyle(
            color: Palette.slateMuted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
      );
    }

    if (_offline) {
      return Center(
        child: HoverRegion(
          onTap: _load,
          builder: (_, hovered) => Text(
            tl
                ? 'Offline ang server. Pindutin upang subukan muli.'
                : 'Server offline. Click to retry connection.',
            style: TextStyle(
              color: hovered ? Palette.prussianBlue : Palette.slateMuted,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          tl ? 'Walang nahanap na gamot.' : 'No matching medicines found.',
          style: const TextStyle(
            color: Palette.slateMuted,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    if (hasQuery) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: isDesktop ? 360.0 : 420.0,
          mainAxisExtent: 124.0,
          crossAxisSpacing: 20.0,
          mainAxisSpacing: 20.0,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i], tl),
      );
    }

    final sections = <String, List<_CatalogItem>>{};
    for (final item in items) {
      final k = _groupKeyFor(item, tl);
      (sections[k] ??= []).add(item);
    }
    final sectionKeys = sections.keys.toList()..sort();

    return CustomScrollView(
      slivers: [
        for (final key in sectionKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 18.0, bottom: 10.0),
              child: Row(
                children: [
                  Text(
                    '$key  //  ${sections[key]!.length.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Palette.prussianBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(height: 1, color: Palette.borderLight),
                  ),
                ],
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isDesktop ? 360.0 : 420.0,
              mainAxisExtent: 124.0,
              crossAxisSpacing: 20.0,
              mainAxisSpacing: 20.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildCard(sections[key]![i], tl),
              childCount: sections[key]!.length,
            ),
          ),
        ],
      ],
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
              color: Palette.prussianBlue,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Motion.smooth,
            style: TextStyle(
              color: hovered ? Palette.prussianBlue : Palette.slateMuted,
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
            width: selected ? 24 : (hovered ? 12 : 0),
            color: selected ? Palette.darkCyan : Palette.prussianBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_CatalogItem item, bool tl) {
    final expired = item.units <= 0;
    final barColor = expired ? Palette.borderLight : Palette.darkCyan;
    final statusColor =
        expired ? Palette.slateMuted.withValues(alpha: 0.65) : Palette.darkCyan;
    final status =
        expired ? (tl ? 'WALANG STOK' : 'UNAVAILABLE') : '${item.units} UNITS';

    final brand = item.firstBatch.brandLabel(tl: tl).toUpperCase();
    final cat = item.firstBatch.categoryLabel(tl: tl).toUpperCase();

    return HoverRegion(
      cursor: SystemMouseCursors.basic,
      builder: (_, hovered) => AnimatedSlide(
        duration: const Duration(milliseconds: 340),
        curve: Motion.smooth,
        offset: (hovered && !expired) ? const Offset(0, -0.03) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Motion.smooth,
          color: (hovered && !expired) ? Palette.pureWhite : Palette.brightSnow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$cat · $brand',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: expired
                                  ? Palette.slateMuted.withValues(alpha: 0.55)
                                  : (hovered
                                      ? Palette.prussianBlue
                                      : Palette.slateMuted),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: TallManText(
                            text: item.name,
                            highlightColor: expired ? null : Palette.darkCyan,
                            baseStyle: TextStyle(
                              color: expired
                                  ? Palette.slateMuted.withValues(alpha: 0.6)
                                  : Palette.prussianBlue,
                              fontSize: 22,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.dosage,
                          style: TextStyle(
                            color: expired
                                ? Palette.slateMuted.withValues(alpha: 0.5)
                                : Palette.slateMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.coord,
                      style: TextStyle(
                        color: Palette.slateMuted.withValues(
                          alpha: expired ? 0.45 : 0.7,
                        ),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Motion.smooth,
                height: (hovered && !expired) ? 4.0 : 3.0,
                width: double.infinity,
                color: barColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool tl) {
    final hasQuery = _searchCtrl.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FishInput(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                candidates: _autocompleteCandidates(tl),
                hintText: tl
                    ? 'MAGHANAP NG GAMOT, TATAK, O URI'
                    : 'SEARCH MEDICINE, BRAND, OR TYPE',
                style: const TextStyle(
                  color: Palette.prussianBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
                hintStyle: const TextStyle(
                  color: Palette.slateMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
                cursorColor: Palette.darkCyan,
                ghostColor: Palette.darkCyan.withValues(alpha: 0.42),
                tabPillColor: Palette.darkCyan,
              ),
            ),
            if (hasQuery)
              HoverRegion(
                onTap: _searchCtrl.clear,
                builder: (_, hovered) => Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    tl ? 'BURAHIN' : 'CLEAR',
                    style: TextStyle(
                      color: hovered ? Palette.scarletFire : Palette.slateMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
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
          color: (_searchFocus.hasFocus || hasQuery)
              ? Palette.darkCyan
              : Palette.borderLight,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// // Types

enum _GroupMode { category, brand, az }

class _CatalogItem {
  final String name;
  final String dosage;
  final String coord;
  final int units;
  final MedicineRecord firstBatch;

  const _CatalogItem({
    required this.name,
    required this.dosage,
    required this.coord,
    required this.units,
    required this.firstBatch,
  });
}
