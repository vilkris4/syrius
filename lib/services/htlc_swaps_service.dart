import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

class HtlcSwapsService {
  static Box? _htlcSwapsBox;
  static Box? _lastCheckedHtlcBlockHeightBox;

  static HtlcSwapsService? _instance;

  static HtlcSwapsService getInstance() {
    _instance ??= HtlcSwapsService();
    return _instance!;
  }

  Future<void> openBoxes(List<int> cipherKey) async {
    if (_htlcSwapsBox == null || !_htlcSwapsBox!.isOpen) {
      _htlcSwapsBox = await Hive.openBox(kHtlcSwapsBox,
          encryptionCipher: HiveAesCipher(cipherKey));
    }

    if (_lastCheckedHtlcBlockHeightBox == null ||
        !_lastCheckedHtlcBlockHeightBox!.isOpen) {
      _lastCheckedHtlcBlockHeightBox = await Hive.openBox(
          kLastCheckedHtlcBlockBox,
          encryptionCipher: HiveAesCipher(cipherKey));
    }
  }

  List<HtlcSwap> getAllSwaps() {
    final swaps = _htlcSwapsBox!.values
        .map((e) => HtlcSwap.fromJson(jsonDecode(e)))
        .toList();
    return swaps;
  }

  List<HtlcSwap> getPendingAndActiveSwaps() {
    return _htlcSwapsBox!.values
        .where((e) => [P2pSwapState.pending, P2pSwapState.active]
            .contains(HtlcSwap.fromJson(jsonDecode(e)).state))
        .map((e) => HtlcSwap.fromJson(jsonDecode(e)))
        .toList();
  }

  HtlcSwap? getSwapByHashLock(String hashLock) {
    try {
      final swap = _htlcSwapsBox!.values.firstWhereOrNull(
          (e) => HtlcSwap.fromJson(jsonDecode(e)).hashLock == hashLock);
      return swap != null ? HtlcSwap.fromJson(jsonDecode(swap)) : null;
    } on HiveError {
      return null;
    }
  }

  HtlcSwap? getSwapByCounterHtlcId(String htlcId) {
    try {
      final swap = _htlcSwapsBox!.values.firstWhereOrNull(
          (e) => HtlcSwap.fromJson(jsonDecode(e)).counterHtlcId == htlcId);
      return swap != null ? HtlcSwap.fromJson(jsonDecode(swap)) : null;
    } on HiveError {
      return null;
    }
  }

  HtlcSwap? getSwapById(String id) {
    try {
      final swap = _htlcSwapsBox!.values
          .firstWhereOrNull((e) => HtlcSwap.fromJson(jsonDecode(e)).id == id);
      return swap != null ? HtlcSwap.fromJson(jsonDecode(swap)) : null;
    } on HiveError {
      return null;
    }
  }

  int getLastCheckedHtlcBlockHeight() {
    return _lastCheckedHtlcBlockHeightBox!
        .get(kLastCheckedHtlcBlockKey, defaultValue: 0);
  }

  Future<void> storeSwap(HtlcSwap swap) async => await _htlcSwapsBox!.put(
        swap.id,
        jsonEncode(swap.toJson()),
      );

  Future<void> storeLastCheckedHtlcBlockHeight(int height) async =>
      await _lastCheckedHtlcBlockHeightBox!
          .put(kLastCheckedHtlcBlockKey, height);

  Future<void> deleteSwap(String swapId) async =>
      await _htlcSwapsBox!.delete(swapId);
}
