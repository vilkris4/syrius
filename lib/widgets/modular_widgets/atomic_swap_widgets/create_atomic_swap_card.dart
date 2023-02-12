//TODO:
// Confirm CardScaffold description
// Remove pending swap when creation fails
// Save encrypted preimage

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/create_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/loading_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/deposit_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/addresses_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/hash_type_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/lock_duration_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/hashlock_suffix_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class CreateAtomicSwapCard extends StatefulWidget {
  const CreateAtomicSwapCard({
    Key? key,
  }) : super(key: key);

  @override
  State<CreateAtomicSwapCard> createState() => _CreateAtomicSwapCardState();
}

class _CreateAtomicSwapCardState extends State<CreateAtomicSwapCard> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _evmAddressController = TextEditingController();
  final TextEditingController _hashlockController = TextEditingController();

  final GlobalKey<FormState> _recipientKey = GlobalKey();
  final GlobalKey<FormState> _hashlockKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _createAtomicSwapButtonKey = GlobalKey();

  final CreateHtlcBloc _createHtlcBloc = CreateHtlcBloc();

  String? _selectedSelfAddress = kSelectedAddress;
  String? _selectedLockDuration = kLockDurations[1];
  String? _selectedHashType = kHashTypes.first;
  Token _selectedToken = kDualCoin.first;
  List<int> preimage = [];
  bool _amountIsValid = false;
  int? expirationTime;

  @override
  void initState() {
    super.initState();
    sl.get<BalanceBloc>().getBalanceForAllAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold(
      title: '  Create Atomic Swap',
      description: 'Create an atomic swap on the Zenon Network of Momentum.'
          'The swap must be unlocked before the expiration time in order for the'
          'recipient to receive the funds. If two or more parties use the same '
          'hashlock, all active swaps using the hashlock may be unlocked '
          'simultaneously. By default, the hashlock is a 32-byte random value and '
          'users should treat it like a password. If the hashlock is lost, '
          'participants must wait until the swap has expired in order to reclaim '
          'their funds.',
      childBuilder: () => _getWidgetBody(context),
    );
  }

  Widget _getWidgetBody(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          _getInputFields(),
          Visibility(
              visible: preimage.isNotEmpty,
              child: Column(children: [
                kVerticalSpacing,
                _generatePreimageBox(),
              ])),
          kVerticalSpacing,
          _getCreateAtomicSwapViewModel(),
        ],
      ),
    );
  }

  Column _getInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AddressesDropdown(
          _selectedSelfAddress,
          (address) => setState(() {
            _selectedSelfAddress = address;
            sl.get<BalanceBloc>().getBalanceForAllAddresses();
          }),
        ),
        kVerticalSpacing,
        StreamBuilder<Map<String, AccountInfo>?>(
          stream: sl.get<BalanceBloc>().stream,
          builder: (_, snapshot) {
            if (snapshot.hasData) {
              return AmountInputField(
                controller: _amountController,
                accountInfo: (snapshot.data![_selectedSelfAddress]!),
                valuePadding: 20.0,
                textColor: Theme.of(context).colorScheme.inverseSurface,
                initialToken: _selectedToken,
                onChanged: (token, isValid) {
                  setState(() {
                    _selectedToken = token;
                    _amountIsValid = isValid;
                  });
                },
              );
            }
            if (snapshot.hasError) {
              return SyriusErrorWidget(snapshot.error!);
            }
            return const SyriusLoadingWidget();
          },
        ),
        kVerticalSpacing,
        Form(
          key: _recipientKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: InputField(
            onChanged: (value) {
              setState(() {});
            },
            validator: (value) => InputValidators.checkAddress(value),
            controller: _recipientController,
            suffixIcon: RawMaterialButton(
              child: const Icon(
                Icons.content_paste,
                color: AppColors.darkHintTextColor,
                size: 15.0,
              ),
              shape: const CircleBorder(),
              onPressed: () {
                ClipboardUtils.pasteToClipboard(context, (String value) {
                  _recipientController.text = value;
                  setState(() {});
                });
              },
            ),
            suffixIconConstraints: const BoxConstraints(
              maxWidth: 45.0,
              maxHeight: 20.0,
            ),
            hintText: 'Recipient address (counterparty)',
          ),
        ),
        kVerticalSpacing,
        LockDurationDropdown(
          _selectedLockDuration,
          (duration) => setState(() {
            _selectedLockDuration =
                (duration != null) ? duration : kLockDurations[1];
          }),
        ),
        kVerticalSpacing,
        HashTypeDropdown(
          _selectedHashType,
          (hashType) => setState(() {
            _selectedHashType =
                (hashType != null) ? hashType : kHashTypes.first;
            _onGeneratePressed(_selectedHashType, context, (String value) {
              _hashlockController.text = value;
              setState(() {});
            });
          }),
        ),
        kVerticalSpacing,
        Form(
          key: _hashlockKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: InputField(
            onChanged: (value) {
              setState(() {});
            },
            validator: (value) => InputValidators.checkHash(value),
            controller: _hashlockController,
            suffixIcon: _getHashlockSuffix(),
            suffixIconConstraints: const BoxConstraints(),
            hintText: 'Hashlock',
          ),
        ),
      ],
    );
  }

  Widget _generatePreimageBox() {
    return Row(children: [
      Flexible(
        fit: FlexFit.tight,
        child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              border: Border.all(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(7.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Text(
                      'Copy and save this secret. You will need it to unlock the counter deposit.',
                      style: Theme.of(context).textTheme.subtitle1,
                      textScaleFactor: 1.2),
                ),
                Padding(
                    padding: const EdgeInsets.only(bottom: 15.0, left: 15.0),
                    child: Row(children: [
                      Text(
                        FormatUtils.formatLongString(
                            FormatUtils.encodeHexString(preimage)),
                        style: Theme.of(context).textTheme.bodyText2,
                        textScaleFactor: 1.2,
                      ),
                      CopyToClipboardIcon(
                        FormatUtils.encodeHexString(preimage),
                        iconColor: AppColors.darkHintTextColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]))
              ],
            )),
      )
    ]);
  }

  Widget _getHashlockSuffix() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        HashlockSuffixGenerateWidget(
          onPressed: () => {
            _onGeneratePressed(_selectedHashType, context, (String value) {
              _hashlockController.text = value;
              setState(() {});
            })
          },
          context: context,
        ),
        HashlockSuffixClipboardWidget(
          onPressed: () => {
            ClipboardUtils.pasteToClipboard(context, (String value) {
              _hashlockController.text = value;
              preimage = [];
              setState(() {});
            })
          },
          context: context,
        ),
      ],
    );
  }

  void _onGeneratePressed(
      String? hashType, BuildContext context, Function(String) callback) async {
    preimage = generatePreimage();
    String hash = (hashType == kHashTypes[1])
        ? Hash.fromBytes(await Crypto.sha256Bytes(preimage)).toString()
        : Hash.digest(preimage).toString();

    callback(hash);
  }

  Widget _getCreateAtomicSwapViewModel() {
    return ViewModelBuilder<CreateHtlcBloc>.reactive(
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            print("_getCreateAtomicSwapViewModel: $event");
            if (event is AccountBlockTemplate) {
              _sendConfirmationNotification();
              setState(() {
                _createAtomicSwapButtonKey.currentState?.animateReverse();
              });
            }
          },
          onError: (error) {
            _sendErrorNotification(error);
            setState(() {
              _createAtomicSwapButtonKey.currentState?.animateReverse();
            });
            //TODO: remove pending swap???
            //sl.get<HtlcListBloc>().removePendingSwap(
            //   hashLocked: Address.parse(_recipientController.text),
            //  hashLock: (Hash.parse(_hashlockController.text).getBytes())!,
            // );
          },
        );
      },
      builder: (_, model, __) => _getCreateAtomicSwapButton(model),
      viewModelBuilder: () => CreateHtlcBloc(),
    );
  }

  Widget _getCreateAtomicSwapButton(CreateHtlcBloc model) {
    return LoadingButton.stepper(
      onPressed: (_isInputValid())
          ? () {
              _onCreateButtonPressed(model);
            }
          : null,
      text: 'Create Atomic Swap',
      key: _createAtomicSwapButtonKey,
    );
  }

  void _onCreateButtonPressed(CreateHtlcBloc model) async {
    final json = '{"id": "${"0" * 64}",'
        '"timeLocked": "$_selectedSelfAddress",'
        '"hashLocked": "${Address.parse(_recipientController.text)}",'
        '"tokenStandard": "${_selectedToken.tokenStandard}",'
        '"amount": ${_amountController.text.toNum().extractDecimals(_selectedToken.decimals)},'
        '"expirationTime": ${await _getExpirationTime(_selectedLockDuration!)},'
        '"hashType": ${(_selectedHashType == kHashTypes.first) ? 0 : 1},'
        '"keyMaxSize": ${_hashlockController.text.length},'
        '"hashLock": "${base64.encode((Hash.parse(_hashlockController.text).getBytes())!)}"}';

    final TextEditingController _secretController = TextEditingController();
    final GlobalKey<FormState> _secretKey = GlobalKey();

    showDepositDialog(
      context: context,
      title: 'Create Swap',
      htlc: HtlcInfo.fromJson(jsonDecode(json)),
      token: _selectedToken,
      controller: _secretController,
      key: _secretKey,
      preimage: preimage,
      onCreateButtonPressed: () async {
        print("create button pressed");
        sl.get<ActiveSwapsWorker>().addPendingSwap(
              json: json,
              preimage: preimage,
            );
        //(preimage.isNotEmpty) ? _savePreimage(preimage) : null;
        _sendCreateHtlcBlock(model);
        Navigator.pop(context);
      },
    );
  }

  void _sendCreateHtlcBlock(CreateHtlcBloc model) async {
    _createAtomicSwapButtonKey.currentState?.animateForward();
    model.createHtlc(
      timeLocked: Address.parse(_selectedSelfAddress!),
      token: _selectedToken,
      amount: _amountController.text,
      hashLocked: Address.parse(_recipientController.text),
      expirationTime: expirationTime!,
      hashType: (_selectedHashType == kHashTypes.first) ? 0 : 1,
      keyMaxSize: _hashlockController.text.length,
      hashLock: (Hash.parse(_hashlockController.text).getBytes())!,
    );
  }

  List<int> generatePreimage([int length = htlcPreimageDefaultLength]) {
    const maxInt = 256;
    return List<int>.generate(length, (i) => Random.secure().nextInt(maxInt));
  }

  Future<int> _getExpirationTime(String lockDuration) async {
    int _currentTime = (await zenon!.ledger.getFrontierMomentum()).timestamp;
    int _expirationTime = 0;

    switch (lockDuration) {
      case "3 hours":
        _expirationTime = htlcTimelockUnitSec * 3;
        break;
      case "24 hours":
        _expirationTime = htlcTimelockUnitSec * 24;
        break;
      default:
        _expirationTime = htlcTimelockUnitSec * 12;
    }
    expirationTime = _expirationTime + _currentTime;
    return expirationTime!;
  }

  bool _isInputValid() =>
      _amountIsValid &&
      InputValidators.checkAddress(_recipientController.text) == null &&
      InputValidators.checkHash(_hashlockController.text) == null;

  // TODO: encrypt preimage before saving
  /*
  Future<void> _savePreimage(List<int> _preimage) async {
    String hashLock = (Hash.parse(_hashlockController.text)).toString();
    String preimage = FormatUtils.encodeHexString(_preimage);
    Map preimageMap = sharedPrefsService!.get(
      kHtlcCreatedPreimagesKey,
      defaultValue: {},
    );

    preimageMap.addAll({
      hashLock: preimage,
    });

    await sharedPrefsService!.put(
      kHtlcCreatedPreimagesKey,
      preimageMap,
    );
  }
   */

  void _sendConfirmationNotification() {
    sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Sent ${_amountController.text} ${_selectedToken.symbol} '
                'to $htlcAddress',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details: 'Sent ${_amountController.text} ${_selectedToken.symbol} '
                'from $_selectedSelfAddress to $htlcAddress',
            type: NotificationType.paymentSent,
            id: null,
          ),
        );
  }

  void _sendErrorNotification(error) {
    NotificationUtils.sendNotificationError(
      error,
      'Couldn\'t send ${_amountController.text} ${_selectedToken.symbol} '
      'to $htlcAddress',
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _evmAddressController.dispose();
    _hashlockController.dispose();
    super.dispose();
  }
}
