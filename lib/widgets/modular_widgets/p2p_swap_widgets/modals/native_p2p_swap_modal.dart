import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/reclaim_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/unlock_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_swap_details_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/elevated_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/exchange_rate_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_info_text.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class NativeP2pSwapModal extends StatefulWidget {
  final String swapId;
  final Function(String)? onSwapStarted;

  const NativeP2pSwapModal({
    required this.swapId,
    this.onSwapStarted,
    Key? key,
  }) : super(key: key);

  @override
  State<NativeP2pSwapModal> createState() => _NativeP2pSwapModalState();
}

class _NativeP2pSwapModalState extends State<NativeP2pSwapModal> {
  late final HtlcSwapBloc _htlcSwapBloc;

  String _swapCompletedText = 'Swap completed.';

  bool _isSendingTransaction = false;
  bool _shouldShowIncorrectAmountInstructions = false;

  @override
  void initState() {
    super.initState();
    _htlcSwapBloc = HtlcSwapBloc(widget.swapId);
    _htlcSwapBloc.getDataPeriodically();
  }

  @override
  void dispose() {
    _htlcSwapBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HtlcSwap>(
      stream: _htlcSwapBloc.stream,
      builder: (_, snapshot) {
        if (snapshot.hasData) {
          return BaseModal(
            title: _getTitle(snapshot.data!),
            child: _getContent(snapshot.data!),
          );
        } else if (snapshot.hasError) {
          return SyriusErrorWidget(snapshot.error!);
        }
        return const SyriusLoadingWidget();
      },
    );
  }

  String _getTitle(HtlcSwap swap) {
    return swap.state == P2pSwapState.active ? 'Active swap' : '';
  }

  Widget _getContent(HtlcSwap swap) {
    switch (swap.state) {
      case P2pSwapState.pending:
        return _getPendingView();
      case P2pSwapState.active:
        return _getActiveView(swap);
      case P2pSwapState.completed:
        return _getCompletedView(swap);
      case P2pSwapState.reclaimable:
      case P2pSwapState.unsuccessful:
        return _getUnsuccessfulView(swap);
      default:
        return Container();
    }
  }

