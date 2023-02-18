import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/info_item_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/dialog_info_item_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

showDepositDialog({
  required BuildContext context,
  required String title,
  required HtlcInfo htlc,
  required Token token,
  VoidCallback? onCreateButtonPressed,
  final void Function(Token)? onDepositButtonPressed,
  required TextEditingController controller,
  required Key? key,
  List<int>? preimage,
}) {
  bool? valid = false;
  controller.text = '';
  num ratio = 0;
  bool ratioReversed = false;
  Token _selectedToken =
      (token.tokenStandard.toString() == kZnnCoin.tokenStandard.toString())
          ? kQsrCoin
          : kZnnCoin;
  bool _creatingSwap = (title == 'Create Swap');

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
                        label: 'Recipient',
                        value: (_creatingSwap)
                            ? htlc.hashLocked.toString()
                            : htlc.timeLocked.toString(),
                      )
                    ],
                  ),
                  kVerticalSpacing,
                  Visibility(
                    visible: !_creatingSwap,
                    child: Flexible(
                      child: StreamBuilder<Map<String, AccountInfo>?>(
                        stream: sl.get<BalanceBloc>().stream,
                        builder: (_, snapshot) {
                          if (snapshot.hasError) {
                            return SyriusErrorWidget(snapshot.error!);
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.active) {
                            if (snapshot.hasData) {
                              return AmountInputField(
                                controller: controller,
                                accountInfo: (snapshot
                                    .data![htlc.hashLocked.toString()]!),
                                valuePadding: 20.0,
                                textColor: Theme.of(context)
                                    .colorScheme
                                    .inverseSurface,
                                initialToken: _selectedToken,
                                onChanged: (token, isValid) {
                                  setState(() {
                                    _selectedToken = token;
                                    valid = isValid;
                                    if (isValid) {
                                      ratio = (!ratioReversed)
                                          ? AmountUtils.addDecimals(
                                                  htlc.amount, token.decimals) /
                                              controller.text.toNum()
                                          : controller.text.toNum() /
                                              AmountUtils.addDecimals(
                                                  htlc.amount, token.decimals);
                                    } else {
                                      ratio = 0;
                                    }
                                  });
                                },
                              );
                            }
                            return const SyriusLoadingWidget();
                          }
                          return const SyriusLoadingWidget();
                        },
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !_creatingSwap,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 13.0),
                      child: Row(children: [
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(children: [
                                  const SizedBox(
                                    width: 20.0,
                                  ),
                                  Text(
                                      (!ratioReversed)
                                          ? '1 ${token.symbol} = ${ratio.toStringAsFixed(5)} ${_selectedToken.symbol}'
                                          : '1 ${_selectedToken.symbol} = ${ratio.toStringAsFixed(5)} ${token.symbol}',
                                      style: const TextStyle(
                                        color:
                                            AppColors.unselectedSeedChoiceColor,
                                      )),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        ratioReversed = !ratioReversed;
                                        (1 / ratio).isInfinite
                                            ? ratio = 0
                                            : ratio = 1 / ratio;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .inverseSurface,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      minimumSize: Size.zero,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(
                                      Feather.refresh_cw,
                                      color:
                                          AppColors.unselectedSeedChoiceColor,
                                      size: 15.0,
                                    ),
                                  ),
                                ]))),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Icon(
                            AntDesign.arrowdown,
                            color: Theme.of(context).colorScheme.inverseSurface,
                            size: 25,
                          ),
                        ),
                        const Spacer(),
                      ]),
                    ),
                  ),
                  kVerticalSpacing,
                  DialogInfoItemWidget(
                    id: (_creatingSwap) ? 'Sending' : 'You receive',
                    value:
                        FormatUtils.formatAtomicSwapAmount(htlc.amount, token),
                    address: Address.parse(htlc.tokenStandard.toString()),
                    token: token,
                  ),
                  kVerticalSpacing,
                  (preimage == null)
                      ? Container()
                      : Visibility(
                          visible: preimage.isNotEmpty,
                          child: Row(children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).dividerTheme.color,
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        style: BorderStyle.solid),
                                    borderRadius: BorderRadius.circular(7.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(15.0),
                                        child: Text(
                                            'Copy and save this secret. You will need it to unlock the counter deposit.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1,
                                            textScaleFactor: 1.2),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 15.0, left: 15.0),
                                        child: Row(
                                          children: [
                                            Text(
                                              FormatUtils.formatLongString(
                                                  FormatUtils.encodeHexString(
                                                      preimage)),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                              textScaleFactor: 1.2,
                                            ),
                                            CopyToClipboardIcon(
                                              FormatUtils.encodeHexString(
                                                  preimage),
                                              iconColor:
                                                  AppColors.darkHintTextColor,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )),
                            )
                          ]),
                        ),
                  Visibility(child: kVerticalSpacing, visible: _creatingSwap),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                        onPressed: () async {
                          if (_creatingSwap) {
                            onCreateButtonPressed?.call();
                          } else if (valid == true) {
                            onDepositButtonPressed!(_selectedToken);
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
                                  style: Theme.of(context).textTheme.subtitle1,
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
                                            .subtitle1,
                                        children: [
                                          TextSpan(
                                            text: FormatUtils.formatDate(
                                                htlc.expirationTime * 1000,
                                                dateFormat:
                                                    'hh:mm a, MM/dd/yyyy'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
                                          ),
                                          TextSpan(
                                            text: ' to unlock the deposit.',
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
                        Visibility(
                          visible: !_creatingSwap,
                          child: kVerticalSpacing,
                        ),
                        Visibility(
                          visible: !_creatingSwap,
                          child: Row(
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
                                  Row(
                                    children: [
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
                                                        .contains(htlc
                                                            .hashLocked
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
                                                text:
                                                    ' after the recipient unlocks the deposit.',
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
                                    ],
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                        kVerticalSpacing,
                        Row(
                          children: [
                            Column(children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Text(
                                  '●',
                                  style: Theme.of(context).textTheme.subtitle1,
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
                                              .subtitle1,
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
                ],
              ),
            ),
          );
        });
      });
}
