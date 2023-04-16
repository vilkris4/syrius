import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/create_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/handlers/p2p_swaps_handler.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/basic_dropdown_item.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_pair.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/addresses_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/basic_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
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
  _StartNativeSwapModalState createState() => _StartNativeSwapModalState();
}

class _StartNativeSwapModalState extends State<StartNativeSwapModal> {
  Token _selectedToken = kZnnCoin;
  bool _areInputsValid = false;
  String? _selectedSelfAddress = kSelectedAddress;

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

  @override
  void initState() {
    super.initState();
    sl.get<BalanceBloc>().getBalanceForAllAddresses();
    _selectedLockDuration = _lockDurationItems[1];
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
        const SizedBox(height: 25.0),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your address',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: AppColors.darkHintTextColor,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  AddressesDropdown(
                    _selectedSelfAddress,
                    (address) => setState(() {
                      _selectedSelfAddress = address;
                      sl.get<BalanceBloc>().getBalanceForAllAddresses();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 20.0,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Counterparty address',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: AppColors.darkHintTextColor,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  InputField(
                    onChanged: (value) {
                      setState(() {});
                    },
                    validator: (value) => InputValidators.checkAddress(value),
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
                    contentLeftPadding: 20.0,
                  ),
                ],
              ),
            ),
          ],
        ),
        kVerticalSpacing,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You are selling',
              style: TextStyle(
                fontSize: 14.0,
                color: AppColors.darkHintTextColor,
              ),
            ),
            const SizedBox(height: 3.0),
            Flexible(
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
                        valuePadding: 20.0,
                        textColor: Theme.of(context).colorScheme.inverseSurface,
                        initialToken: _selectedToken,
                        onChanged: (token, isValid) {
                          setState(() {
                            _selectedToken = token;
                            _areInputsValid = isValid;
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
          ],
        ),
        kVerticalSpacing,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your deposit expires in',
              style: TextStyle(
                fontSize: 14.0,
                color: AppColors.darkHintTextColor,
              ),
            ),
            const SizedBox(height: 3.0),
            BasicDropdown<int>(
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
          ],
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
          (event) {
            if (event is AccountBlockTemplate) {
              _storeP2pSwap(event.hash.toString());
              _storeHtlcPair(event.hash.toString());
              widget.onSwapStarted.call(event.hash.toString());
              Navigator.pop(context);
            }
          },
          onError: (error) {
            //TODO: remove pending swap
            //Example: create a swap with a net id that doesn't match the node
            //_sendErrorNotification(error);
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
      isEnabled: true, //areInputsValid,
      onPressed: () {
        if (_areInputsValid) {
          _onStartButtonPressed(model);
        } else {
          if (_amountController.text.isEmpty) {
            _amountController.text = ' ';
            _amountController.text = '';
          }
        }
      },
    );
  }

  void _onStartButtonPressed(CreateHtlcBloc model) async {
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

  void _storeP2pSwap(String id) async {
    await sl<P2pSwapsHandler>().storeSwap(P2pSwap(
        id: id,
        type: P2pSwapType.native,
        mode: P2pSwapMode.htlc,
        direction: P2pSwapDirection.outgoing,
        state: P2pSwapState.pending,
        startTime: (DateTime.now().millisecondsSinceEpoch / 1000).round(),
        expirationTime: _expirationTime,
        fromAmount: _amountController.text
            .toNum()
            .extractDecimals(_selectedToken.decimals),
        toAmount: 0,
        fromToken: _selectedToken,
        selfAddress: _selectedSelfAddress!,
        counterpartyAddress: _counterpartyAddressController.text));
  }

  void _storeHtlcPair(String initialHtlcId) async {
    await sl<P2pSwapsHandler>().storeHtlcPair(HtlcPair(
      hashLock: _hashLock.toString(),
      preimage: _preimage.toString(),
      initialHtlcId: initialHtlcId,
      counterHtlcId: '',
    ));
  }

  List<int> _generatePreimage([int length = htlcPreimageDefaultLength]) {
    const maxInt = 256;
    return List<int>.generate(length, (i) => Random.secure().nextInt(maxInt));
  }

  @override
  void dispose() {
    _counterpartyAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
