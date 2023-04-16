import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

class P2pSwapsListBloc extends BaseBloc<List<P2pSwap>> {
  P2pSwapsListBloc() {
    getSwaps();
  }

  Future<void> getSwaps() async {
    try {
      await _openBox();
      final swaps = Hive.box(kP2pSwapsBox)
          .values
          .map((e) => P2pSwap.fromJson(jsonDecode(e)))
          .toList();
      swaps.sort((a, b) => b.startTime.compareTo(a.startTime));
      addEvent(swaps);
    } catch (e) {
      addError(e);
    }
  }

  Future<void> _openBox() async {
    if (!Hive.isBoxOpen(kP2pSwapsBox)) {
      await Hive.openBox(kP2pSwapsBox,
          encryptionCipher:
              HiveAesCipher((kKeyStore!.getKeyPair(0).getPrivateKey())!));
    }
  }
}
