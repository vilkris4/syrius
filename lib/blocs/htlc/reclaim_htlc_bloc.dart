import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ReclaimHtlcBloc extends BaseBloc<AccountBlockTemplate?> {
  void reclaimHtlc({
    required Hash id,
    required Address? sender,
  }) {
    try {
      addEvent(null);
      AccountBlockTemplate transactionParams = zenon!.embedded.htlc.reclaim(id);
      KeyPair blockSigningKeyPair = kKeyStore!.getKeyPair(
        kDefaultAddressList.indexOf(sender.toString()),
      );
      AccountBlockUtils.createAccountBlock(transactionParams, 'reclaim swap',
          blockSigningKey: blockSigningKeyPair,
          waitForRequiredPlasma: true)
          .then(
        (response) {
          AddressUtils.refreshBalance();
          addEvent(response);
        },
      ).onError(
        (error, stackTrace) {
          addError(error.toString());
        },
      );
    } catch (e) {
      addError(e);
    }
  }
}
