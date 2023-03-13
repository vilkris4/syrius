import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/basic_dropdown_item.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/addresses_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/basic_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

showInitiateSwapDialog({
  required BuildContext context,
  VoidCallback? onCreateButtonPressed,
}) {
  String title = 'Initiate swap';
  bool? valid = false;
  Token selectedToken = kZnnCoin;
  String? selectedSelfAddress = kSelectedAddress;

  TextEditingController counterpartyAddressController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  BasicDropdownItem<int>? selectedLockDuration;
  BasicDropdownItem<int>? selectedHashType;

  final List<BasicDropdownItem<int>> lockDurationItems = [
    BasicDropdownItem(label: '3 hours', value: kOneHourInSeconds * 3),
    BasicDropdownItem(
        label: '12 hours (default)', value: kOneHourInSeconds * 12),
    BasicDropdownItem(label: '24 hours', value: kOneHourInSeconds * 24),
  ];

  final List<BasicDropdownItem<int>> hashTypeItems = [
    BasicDropdownItem(label: 'ZTS (Zenon Network)', value: htlcHashTypeSha3),
    BasicDropdownItem(label: 'BTC (Bitcoin)', value: htlcHashTypeSha256),
  ];

  sl.get<BalanceBloc>().getBalanceForAllAddresses();

  showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 30.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            content: SizedBox(
              width: 495,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  kVerticalSpacing,
                  Row(
                    children: [
                      const SizedBox(
                        width: 5.0,
                      ),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.inverseSurface,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(
                          Icons.clear,
                          color: AppColors.lightSecondary,
                          size: 25.0,
                        ),
                      ),
                    ],
                  ),
                  kVerticalSpacing,
                  Row(
                    children: const [
                      SizedBox(width: 2.0),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Your address',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: AppColors.darkHintTextColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.0),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Counterparty address (NoM)',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: AppColors.darkHintTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Flexible(
                        child: AddressesDropdown(
                          selectedSelfAddress,
                          (address) => setState(() {
                            selectedSelfAddress = address;
                            sl.get<BalanceBloc>().getBalanceForAllAddresses();
                          }),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Flexible(
                        child: InputField(
                          onChanged: (value) {
                            setState(() {});
                          },
                          validator: (value) =>
                              InputValidators.checkAddress(value),
                          controller: counterpartyAddressController,
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
                                counterpartyAddressController.text = value;
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
                      ),
                    ],
                  ),
                  kVerticalSpacing,
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'You are selling',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: AppColors.darkHintTextColor,
                          ),
                        ),
                      ]),
                  const SizedBox(height: 4.0),
                  Flexible(
                    child: StreamBuilder<Map<String, AccountInfo>?>(
                      stream: sl.get<BalanceBloc>().stream,
                      builder: (_, snapshot) {
                        if (snapshot.hasError) {
                          return SyriusErrorWidget(snapshot.error!);
                        }
                        if (snapshot.hasData) {
                          return AmountInputField(
                            controller: amountController,
                            accountInfo: (snapshot.data![selectedSelfAddress]!),
                            valuePadding: 20.0,
                            textColor:
                                Theme.of(context).colorScheme.inverseSurface,
                            initialToken: selectedToken,
                            onChanged: (token, isValid) {
                              setState(() {
                                selectedToken = token;
                                valid = isValid;
                              });
                            },
                          );
                        }
                        return const SyriusLoadingWidget();
                      },
                    ),
                  ),
                  kVerticalSpacing,
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'You are receiving',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: AppColors.darkHintTextColor,
                          ),
                        ),
                      ]),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Expanded(
                        child: BasicDropdown<int>(
                          'Counterparty\'s network',
                          selectedHashType,
                          hashTypeItems,
                          (hashType) => setState(() {
                            if (hashType != null) {
                              selectedHashType = hashType;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  kVerticalSpacing,
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Expires in',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: AppColors.darkHintTextColor,
                          ),
                        ),
                      ]),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Expanded(
                        child: BasicDropdown<int>(
                          'Lock duration',
                          selectedLockDuration,
                          lockDurationItems,
                          (duration) => setState(() {
                            if (duration != null) {
                              selectedLockDuration = duration;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  kVerticalSpacing,
                  kVerticalSpacing,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 25.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        8.0,
                      ),
                      color: Theme.of(context).dividerTheme.color,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Column(children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Text(
                                  '●',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ]),
                            Flexible(
                              child: Column(children: [
                                Row(children: [
                                  Flexible(
                                    child: RichText(
                                      text: TextSpan(
                                        text:
                                            selectedHashType == hashTypeItems[1]
                                                ? 'Bitcoin text'
                                                : 'Zenon Network text',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                  ),
                                ])
                              ]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Column(children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Text(
                                  '●',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ]),
                            Flexible(
                              child: Column(children: [
                                Row(children: [
                                  Flexible(
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'The recipient has until ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        children: [
                                          TextSpan(
                                            text: 'this time',
                                            /*FormatUtils.formatDate(
                                                htlc.expirationTime * 1000,
                                                dateFormat:
                                                    'hh:mm a, MM/dd/yyyy'),*/
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          TextSpan(
                                            text: ' to unlock the deposit.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ],
                                      ),
                                      maxLines: 3,
                                      softWrap: true,
                                    ),
                                  ),
                                ])
                              ]),
                            ),
                          ],
                        ),
                        kVerticalSpacing,
                        Row(
                          children: [
                            Column(children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Text(
                                  '●',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ]),
                            Flexible(
                              child: Column(children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: RichText(
                                        text: TextSpan(
                                          text:
                                              'The deposit can be reclaimed if the recipient does not unlock it before it expires.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        maxLines: 3,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  kVerticalSpacing,
                  kVerticalSpacing,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        onPressed: () async {
                          if (valid == true) {
                            onCreateButtonPressed?.call();
                          } else {
                            if (amountController.text.isEmpty) {
                              amountController.text = ' ';
                              amountController.text = '';
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.znnColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  kVerticalSpacing,
                ],
              ),
            ),
          );
        });
      });
}
