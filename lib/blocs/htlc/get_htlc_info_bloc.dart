import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc_with_refresh_mixin.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class GetHtlcInfoBloc extends BaseBlocWithRefreshMixin<HtlcInfo?> {
  final String htlcId;
  GetHtlcInfoBloc(this.htlcId);

  @override
  Future<HtlcInfo?> getDataAsync() {
    if (htlcId.isEmpty) {
      throw 'Empty HTLC ID';
    }
    return zenon!.embedded.htlc.getById(Hash.parse(htlcId));
  }
}
