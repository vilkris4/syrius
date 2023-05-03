import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

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
    return _swapsForCurrentChainId;
  }

  List<HtlcSwap> getSwapsByState(List<P2pSwapState> states) {
    return _swapsForCurrentChainId
        .where((e) => states.contains(e.state))
        .toList();
  }

  HtlcSwap? getSwapByHashLock(String hashLock) {
    try {
      return _swapsForCurrentChainId
          .firstWhereOrNull((e) => e.hashLock == hashLock);
    } on HiveError {
      return null;
    }
  }

  HtlcSwap? getSwapByHtlcId(String htlcId) {
    try {
      return _swapsForCurrentChainId.firstWhereOrNull(
          (e) => e.initialHtlcId == htlcId || e.counterHtlcId == htlcId);
    } on HiveError {
      return null;
    }
  }

  HtlcSwap? getSwapById(String id) {
    try {
      return _swapsForCurrentChainId.firstWhereOrNull((e) => e.id == id);
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

  List<HtlcSwap> get _swapsForCurrentChainId {
    return kNodeChainId != null
        ? _htlcSwapsBox!.values
            .where(
                (e) => HtlcSwap.fromJson(jsonDecode(e)).chainId == kNodeChainId)
            .map((e) => HtlcSwap.fromJson(jsonDecode(e)))
            .toList()
        : [];
  }
}
