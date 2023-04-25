import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';

class HtlcSwapBloc extends BaseBloc<HtlcSwap> {
  final String swapId;
  Timer? _timer;

  HtlcSwapBloc(this.swapId);

  Future<void> getDataPeriodically() async {
    try {
      _timer = makePeriodicCall(const Duration(seconds: 5), (Timer t) async {
        final swap = htlcSwapsService!.getSwapById(swapId);
        if (swap != null) {
          addEvent(swap);
        } else {
          throw 'Swap does not exist';
        }
      });
    } catch (e) {
      addError(e);
    }
  }

  @override
  dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Timer makePeriodicCall(
      Duration duration, void Function(Timer timer) callback) {
    final timer = Timer.periodic(duration, callback);
    callback(timer);
    return timer;
  }
}