  Widget _getPendingView() {
    return SizedBox(
      height: 215.0,
      child:
          Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Text(
          'Starting swap. This will take a moment.',
          style: TextStyle(
            fontSize: 16.0,
          ),
        ),
        SizedBox(height: 25.0),
        SyriusLoadingWidget()
      ]),
    );
  }

  Widget _getActiveView(HtlcSwap swap) {
    return Column(
      children: [
        const SizedBox(
          height: 20.0,
        ),
        HtlcCard.sending(swap: swap),
        const SizedBox(
          height: 15.0,
        ),
        const Icon(
          AntDesign.arrowdown,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(
          height: 15.0,
        ),
        HtlcCard.receiving(swap: swap),
        const SizedBox(
          height: 25,
        ),
        _getBottomSection(swap),
      ],
    );
  }

  Widget _getCompletedView(HtlcSwap swap) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 10.0,
        ),
        Container(
          width: 72.0,
          height: 72.0,
          color: Colors.transparent,
          child: SvgPicture.asset(
            'assets/svg/ic_completed_symbol.svg',
            color: AppColors.znnColor,
          ),
        ),
        const SizedBox(
          height: 30.0,
        ),
        Text(
          _swapCompletedText,
          style: const TextStyle(
            fontSize: 16.0,
          ),
        ),
        const SizedBox(height: 25.0),
        Container(
          decoration: const BoxDecoration(
              color: Color(0xff282828),
              borderRadius: BorderRadius.all(Radius.circular(8.0))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('From',
                        style: TextStyle(
                            fontSize: 14.0, color: AppColors.subtitleColor)),
                    Text(
                        '${swap.fromAmount.addDecimals(swap.fromDecimals)} ${swap.fromSymbol}',
                        style: const TextStyle(
                            fontSize: 14.0, color: AppColors.subtitleColor)),
                  ],
                ),
                const SizedBox(
                  height: 15.0,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('To',
                        style: TextStyle(
                            fontSize: 14.0, color: AppColors.subtitleColor)),
                    Text(
                        '${swap.toAmount!.addDecimals(swap.toDecimals!)} ${swap.toSymbol!}',
                        style: const TextStyle(
                            fontSize: 14.0, color: AppColors.subtitleColor)),
                  ],
                ),
                const SizedBox(
                  height: 15.0,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Exchange Rate',
                      style: TextStyle(
                          fontSize: 14.0, color: AppColors.subtitleColor),
                    ),
                    _getExchangeRateWidget(swap),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 25,
        ),
        HtlcSwapDetailsWidget(swap: swap),
      ],
    );
  }

  Widget _getUnsuccessfulView(HtlcSwap swap) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final expiration = swap.direction == P2pSwapDirection.outgoing
        ? swap.initialHtlcExpirationTime
        : swap.counterHtlcExpirationTime;
    final remainingDuration = Duration(seconds: (expiration ?? 0) - now);
    final isReclaimable = remainingDuration.inSeconds <= 0 &&
        swap.state == P2pSwapState.reclaimable;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 10.0,
        ),
        Container(
          width: 72.0,
          height: 72.0,
          color: Colors.transparent,
          child: SvgPicture.asset(
            'assets/svg/ic_unsuccessful_symbol.svg',
            color: AppColors.errorColor,
          ),
        ),
        const SizedBox(
          height: 30.0,
        ),
        Text(
          isReclaimable || swap.state == P2pSwapState.unsuccessful
              ? 'The swap was unsuccessful.'
              : 'The swap was unsuccessful.\nPlease wait for your deposit to expire to reclaim your funds.',
          style: const TextStyle(
            fontSize: 16.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 25.0),
        Container(
          decoration: const BoxDecoration(
              color: Color(0xff282828),
              borderRadius: BorderRadius.all(Radius.circular(8.0))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (remainingDuration.inSeconds > 0)
                  TweenAnimationBuilder<Duration>(
                    duration: remainingDuration,
                    tween: Tween(begin: remainingDuration, end: Duration.zero),
                    onEnd: () => setState(() {}),
                    builder: (_, Duration d, __) {
                      return Visibility(
                        visible: d.inSeconds > 0,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 15.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Deposit expires in',
                                style: TextStyle(
                                    fontSize: 14.0,
                                    color: AppColors.subtitleColor),
                              ),
                              Text(
                                d.toString().split('.').first,
                                style: const TextStyle(
                                    fontSize: 14.0,
                                    color: AppColors.subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        swap.state == P2pSwapState.reclaimable
                            ? 'Deposited amount'
                            : 'Deposited amount (reclaimed)',
                        style: const TextStyle(
                            fontSize: 14.0, color: AppColors.subtitleColor)),
                    Text(
                      '${swap.fromAmount.addDecimals(swap.fromDecimals)} ${swap.fromSymbol}',
                      style: const TextStyle(
                          fontSize: 14.0, color: AppColors.subtitleColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isReclaimable)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: _getReclaimButton(swap),
          ),
        const SizedBox(
          height: 25,
        ),
        HtlcSwapDetailsWidget(swap: swap),
      ],
    );
  }

  Widget _getBottomSection(HtlcSwap swap) {
    if (swap.counterHtlcId == null) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              'Send your deposit ID to the counterparty via a messaging service so that they can join the swap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
              ),
            ),
          ),
          const SizedBox(
            height: 25,
          ),
          SyriusElevatedButton(
            text: 'Copy deposit ID',
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333333),
            ),
            onPressed: () =>
                ClipboardUtils.copyToClipboard(swap.initialHtlcId, context),
            icon: const Icon(
              Icons.copy,
              color: Colors.white,
              size: 18.0,
            ),
          )
        ],
      );
    } else {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exchange Rate',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: AppColors.subtitleColor,
                  ),
                ),
                _getExchangeRateWidget(swap),
              ],
            ),
          ),
          const SizedBox(
            height: 25,
          ),
          Visibility(
            visible: swap.direction == P2pSwapDirection.outgoing,
            child: Column(
              children: [
                _getSwapButtonViewModel(swap),
                const SizedBox(
                  height: 25,
                ),
                _getIncorrectAmountButton(swap),
              ],
            ),
          ),
          Visibility(
            visible: swap.direction == P2pSwapDirection.incoming,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: LoadingInfoText(
                  text: 'Waiting for the counterparty to complete the swap.'),
            ),
          ),
        ],
      );
    }
  }

  Widget _getSwapButtonViewModel(HtlcSwap swap) {
    return ViewModelBuilder<UnlockHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) async {
            if (event is AccountBlockTemplate) {
              _swapCompletedText =
                  'Swap completed. You will receive the funds shortly.';
              swap.state = P2pSwapState.completed;
              await htlcSwapsService!.storeSwap(swap);
            }
          },
          onError: (error) {
            setState(() {
              _isSendingTransaction = false;
            });
          },
        );
      },
      builder: (_, model, __) => InstructionButton(
        text: 'Swap',
        isEnabled: true,
        isLoading: _isSendingTransaction,
        loadingText: 'Swapping',
        onPressed: () {
          setState(() {
            _isSendingTransaction = true;
          });
          model.unlockHtlc(
              id: Hash.parse(swap.counterHtlcId!),
              preimage: FormatUtils.decodeHexString(swap.preimage!),
              hashLocked: Address.parse(swap.selfAddress));
        },
      ),
      viewModelBuilder: () => UnlockHtlcBloc(),
    );
  }

  Widget _getIncorrectAmountButton(HtlcSwap swap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 50),
          firstCurve: Curves.easeInOut,
          firstChild: InkWell(
            onTap: () => setState(() {
              _shouldShowIncorrectAmountInstructions = true;
            }),
            child: const Center(
              child: Text(
                'I’m receiving the wrong token or amount.',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.subtitleColor,
                ),
              ),
            ),
          ),
          secondChild:
              _getIncorrectAmountInstructions(swap.initialHtlcExpirationTime),
          crossFadeState: _shouldShowIncorrectAmountInstructions
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),
      ),
    );
  }

  Widget _getIncorrectAmountInstructions(int expirationTime) {
    final expiration =
        DateTime.fromMillisecondsSinceEpoch(expirationTime * 1000);
    return Text(
      'If the token or the amount you are receiving is not what you have agreed upon, wait until your deposit expires to reclaim your funds.\nYour deposit will expire at ${expiration.toString().split('.').first}.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14.0,
      ),
    );
  }

  Widget _getReclaimButton(HtlcSwap swap) {
    return ViewModelBuilder<ReclaimHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) async {
            if (event is AccountBlockTemplate) {
              swap.state = P2pSwapState.unsuccessful;
              await htlcSwapsService!.storeSwap(swap);
            }
          },
          onError: (error) {
            setState(() {
              _isSendingTransaction = false;
            });
          },
        );
      },
      builder: (_, model, __) => InstructionButton(
        text: 'Reclaim funds',
        isEnabled: true,
        isLoading: _isSendingTransaction,
        loadingText: 'Reclaiming',
        onPressed: () {
          setState(() {
            _isSendingTransaction = true;
          });
          model.reclaimHtlc(
            id: swap.direction == P2pSwapDirection.outgoing
                ? Hash.parse(swap.initialHtlcId)
                : Hash.parse(swap.counterHtlcId!),
            timeLocked: Address.parse(swap.selfAddress),
          );
        },
      ),
      viewModelBuilder: () => ReclaimHtlcBloc(),
    );
  }

  Widget _getExchangeRateWidget(HtlcSwap swap) {
    return ExchangeRateWidget(
        fromAmount: swap.fromAmount,
        fromDecimals: swap.fromDecimals,
        fromSymbol: swap.fromSymbol,
        toAmount: swap.toAmount!,
        toDecimals: swap.toDecimals!,
        toSymbol: swap.toSymbol!);
  }
}
