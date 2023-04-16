import 'dart:convert';

import 'package:znn_sdk_dart/znn_sdk_dart.dart';

enum P2pSwapType {
  native,
  crosschain,
}

enum P2pSwapMode {
  htlc,
}

enum P2pSwapState {
  pending,
  active,
  completed,
  reclaimable,
  unsuccessful,
}

enum P2pSwapDirection {
  outgoing,
  incoming,
}

class P2pSwap {
  final String id;
  final P2pSwapType type;
  final P2pSwapMode mode;
  final P2pSwapDirection direction;
  final int startTime;
  final int expirationTime;
  final int fromAmount;
  final Token fromToken;
  final String selfAddress;
  final String counterpartyAddress;
  P2pSwapState state;
  int toAmount;
  Token? toToken;

  P2pSwap(
      {required this.id,
      required this.type,
      required this.mode,
      required this.direction,
      required this.state,
      required this.startTime,
      required this.expirationTime,
      required this.fromAmount,
      required this.toAmount,
      required this.fromToken,
      required this.selfAddress,
      required this.counterpartyAddress,
      this.toToken});

  P2pSwap.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        type = P2pSwapType.values.byName(json['type']),
        mode = P2pSwapMode.values.byName(json['mode']),
        direction = P2pSwapDirection.values.byName(json['direction']),
        state = P2pSwapState.values.byName(json['state']),
        startTime = json['startTime'],
        expirationTime = json['expirationTime'],
        fromAmount = json['fromAmount'],
        toAmount = json['toAmount'],
        fromToken = Token.fromJson(jsonDecode(json['fromToken'])),
        toToken = json['toToken'].isEmpty
            ? null
            : Token.fromJson(jsonDecode(json['toToken'])),
        selfAddress = json['selfAddress'],
        counterpartyAddress = json['counterpartyAddress'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'mode': mode.name,
        'direction': direction.name,
        'state': state.name,
        'startTime': startTime,
        'expirationTime': expirationTime,
        'fromAmount': fromAmount,
        'toAmount': toAmount,
        'selfAddress': selfAddress,
        'counterpartyAddress': counterpartyAddress,
        'fromToken': jsonEncode(fromToken.toJson()),
        'toToken': toToken != null ? jsonEncode(toToken!.toJson()) : ''
      };
}
