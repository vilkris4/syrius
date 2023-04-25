import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/create_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/basic_dropdown_item.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/addresses_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/basic_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/labeled_input_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class StartNativeSwapModal extends StatefulWidget {
  final Function(String) onSwapStarted;

  const StartNativeSwapModal({
    required this.onSwapStarted,
    Key? key,
  }) : super(key: key);

  @override
  State<StartNativeSwapModal> createState() => _StartNativeSwapModalState();
}

class _StartNativeSwapModalState extends State<StartNativeSwapModal> {
  Token _selectedToken = kZnnCoin;
  String? _selectedSelfAddress = kSelectedAddress;
  bool _isAmountValid = false;

  late Hash _hashLock;
  late List<int> _preimage;
  late int _expirationTime;

  final TextEditingController _counterpartyAddressController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  late BasicDropdownItem<int> _selectedLockDuration;

  final List<BasicDropdownItem<int>> _lockDurationItems = [
    BasicDropdownItem(label: '3 hours', value: kOneHourInSeconds * 3),
    BasicDropdownItem(label: '12 hours', value: kOneHourInSeconds * 12),
    BasicDropdownItem(label: '24 hours', value: kOneHourInSeconds * 24),
  ];

  bool _isSendingTransaction = false;

  @override
  void initState() {
    super.initState();
    sl.get<BalanceBloc>().getBalanceForAllAddresses();
    _selectedLockDuration = _lockDurationItems[1];
  }

