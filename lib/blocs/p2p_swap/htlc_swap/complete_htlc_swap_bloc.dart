import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class CompleteHtlcSwapBloc extends BaseBloc<HtlcSwap?> {
  void completeHtlcSwap({
    required HtlcSwap swap,
  }) {
    try {
      addEvent(null);
      final htlcId = swap.direction == P2pSwapDirection.outgoing
          ? swap.counterHtlcId!
          : swap.initialHtlcId;
      AccountBlockTemplate transactionParams = zenon!.embedded.htlc.unlock(
          Hash.parse(htlcId), FormatUtils.decodeHexString(swap.preimage!));
      KeyPair blockSigningKeyPair = kKeyStore!.getKeyPair(
        kDefaultAddressList.indexOf(swap.selfAddress.toString()),
      );
      AccountBlockUtils.createAccountBlock(transactionParams, 'complete swap',
              blockSigningKey: blockSigningKeyPair, waitForRequiredPlasma: true)
          .then(
        (response) async {
          swap.state = P2pSwapState.completed;
          await htlcSwapsService!.storeSwap(swap);
          AddressUtils.refreshBalance();
          addEvent(swap);
        },
      ).onError(
        (error, stackTrace) {
          addError(error.toString(), stackTrace);
        },
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }
}
