import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class RetrieveHtlcBloc extends BaseBloc<HtlcInfo?> {
  Future<void> getHtlcInfo(Hash id) async {
    try {
      HtlcInfo htlcInfo = await zenon!.embedded.htlc.getById(id);
      if (_isSwapExpired(htlcInfo)) {
        throw 'HTLC has expired';
      }
      if (_isIncomingDeposit(htlcInfo) ||
          await _canProxyUnlock(htlcInfo.timeLocked)) {
        throw 'HTLC cannot be unlocked';
      }
      addEvent(htlcInfo);
    } catch (e) {
      addError(e);
    }
  }

  bool _isSwapExpired(HtlcInfo htlcInfo) {
    final remaining = htlcInfo.expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining <= 0;
  }

  bool _isIncomingDeposit(HtlcInfo htlcInfo) {
    return kDefaultAddressList.contains(htlcInfo.hashLocked.toString());
  }

  Future<bool> _canProxyUnlock(Address address) async {
    return await zenon!.embedded.htlc.getProxyUnlockStatus(address);
  }
}
