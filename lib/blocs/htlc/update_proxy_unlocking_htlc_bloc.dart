import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class UpdateProxyUnlockingHtlcBloc extends BaseBloc<AccountBlockTemplate?> {
  void updateProxy({
    required Address? address,
    required bool allowed,
  }) {
    try {
      addEvent(null);
      AccountBlockTemplate transactionParams = allowed
          ? zenon!.embedded.htlc.allowProxy()
          : zenon!.embedded.htlc.denyProxy();
      KeyPair blockSigningKeyPair = kKeyStore!.getKeyPair(
        kDefaultAddressList.indexOf(address.toString()),
      );
      AccountBlockUtils.createAccountBlock(transactionParams,
              '${allowed ? 'allow' : 'deny'} proxy unlocking',
              blockSigningKey: blockSigningKeyPair, waitForRequiredPlasma: true)
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
