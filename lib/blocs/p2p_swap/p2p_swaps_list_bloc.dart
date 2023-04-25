import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';

class P2pSwapsListBloc extends BaseBloc<List<P2pSwap>> {
  Timer? _timer;

  Future<void> getDataPeriodically() async {
    try {
      _timer = makePeriodicCall(const Duration(seconds: 5), (Timer t) async {
        await getSwaps();
      });
    } catch (e) {
      addError(e);
    }
  }

  Future<void> getSwaps() async {
    try {
      final swaps = htlcSwapsService!.getAllSwaps();
      swaps.sort((a, b) => b.startTime.compareTo(a.startTime));
      addEvent(swaps);
    } catch (e) {
      addError(e);
    }
  }

  Timer makePeriodicCall(
      Duration duration, void Function(Timer timer) callback) {
    final timer = Timer.periodic(duration, callback);
    callback(timer);
    return timer;
  }

  @override
  dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
