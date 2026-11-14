import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/lasa_engine.dart';
import '../data/models.dart';
import '../data/pb_client.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import 'expiry_parser.dart';

class ConsoleController extends ChangeNotifier {
  final TextEditingController inputCtrl = TextEditingController();
  final TextEditingController unitCtrl = TextEditingController(text: 'mg');
  final TextEditingController dispenseCtrl = TextEditingController();

  final FocusNode inputFocus = FocusNode();
  final FocusNode unitFocus = FocusNode();
  final FocusNode dispenseFocus = FocusNode();

  final VoidCallback onSuccess;
  final VoidCallback onError;

  List<CabinetRecord> cabinets = [];
  List<MedicineRecord> records = [];
  Map<int, List<MedicineRecord>> _slotMap = {};

  CabinetRecord? activeCabinet;
  int? selectedSlot;
  int selectedBatchIndex = 0;

  PromptFlow flow = PromptFlow.idle;

  String draftCabName = '';
  String draftMedName = '';
  String draftBrand = '';
  String draftCategory = '';
  String draftDosage = '';
  int draftQty = 0;

  bool isLoading = true;
  bool isOffline = false;
  bool hasError = false;
  bool hasDispenseError = false;
  bool hasSuccess = false;

  ConsoleController({
    required this.onSuccess,
    required this.onError,
  }) {
    inputFocus.addListener(notifyListeners);
    unitFocus.addListener(notifyListeners);
    dispenseFocus.addListener(notifyListeners);
  }

  // // Helpers

  //Returns `(value, unit)`
  static (String, String) splitDosage(String dosage) {
    final s = dosage.trim();
    final match = RegExp(r'^([0-9.]+)\s*(.*)$').firstMatch(s);
    if (match != null) {
      final val = match.group(1) ?? s;
      final unit = (match.group(2) ?? '').trim();
      return (val, unit.isEmpty ? 'mg' : unit);
    }
    return (s, 'mg');
  }

