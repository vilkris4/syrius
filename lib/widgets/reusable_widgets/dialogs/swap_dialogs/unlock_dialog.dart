//TODO: a cancel a 'scan for secret' future

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/info_item_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
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

  bool scanning = false;
  bool? secretFound;

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
                        },
                        validator: (value) =>
                            (valid == true) ? null : 'Invalid secret',
                        controller: controller,
                        contentLeftPadding: 20.0,
                        suffixIcon: (!valid)
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  (!scanning && secretFound == null)
                                      ? SecretSuffixScanWidget(
                                          onPressed: () async {
                                          setState(() {
                                            scanning = true;
                                          });
                                          String _preimage = await sl
                                              .get<ActiveSwapsWorker>()
                                              .scanForSecret(htlc.id);
                                          try {
                                            setState(() {
                                              if (_preimage.isEmpty) {
                                                secretFound = false;
                                                scanning = false;
                                              } else {
                                                preimage = _preimage;
                                                controller.text = preimage!;
                                                secretFound = true;
                                                scanning = false;
                                              }
                                            });
                                          } catch (e) {
                                            //TODO: handle error when Navigator pop() during scan
                                            print(e);
                                          }
                                          valid = (await InputValidators
                                                      .checkSecret(htlc,
                                                          controller.text) ==
                                                  null)
                                              ? true
                                              : false;
                                        })
                                      : Container(),
                                  SecretSuffixClipboardWidget(
                                    onPressed: () => {
                                      ClipboardUtils.pasteToClipboard(context,
                                          (String _value) async {
                                        controller.text = '';
                                        controller.text = _value;
                                        valid =
                                            (await InputValidators.checkSecret(
                                                        htlc,
                                                        controller.text) ==
                                                    null)
                                                ? true
                                                : false;
                                      }),
                                    },
                                  ),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                ],
                              )
                            : const SizedBox(
                                width: 20.0,
                              ),
                        suffixIconConstraints: const BoxConstraints(),
                        hintText: 'Secret',
                      ),
                    ),
                    Visibility(
                        visible: scanning || secretFound != null,
                        child: Flexible(
                            child: Row(
                          children: [
                            Visibility(
                                visible: scanning,
                                child: Flexible(
                                    child: Row(children: [
                                  const SizedBox(
                                    width: 20.0,
                                    height: 50.0,
                                  ),
                                  const SyriusLoadingWidget(
                                    size: 12.0,
                                    strokeWidth: 1.0,
                                  ),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  Text(
                                    'Scanning for secrets...',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                  const Spacer(),
                                  SecretCancelScanWidget(onPressed: () {}),
                                ]))),
                            Visibility(
                                visible: secretFound == true,
                                child: Row(children: [
                                  const SizedBox(
                                    width: 20.0,
                                    height: 50.0,
                                  ),
                                  const Icon(
                                    AntDesign.checkcircleo,
                                    size: 12.0,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  Text(
                                    'Secret found',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ])),
                            Visibility(
                                visible: secretFound == false,
                                child: Row(children: [
                                  const SizedBox(
                                    width: 20.0,
                                    height: 50.0,
                                  ),
                                  const Icon(
                                    AntDesign.closecircleo,
                                    size: 12.0,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  Text(
                                    'Secret not published yet',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ])),
                          ],
                        ))),
                    (!scanning && secretFound == null)
                        ? kVerticalSpacing
                        : Container(),
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
