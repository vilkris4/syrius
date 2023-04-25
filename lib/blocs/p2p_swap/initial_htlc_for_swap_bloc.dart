import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class InitialHtlcForSwapBloc extends BaseBloc<HtlcInfo?> {
  final _minimumRequiredDuration = const Duration(hours: 1);
  Future<void> getInitialHtlc(Hash id) async {
    try {
      final htlc = await zenon!.embedded.htlc.getById(id);
      if (!kDefaultAddressList.contains(htlc.hashLocked.toString())) {
        throw 'This deposit is not intended for you.';
      }
      if (kDefaultAddressList.contains(htlc.timeLocked.toString())) {
        throw 'Cannot join a swap that you have started.';
      }
      final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final remainingDuration = Duration(seconds: htlc.expirationTime - now);
      if (remainingDuration < _minimumRequiredDuration) {
        throw 'This deposit will expire too soon for a safe swap.';
      }
      addEvent(htlc);
    } catch (e) {
      addError(e);
    }
  }
}