  static String combineDosage(String rawVal, String rawUnit) {
    final val = rawVal.trim();
    final unit = rawUnit.trim().isEmpty ? 'mg' : rawUnit.trim();
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(val)) return '$val$unit';
    return val;
  }

  static Color statusColor(int daysLeft, int totalStock) {
    if (daysLeft < 0) return Palette.scarletFire;
    if (daysLeft <= 30 || totalStock <= 15) return Palette.amberGlow;
    return Palette.darkCyan;
  }

  static String statusReason(
    MedicineRecord batch,
    int totalStock, {
    required bool tl,
  }) {
    final d = batch.daysLeft;
    if (d < 0) {
      final ago = d.abs();
      return tl
          ? 'PASADO · $ago ARAW NA ANG NAKALIPAS'
          : (ago == 1 ? 'EXPIRED · 1 DAY AGO' : 'EXPIRED · $ago DAYS AGO');
    }
    if (d == 0) {
      return tl ? 'MAG-EEXPIRE NGAYONG ARAW' : 'EXPIRES TODAY';
    }
    if (d <= 30) {
      return tl
          ? 'MALAPIT MAG-EXPIRE · $d ARAW NA LANG'
          : 'EXPIRING SOON · $d DAYS LEFT';
    }
    if (totalStock <= 15) {
      return tl
          ? 'MABABANG STOK · $totalStock UNIT NA LANG'
          : 'LOW STOCK · $totalStock UNITS LEFT';
    }
    return tl
        ? 'SAPAT ANG STOK · EXP ${ExpiryParser.shortDate(batch.expiry)}'
        : 'HEALTHY · EXP ${ExpiryParser.shortDate(batch.expiry)}';
  }

  @override
  void dispose() {
    inputFocus.removeListener(notifyListeners);
    unitFocus.removeListener(notifyListeners);
    dispenseFocus.removeListener(notifyListeners);
    inputCtrl.dispose();
    unitCtrl.dispose();
    dispenseCtrl.dispose();
    inputFocus.dispose();
    unitFocus.dispose();
    dispenseFocus.dispose();
    super.dispose();
  }

  // // Private Functions

  void _setInputText(String text) {
    inputCtrl.text = text;
    inputCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  void _rebuildSlots() {
    final cab = activeCabinet;
    if (cab == null) {
      _slotMap = const {};
      return;
    }

    final map = <int, List<MedicineRecord>>{};
    for (final r in records) {
      if (r.cabinet == cab.name) {
        (map[r.slot] ??= []).add(r);
      }
    }
    for (final list in map.values) {
      list.sort((a, b) => a.expiry.compareTo(b.expiry));
    }
    _slotMap = map;
  }

  Iterable<String> _otherNames({String? exclude}) {
    final exNorm = exclude != null ? LasaEngine.normalize(exclude) : '';
    final out = <String>{};
    for (final r in records) {
      if (LasaEngine.normalize(r.name) != exNorm) {
        out.add(r.name);
      }
    }
    return out;
  }

  MedicineRecord? _findRecord(String query, {int? batchNum}) {
    MedicineRecord? bestRec;
    var bestScore = 0.0;

    for (final r in records) {
      if (batchNum != null && r.batchNum != batchNum) continue;

      final sName = Motion.fuzzyScore(query, r.displayName);
      final sBrand = Motion.fuzzyScore(query, r.brand);
      final sCat = Motion.fuzzyScore(query, r.category);
      final sLasa = Motion.fuzzyScore(query, r.lasaGroup);

      final s = math.max(math.max(sName, sBrand), math.max(sCat, sLasa));
      if (s >= 0.42 && s > bestScore) {
        bestScore = s;
        bestRec = r;
      }
    }
    return bestRec;
  }

  Future<void> _syncLasa(List<MedicineRecord> current) async {
    final enriched = LasaEngine.enrich(current);
    for (var i = 0; i < current.length; i++) {
      final orig = current[i];
      final next = enriched[i];
      if (orig.name != next.displayName ||
          orig.isLasa != next.isLasa ||
          orig.lasaGroup != next.lasaGroup) {
        await PbClient.updateMedicine(orig.id, {
          'name': next.displayName,
          'is_lasa': next.isLasa,
          'lasa_group': next.lasaGroup,
        });
      }
    }
  }

  void _fail() {
    hasError = true;
    hasSuccess = false;
    notifyListeners();
    onError();
    inputFocus.requestFocus();
  }

  void _succeed() {
    hasError = false;
    hasDispenseError = false;
    hasSuccess = true;
    notifyListeners();
    onSuccess();
  }

  // // Public API

  int get cabBatchCount {
    final cab = activeCabinet;
    if (cab == null) return 0;
    var count = 0;
    for (final r in records) {
      if (r.cabinet == cab.name) count++;
    }
    return count;
  }

  List<MedicineRecord> slotBatches(int slot) => _slotMap[slot] ?? const [];

  List<MedicineRecord> get currentBatches {
    if (selectedSlot == null) return const [];
    return _slotMap[selectedSlot!] ?? const [];
  }

  MedicineRecord? get activeBatch {
    final batches = currentBatches;
    if (batches.isEmpty) return null;
    final idx = selectedBatchIndex.clamp(0, batches.length - 1).toInt();
    return batches[idx];
  }

  int get nextBatchNum {
    var maxNum = 0;
    for (final b in currentBatches) {
      if (b.batchNum > maxNum) maxNum = b.batchNum;
    }
    return maxNum + 1;
  }

  bool get isDosageStep =>
      flow == PromptFlow.stockDosage || flow == PromptFlow.editDosage;

  bool get isConfirmingDelete =>
      flow == PromptFlow.confirmDeleteBatch || flow == PromptFlow.confirmDeleteCabinet;

  bool get canStepBack {
    switch (flow) {
      case PromptFlow.newCabinetGrid:
      case PromptFlow.stockBrand:
      case PromptFlow.stockCategory:
      case PromptFlow.stockDosage:
      case PromptFlow.stockQty:
      case PromptFlow.stockExpiry:
      case PromptFlow.addBatchExpiry:
      case PromptFlow.editBrand:
      case PromptFlow.editCategory:
      case PromptFlow.editDosage:
      case PromptFlow.editBatchExpiry:
        return true;
      default:
        return false;
    }
  }

  Iterable<String> get promptCandidates {
    final out = <String>{};
    switch (flow) {
      case PromptFlow.idle:
        final sorted = [...records]
          ..sort((a, b) => a.batchNum.compareTo(b.batchNum));
        for (final r in sorted) {
          if (r.displayName.isNotEmpty) {
            out.add(r.displayName);
            out.add('${r.displayName} ${r.batchNum}');
          }
          if (r.brand.isNotEmpty) out.add(r.brand);
          if (r.category.isNotEmpty) out.add(r.category);
          if (r.lasaGroup.isNotEmpty) out.add(r.lasaGroup);
        }
        break;
      case PromptFlow.stockName:
      case PromptFlow.editName:
        for (final r in records) {
          if (r.displayName.isNotEmpty) out.add(r.displayName);
        }
        break;
      case PromptFlow.stockBrand:
      case PromptFlow.editBrand:
        for (final r in records) {
          if (r.brand.isNotEmpty) out.add(r.brand);
        }
        break;
      case PromptFlow.stockCategory:
      case PromptFlow.editCategory:
        for (final r in records) {
          if (r.category.isNotEmpty) out.add(r.category);
        }
        break;
      default:
        break;
    }
    return out;
  }

  void stepBack() {
    if (!canStepBack) return;
    hasError = false;

    switch (flow) {
      case PromptFlow.newCabinetGrid:
        flow = PromptFlow.newCabinetName;
        _setInputText(draftCabName);
        break;
      case PromptFlow.stockBrand:
        flow = PromptFlow.stockName;
        _setInputText(draftMedName);
        break;
      case PromptFlow.stockCategory:
        flow = PromptFlow.stockBrand;
        _setInputText(draftBrand);
        break;
      case PromptFlow.stockDosage:
        flow = PromptFlow.stockCategory;
        _setInputText(draftCategory);
        break;
      case PromptFlow.stockQty:
        flow = PromptFlow.stockDosage;
        final (val, unit) = splitDosage(draftDosage);
        _setInputText(val);
        unitCtrl.text = unit;
        break;
      case PromptFlow.stockExpiry:
        flow = PromptFlow.stockQty;
        _setInputText(draftQty > 0 ? draftQty.toString() : '');
        break;
      case PromptFlow.addBatchExpiry:
        flow = PromptFlow.addBatchQty;
        _setInputText(draftQty > 0 ? draftQty.toString() : '');
        break;
      case PromptFlow.editBrand:
        flow = PromptFlow.editName;
        _setInputText(draftMedName);
        break;
      case PromptFlow.editCategory:
        flow = PromptFlow.editBrand;
        _setInputText(draftBrand);
        break;
      case PromptFlow.editDosage:
        flow = PromptFlow.editCategory;
        _setInputText(draftCategory);
        break;
      case PromptFlow.editBatchExpiry:
        flow = PromptFlow.editBatchQty;
        _setInputText(draftQty.toString());
        break;
      default:
        break;
    }

    notifyListeners();
    inputFocus.requestFocus();
  }

  void clearError() {
    if (!hasError) return;
    hasError = false;
    notifyListeners();
  }

  void clearDispenseError() {
    if (!hasDispenseError) return;
    hasDispenseError = false;
    notifyListeners();
  }

  Future<void> sync({bool reconcileLasa = false}) async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      final cabs = await PbClient.getCabinets();
      var meds = await PbClient.getMedicines();
      if (reconcileLasa) {
        await _syncLasa(meds);
        meds = await PbClient.getMedicines();
      }
      cabinets = cabs;
      records = meds;
      isLoading = false;
      isOffline = false;

      if (cabinets.isNotEmpty) {
        final prevId = activeCabinet?.id;
        CabinetRecord? match;
        for (final c in cabinets) {
          if (c.id == prevId) {
            match = c;
            break;
          }
        }
        activeCabinet = match ?? cabinets.first;
      } else {
        activeCabinet = null;
      }

      _rebuildSlots();

      final batches = currentBatches;
      if (selectedBatchIndex >= batches.length) {
        selectedBatchIndex = math.max(0, batches.length - 1);
      }
      notifyListeners();
    } catch (_) {
      isLoading = false;
      isOffline = true;
      hasError = true;
      flow = PromptFlow.idle;
      selectedSlot = null;
      _slotMap = const {};
      notifyListeners();
      onError();
    }
  }

  void selectCabinet(CabinetRecord cab) {
    if (isOffline) return;
    if (activeCabinet?.id == cab.id && flow == PromptFlow.idle && selectedSlot == null) {
      return;
    }
    inputFocus.unfocus();
    unitFocus.unfocus();
    dispenseFocus.unfocus();
    activeCabinet = cab;
    selectedSlot = null;
    selectedBatchIndex = 0;
    flow = PromptFlow.idle;
    dispenseCtrl.clear();
    hasDispenseError = false;
    hasError = false;
    _rebuildSlots();
    notifyListeners();
  }

  void selectBatch(int index) {
    selectedBatchIndex = index;
    if (isConfirmingDelete) flow = PromptFlow.idle;
    notifyListeners();
  }

  void deselect() {
    inputFocus.unfocus();
    unitFocus.unfocus();
    dispenseFocus.unfocus();
    flow = PromptFlow.idle;
    selectedSlot = null;
    selectedBatchIndex = 0;
    inputCtrl.clear();
    dispenseCtrl.clear();
    unitCtrl.text = 'mg';
    hasError = false;
    hasDispenseError = false;
    notifyListeners();
  }

  void selectSlot(int slot) {
    if (isOffline) return;
    inputFocus.unfocus();
    unitFocus.unfocus();
    selectedSlot = slot;
    selectedBatchIndex = 0;
    flow = PromptFlow.idle;
    inputCtrl.clear();
    dispenseCtrl.clear();
    hasError = false;
    hasDispenseError = false;
    notifyListeners();
  }

  void startAddCabinet() {
    if (isOffline) {
      sync();
      return;
    }
    selectedSlot = null;
    flow = PromptFlow.newCabinetName;
    inputCtrl.clear();
    hasError = false;
    notifyListeners();
    inputFocus.requestFocus();
  }

  void startStockSlot(int slot) {
    if (isOffline) {
      sync();
      return;
    }
    if (activeCabinet == null) {
      startAddCabinet();
      return;
    }
    selectedSlot = slot;
    selectedBatchIndex = 0;
    draftMedName = '';
    draftBrand = '';
    draftCategory = '';
    draftDosage = '';
    draftQty = 0;
    flow = PromptFlow.stockName;
    inputCtrl.clear();
    unitCtrl.text = 'mg';
    hasError = false;
    notifyListeners();
    inputFocus.requestFocus();
  }

  void startAddBatch() {
    if (isOffline) return;
    final batches = currentBatches;
    if (batches.isEmpty || activeCabinet == null) return;
    final first = batches.first;
    draftMedName = first.displayName;
    draftBrand = first.brand;
    draftCategory = first.category;
    draftDosage = first.dosage;
    flow = PromptFlow.addBatchQty;
    inputCtrl.clear();
    hasError = false;
    notifyListeners();
    inputFocus.requestFocus();
  }

  void startEditBatch() {
    if (isOffline) return;
    final target = activeBatch;
    if (target == null) return;
    draftMedName = target.displayName;
    draftBrand = target.brand;
    draftCategory = target.category;
    draftDosage = target.dosage;
    draftQty = target.stock;
    flow = PromptFlow.editBatchQty;
    _setInputText(target.stock.toString());
    hasError = false;
    notifyListeners();
    inputFocus.requestFocus();
  }

  void startRename() {
    if (isOffline) return;
    final batches = currentBatches;
    if (batches.isEmpty) return;
    final first = batches.first;
    draftMedName = first.displayName;
    draftBrand = first.brand;
    draftCategory = first.category;
    draftDosage = first.dosage;
    flow = PromptFlow.editName;
    _setInputText(first.displayName);
    hasError = false;
    notifyListeners();
    inputFocus.requestFocus();
  }

  void promptDeleteBatch() {
    if (isOffline || activeBatch == null) return;
    inputFocus.unfocus();
    unitFocus.unfocus();
    dispenseFocus.unfocus();
    inputCtrl.clear();
    hasError = false;
    flow = PromptFlow.confirmDeleteBatch;
    notifyListeners();
  }

  void promptDeleteCabinet() {
    if (isOffline || activeCabinet == null) return;
    inputFocus.unfocus();
    unitFocus.unfocus();
    dispenseFocus.unfocus();
    inputCtrl.clear();
    hasError = false;
    flow = PromptFlow.confirmDeleteCabinet;
    notifyListeners();
  }

  void cancelDelete() {
    inputCtrl.clear();
    inputFocus.unfocus();
    hasError = false;
    flow = PromptFlow.idle;
    notifyListeners();
  }

  Future<void> confirmDelete() async {
    if (flow == PromptFlow.confirmDeleteCabinet) {
      await deleteCabinet();
    } else if (flow == PromptFlow.confirmDeleteBatch) {
      await deleteBatch();
    }
  }

  Future<void> adjustStock(MedicineRecord batch, int delta) async {
    if (isOffline) return;
    final next = batch.stock + delta;
    if (next <= 0) {
      final idx = currentBatches.indexWhere((b) => b.id == batch.id);
      if (idx != -1) selectedBatchIndex = idx;
      promptDeleteBatch();
      return;
    }
    try {
      await PbClient.updateStock(batch.id, next);
      await sync();
      if (currentBatches.isEmpty) {
        selectedSlot = null;
        flow = PromptFlow.idle;
      }
      _succeed();
    } catch (_) {
      _fail();
    }
  }

  Future<void> deleteCabinet() async {
    if (isOffline) return;
    final cab = activeCabinet;
    if (cab == null) return;
    try {
      for (final m in records) {
        if (m.cabinet == cab.name) {
          await PbClient.deleteMedicine(m.id);
        }
      }
      await PbClient.deleteCabinet(cab.id);
      activeCabinet = null;
      selectedSlot = null;
      flow = PromptFlow.idle;
      inputCtrl.clear();
      await sync(reconcileLasa: true);
      _succeed();
    } catch (_) {
      _fail();
    }
  }

  Future<void> deleteBatch() async {
    if (isOffline) return;
    final target = activeBatch;
    if (target == null) return;
    try {
      await PbClient.deleteMedicine(target.id);
      flow = PromptFlow.idle;
      inputCtrl.clear();
      await sync(reconcileLasa: true);
      if (currentBatches.isEmpty) {
        selectedSlot = null;
        selectedBatchIndex = 0;
      }
      _succeed();
    } catch (_) {
      _fail();
    }
  }

  Future<void> submitDispense() async {
    if (isOffline) return;
    final raw = dispenseCtrl.text.trim();
    final qty = int.tryParse(raw);
    if (qty == null || qty <= 0) {
      hasDispenseError = true;
      notifyListeners();
      dispenseFocus.requestFocus();
      return;
    }
    await dispenseFromSlot(qty);
  }

  Future<void> dispenseFromSlot(int qty) async {
    if (isOffline) return;
    final batches = currentBatches;
    if (batches.isEmpty || qty <= 0) {
      hasDispenseError = true;
      notifyListeners();
      return;
    }

    var rem = qty;
    try {
      for (final b in batches) {
        if (rem <= 0) break;
        if (b.stock <= rem) {
          rem -= b.stock;
          await PbClient.deleteMedicine(b.id);
        } else {
          await PbClient.updateStock(b.id, b.stock - rem);
          rem = 0;
        }
      }
      dispenseCtrl.clear();
      dispenseFocus.unfocus();
      await sync(reconcileLasa: true);
      flow = PromptFlow.idle;
      if (currentBatches.isEmpty) selectedSlot = null;
      _succeed();
    } catch (_) {
      hasDispenseError = true;
      notifyListeners();
    }
  }

  Future<void> submitCommand() async {
    if (isOffline) {
      await sync();
      return;
    }
    if (isConfirmingDelete) return;

    final raw = inputCtrl.text.trim();
    final optionalStep = flow == PromptFlow.stockBrand ||
        flow == PromptFlow.stockCategory ||
        flow == PromptFlow.editBrand ||
        flow == PromptFlow.editCategory;

    if (raw.isEmpty && !optionalStep) return;

    switch (flow) {
      case PromptFlow.newCabinetName:
        draftCabName = raw.toUpperCase();
        inputCtrl.clear();
        flow = PromptFlow.newCabinetGrid;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.newCabinetGrid:
        final parts = raw.toLowerCase().split(RegExp(r'[x\s,*]+'));
        final r = int.tryParse(parts[0]);
        final c = parts.length > 1 ? int.tryParse(parts[1]) : 4;
        if (r == null || c == null || r < 1 || c < 1) {
          _fail();
          return;
        }
        try {
          final created = await PbClient.createCabinet(
            name: draftCabName,
            rows: r,
            cols: c,
          );
          inputCtrl.clear();
          inputFocus.unfocus();
          activeCabinet = created;
          await sync();
          selectedSlot = null;
          flow = PromptFlow.idle;
          _succeed();
        } catch (_) {
          _fail();
        }
        break;

      case PromptFlow.stockName:
        final eval = LasaEngine.evaluate(raw, _otherNames(exclude: raw));
        draftMedName = eval.displayName;
        inputCtrl.clear();
        flow = PromptFlow.stockBrand;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.stockBrand:
        draftBrand = raw;
        inputCtrl.clear();
        flow = PromptFlow.stockCategory;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.stockCategory:
        draftCategory = raw;
        inputCtrl.clear();
        unitCtrl.text = 'mg';
        flow = PromptFlow.stockDosage;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.stockDosage:
        draftDosage = combineDosage(raw, unitCtrl.text);
        inputCtrl.clear();
        flow = PromptFlow.stockQty;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.stockQty:
      case PromptFlow.addBatchQty:
        final qty = int.tryParse(raw);
        if (qty == null || qty <= 0) {
          _fail();
          return;
        }
        draftQty = qty;
        inputCtrl.clear();
        flow = flow == PromptFlow.stockQty
            ? PromptFlow.stockExpiry
            : PromptFlow.addBatchExpiry;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.stockExpiry:
      case PromptFlow.addBatchExpiry:
        final exp = ExpiryParser.parse(raw);
        if (exp == null || activeCabinet == null || selectedSlot == null) {
          _fail();
          return;
        }
        try {
          final num = nextBatchNum;
          final code = 'BATCH-${num.toString().padLeft(2, '0')}';
          final eval = LasaEngine.evaluate(
            draftMedName,
            _otherNames(exclude: draftMedName),
          );

          await PbClient.createMedicine({
            'name': eval.displayName,
            'brand': draftBrand,
            'category': draftCategory,
            'dosage': draftDosage,
            'cabinet': activeCabinet!.name,
            'slot': selectedSlot!,
            'stock': draftQty,
            'batch': code,
            'expiry': exp.toIso8601String(),
            'is_lasa': eval.isLasa,
            'lasa_group': eval.counterpart,
          });
          inputCtrl.clear();
          inputFocus.unfocus();
          unitFocus.unfocus();
          await sync(reconcileLasa: true);
          flow = PromptFlow.idle;
          selectedBatchIndex = math.max(0, currentBatches.length - 1);
          _succeed();
        } catch (_) {
          _fail();
        }
        break;

      case PromptFlow.editName:
        final batches = currentBatches;
        if (batches.isEmpty) return;
        final eval = LasaEngine.evaluate(
          raw,
          _otherNames(exclude: batches.first.name),
        );
        draftMedName = eval.displayName;
        _setInputText(draftBrand);
        flow = PromptFlow.editBrand;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.editBrand:
        draftBrand = raw;
        _setInputText(draftCategory);
        flow = PromptFlow.editCategory;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.editCategory:
        final batches = currentBatches;
        if (batches.isEmpty) return;
        draftCategory = raw;
        final (valPart, unitPart) = splitDosage(batches.first.dosage);
        _setInputText(valPart);
        unitCtrl.text = unitPart;
        flow = PromptFlow.editDosage;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.editDosage:
        final batches = currentBatches;
        if (batches.isEmpty) return;
        draftDosage = combineDosage(raw, unitCtrl.text);
        try {
          final eval = LasaEngine.evaluate(
            draftMedName,
            _otherNames(exclude: batches.first.name),
          );
          for (final b in batches) {
            await PbClient.updateMedicine(b.id, {
              'name': eval.displayName,
              'brand': draftBrand,
              'category': draftCategory,
              'dosage': draftDosage,
              'is_lasa': eval.isLasa,
              'lasa_group': eval.counterpart,
            });
          }
          inputCtrl.clear();
          inputFocus.unfocus();
          unitFocus.unfocus();
          await sync(reconcileLasa: true);
          flow = PromptFlow.idle;
          _succeed();
        } catch (_) {
          _fail();
        }
        break;

      case PromptFlow.editBatchQty:
        final target = activeBatch;
        if (target == null) return;
        final qty = int.tryParse(raw);
        if (qty == null || qty <= 0) {
          _fail();
          return;
        }
        draftQty = qty;
        _setInputText(ExpiryParser.monthYear(target.expiry));
        flow = PromptFlow.editBatchExpiry;
        notifyListeners();
        inputFocus.requestFocus();
        break;

      case PromptFlow.editBatchExpiry:
        final target = activeBatch;
        final exp = ExpiryParser.parse(raw);
        if (target == null || exp == null) {
          _fail();
          return;
        }
        try {
          await PbClient.updateMedicine(target.id, {
            'stock': draftQty,
            'expiry': exp.toIso8601String(),
          });
          inputCtrl.clear();
          inputFocus.unfocus();
          unitFocus.unfocus();
          await sync();
          flow = PromptFlow.idle;
          _succeed();
        } catch (_) {
          _fail();
        }
        break;

      case PromptFlow.confirmDeleteBatch:
      case PromptFlow.confirmDeleteCabinet:
        break;

      case PromptFlow.idle:
        final match = RegExp(r'^(.*?)\s+#?(\d+)$').firstMatch(raw);
        final query = match != null ? match.group(1)!.trim() : raw;
        final batchTarget = match != null ? int.tryParse(match.group(2)!) : null;

        var bestRec = _findRecord(query, batchNum: batchTarget);
        var usedBatchTarget = batchTarget != null && bestRec != null;

        if (bestRec == null && batchTarget != null) {
          bestRec = _findRecord(raw);
        }

        if (bestRec != null) {
          inputCtrl.clear();
          inputFocus.unfocus();

          for (final c in cabinets) {
            if (c.name == bestRec.cabinet) {
              activeCabinet = c;
              _rebuildSlots();
              break;
            }
          }

          selectedSlot = bestRec.slot;
          if (usedBatchTarget) {
            final slotList = slotBatches(bestRec.slot);
            final idx = slotList.indexWhere((b) => b.id == bestRec!.id);
            selectedBatchIndex = idx != -1 ? idx : 0;
          } else {
            selectedBatchIndex = 0;
          }
          _succeed();
          return;
        }
        _fail();
        break;
    }
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// // Types

enum PromptFlow {
  idle,
  newCabinetName,
  newCabinetGrid,
  stockName,
  stockBrand,
  stockCategory,
  stockDosage,
  stockQty,
  stockExpiry,
  addBatchQty,
  addBatchExpiry,
  editName,
  editBrand,
  editCategory,
  editDosage,
  editBatchQty,
  editBatchExpiry,
  confirmDeleteBatch,
  confirmDeleteCabinet,
}
