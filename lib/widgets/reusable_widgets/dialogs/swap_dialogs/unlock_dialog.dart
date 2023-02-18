//TODO: a 'scan' for secret suffix

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/info_item_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/scan_secret_suffix_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/dialog_info_item_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

showUnlockDialog({
  required BuildContext context,
  required String title,
  required String description,
  required HtlcInfo htlc,
  required Token token,
  required VoidCallback onUnlockButtonPressed,
  required TextEditingController controller,
  required Key? key,
  String? preimage,
}) async {
  controller.text = preimage!;
  bool valid =
      (await InputValidators.checkSecret(htlc, controller.text) == null)
          ? true
          : false;

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
                          style: Theme.of(context).textTheme.headline5,
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
                            Feather.x,
                            color: AppColors.lightSecondary,
                            size: 25.0,
                          ),
                        ),
                      ],
                    ),
                    kVerticalSpacing,
                    Row(
                      children: [
                        InfoItemWidget(
                          label: 'Deposit ID',
                          value: htlc.id.toString(),
                        ),
                        const SizedBox(
                          width: 15.0,
                        ),
                        InfoItemWidget(
                          label: 'Sender',
                          value: htlc.timeLocked.toString(),
                        ),
                      ],
                    ),
                    kVerticalSpacing,
                    DialogInfoItemWidget(
                      id: 'Locked amount',
                      value: FormatUtils.formatAtomicSwapAmount(
                          htlc.amount, token),
                      address: Address.parse(token.tokenStandard.toString()),
                      token: token,
                    ),
                    kVerticalSpacing,
                    Align(
                      alignment: Alignment.center,
                      child: Icon(
                        AntDesign.arrowdown,
                        color: Theme.of(context).colorScheme.inverseSurface,
                        size: 25,
                      ),
                    ),
                    kVerticalSpacing,
                    DialogInfoItemWidget(
                      id: 'Recipient',
                      value: (kDefaultAddressList
                              .contains(htlc.hashLocked.toString()))
                          ? AddressUtils.getLabel(htlc.hashLocked.toString())
                          : FormatUtils.formatLongString(
                              htlc.hashLocked.toString()),
                      address: htlc.hashLocked,
                      token: token,
                    ),
                    kVerticalSpacing,
                    Form(
                      key: key,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: InputField(
                        onChanged: (value) async {
                          valid = (await InputValidators.checkSecret(
                                      htlc, controller.text) ==
                                  null)
                              ? true
                              : false;
                          // setState(() {});
                        },
                        validator: (value) =>
                            (valid == true) ? null : 'Invalid secret',
                        controller: controller,
                        contentLeftPadding: 20.0,
                        suffixIcon: (!valid)
                            ? ScanSecretSuffixWidgets(
                                onScanPressed: () {},
                                onClipboardPressed: () {
                                  ClipboardUtils.pasteToClipboard(context,
                                      (String _value) async {
                                    controller.text = '';
                                    controller.text = _value;
                                    valid = (await InputValidators.checkSecret(
                                                htlc, controller.text) ==
                                            null)
                                        ? true
                                        : false;
                                  });
                                },
                              )
                            : const SizedBox(
                                width: 15.0,
                              ),
                        suffixIconConstraints: const BoxConstraints(),
                        hintText: 'Secret',
                      ),
                    ),
                    /*
                    Form(
                      key: key,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: InputField(
                        onChanged: (value) async {
                          valid = (await InputValidators.checkSecret(
                                      htlc, controller.text) ==
                                  null)
                              ? true
                              : false;
                        },
                        validator: (value) =>
                            (valid == true) ? null : 'Invalid secret',
                        controller: controller,
                        suffixIcon: ScanSecretSuffixWidgets(
                          onScanPressed: () {
                            /*
                            num maxZnn = accountInfo.getBalanceWithDecimals(
                              kZnnCoin.tokenStandard,
                            );
                            if (_znnAmountController.text.isEmpty ||
                                _znnAmountController.text.toNum() < maxZnn) {
                              setState(() {
                                _znnAmountController.text = maxZnn.toString();
                              });
                            }

                             */
                          },
                          onClipboardPressed: () {
                            ClipboardUtils.pasteToClipboard(context,
                                (String _value) async {
                              controller.text = '';
                              controller.text = _value;
                              valid = (await InputValidators.checkSecret(
                                          htlc, controller.text) ==
                                      null)
                                  ? true
                                  : false;
                            });
                          },
                        ),

                        //_getSecretSuffix(),
                        /*
                  RawMaterialButton(
                    child: const Icon(
                      Icons.content_paste,
                      color: AppColors.darkHintTextColor,
                      size: 15.0,
                    ),
                    shape: const CircleBorder(),
                    onPressed: () {
                      ClipboardUtils.pasteToClipboard(context,
                          (String _value) async {
                        controller.text = '';
                        controller.text = _value;
                        valid = (await InputValidators.checkSecret(
                                    htlc, controller.text) ==
                                null)
                            ? true
                            : false;
                      });
                    },
                  ),
                   */
                        suffixIconConstraints: const BoxConstraints(
                          maxWidth: 45.0,
                          maxHeight: 20.0,
                        ),
                        hintText: 'Secret',
                      ),
                    ),
                    */
                    kVerticalSpacing,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                          onPressed: () async {
                            valid = (await InputValidators.checkSecret(
                                        htlc, controller.text) ==
                                    null)
                                ? true
                                : false;
                            if (valid == true) {
                              onUnlockButtonPressed();
                            } else {
                              if (controller.text.isEmpty) {
                                controller.text = ' ';
                                controller.text = '';
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
                                        Theme.of(context).textTheme.subtitle1,
                                  ),
                                ),
                              ]),
                              Flexible(
                                child: Column(children: [
                                  Row(children: [
                                    Flexible(
                                      child: RichText(
                                        text: TextSpan(
                                          text: 'You will receive ',
                                          style: Theme.of(context)
                                              .textTheme
                                              .subtitle1,
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${FormatUtils.formatAtomicSwapAmount(htlc.amount, token)} ${token.symbol} ',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                            TextSpan(
                                              text: 'into ',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1,
                                            ),
                                            TextSpan(
                                              text: (kDefaultAddressList
                                                      .contains(htlc.hashLocked
                                                          .toString()))
                                                  ? AddressUtils.getLabel(htlc
                                                      .hashLocked
                                                      .toString())
                                                  : FormatUtils
                                                      .formatLongString(htlc
                                                          .hashLocked
                                                          .toString()),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                            TextSpan(
                                              text: '.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1,
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
                                        Theme.of(context).textTheme.subtitle1,
                                  ),
                                ),
                              ]),
                              Flexible(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Column(children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      text:
                                                          'The secret will be published on-chain.',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .subtitle1,
                                                    ),
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
                            ],
                          ),
                        ],
                      ),
                    ),
                    kVerticalSpacing,
                  ],
                )),
          );
        });
      });
}