  @override
  void dispose() {
    _counterpartyAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      title: 'Start swap',
      child: _getContent(),
    );
  }

  Widget _getContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20.0),
        Row(
          children: [
            Expanded(
              child: LabeledInputContainer(
                labelText: 'Your address',
                inputWidget: AddressesDropdown(
                  _selectedSelfAddress,
                  (address) => setState(() {
                    _selectedSelfAddress = address;
                    sl.get<BalanceBloc>().getBalanceForAllAddresses();
                  }),
                ),
              ),
            ),
            const SizedBox(
              width: 20.0,
            ),
            Expanded(
              child: LabeledInputContainer(
                labelText: 'Counterparty address',
                helpText: 'The address of the trading partner for the swap.',
                inputWidget: Form(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: InputField(
                    onChanged: (value) {
                      setState(() {});
                    },
                    validator: (value) => _validateCounterpartyAddress(value),
                    controller: _counterpartyAddressController,
                    suffixIcon: RawMaterialButton(
                      child: const Icon(
                        Icons.content_paste,
                        color: AppColors.darkHintTextColor,
                        size: 15.0,
                      ),
                      shape: const CircleBorder(),
                      onPressed: () {
                        ClipboardUtils.pasteToClipboard(context,
                            (String value) {
                          _counterpartyAddressController.text = value;
                          setState(() {});
                        });
                      },
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      maxWidth: 45.0,
                      maxHeight: 20.0,
                    ),
                    hintText: 'z1q...',
                    contentLeftPadding: 10.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        kVerticalSpacing,
        LabeledInputContainer(
          labelText: 'You are sending',
          inputWidget: Flexible(
            child: StreamBuilder<Map<String, AccountInfo>?>(
              stream: sl.get<BalanceBloc>().stream,
              builder: (_, snapshot) {
                if (snapshot.hasError) {
                  return SyriusErrorWidget(snapshot.error!);
                }
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.hasData) {
                    return AmountInputField(
                      controller: _amountController,
                      accountInfo: (snapshot.data![_selectedSelfAddress]!),
                      valuePadding: 10.0,
                      textColor: Theme.of(context).colorScheme.inverseSurface,
                      initialToken: _selectedToken,
                      hintText: '0.0',
                      onChanged: (token, isValid) {
                        setState(() {
                          _selectedToken = token;
                          _isAmountValid = isValid;
                        });
                      },
                    );
                  } else {
                    return const SyriusLoadingWidget();
                  }
                } else {
                  return const SyriusLoadingWidget();
                }
              },
            ),
          ),
        ),
        kVerticalSpacing,
        LabeledInputContainer(
          labelText: 'Your deposit expires in',
          helpText:
              'If the swap is unsuccessful you can reclaim your funds after the deposit has expired.',
          inputWidget: BasicDropdown<int>(
            'Lock duration',
            _selectedLockDuration,
            _lockDurationItems,
            (duration) => setState(
              () {
                if (duration != null) {
                  _selectedLockDuration = duration;
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 25.0),
        _getStartSwapViewModel(),
      ],
    );
  }

  _getStartSwapViewModel() {
    return ViewModelBuilder<CreateHtlcBloc>.reactive(
      onModelReady: (model) {
        model.stream.listen(
          (event) async {
            if (event is AccountBlockTemplate) {
              await htlcSwapsService!.storeSwap(HtlcSwap(
                id: event.hash.toString(),
                type: P2pSwapType.native,
                direction: P2pSwapDirection.outgoing,
                selfAddress: _selectedSelfAddress!,
                counterpartyAddress: _counterpartyAddressController.text,
                state: P2pSwapState.pending,
                startTime:
                    (DateTime.now().millisecondsSinceEpoch / 1000).round(),
                initialHtlcExpirationTime: _expirationTime,
                fromAmount: _amountController.text
                    .toNum()
                    .extractDecimals(_selectedToken.decimals),
                fromTokenStandard: _selectedToken.tokenStandard.toString(),
                fromDecimals: _selectedToken.decimals,
                fromSymbol: _selectedToken.symbol,
                fromChain: P2pSwapChain.nom,
                toChain: P2pSwapChain.nom,
                hashLock: _hashLock.toString(),
                preimage: FormatUtils.encodeHexString(_preimage),
                initialHtlcId: event.hash.toString(),
                hashType: htlcHashTypeSha3,
              ));
              widget.onSwapStarted.call(event.hash.toString());
            }
          },
          onError: (error) {
            setState(() {
              _isSendingTransaction = false;
            });
          },
        );
      },
      builder: (_, model, __) => _getStartSwapButton(model),
      viewModelBuilder: () => CreateHtlcBloc(),
    );
  }

  Widget _getStartSwapButton(CreateHtlcBloc model) {
    return InstructionButton(
      text: 'Start swap',
      instructionText: 'Fill in the swap details',
      loadingText: 'Sending transaction',
      isEnabled: _isInputValid(),
      isLoading: _isSendingTransaction,
      onPressed: () => _onStartButtonPressed(model),
    );
  }

  void _onStartButtonPressed(CreateHtlcBloc model) async {
    setState(() {
      _isSendingTransaction = true;
    });
    _expirationTime = (await zenon!.ledger.getFrontierMomentum()).timestamp +
        _selectedLockDuration.value;
    _preimage = _generatePreimage();
    _hashLock = Hash.digest(_preimage);

    model.createHtlc(
      timeLocked: Address.parse(_selectedSelfAddress!),
      token: _selectedToken,
      amount: _amountController.text,
      hashLocked: Address.parse(_counterpartyAddressController.text),
      expirationTime: _expirationTime,
      hashType: htlcHashTypeSha3,
      keyMaxSize: htlcPreimageMaxLength,
      hashLock: _hashLock.getBytes()!,
    );
  }

  List<int> _generatePreimage([int length = htlcPreimageDefaultLength]) {
    const maxInt = 256;
    return List<int>.generate(length, (i) => Random.secure().nextInt(maxInt));
  }

  bool _isInputValid() =>
      _validateCounterpartyAddress(_counterpartyAddressController.text) ==
          null &&
      _isAmountValid;

  String? _validateCounterpartyAddress(String? address) {
    String? result = InputValidators.checkAddress(address);
    if (result != null) {
      return result;
    } else {
      return kDefaultAddressList.contains(address)
          ? 'Cannot swap with your own address'
          : null;
    }
  }
}
