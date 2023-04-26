import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/detail_row.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_info_text.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class HtlcCard extends StatefulWidget {
  final String title;
  final String? htlcId;
  final String? hashLock;
  final int? expirationTime;
  final String? recipient;
  final int? amount;
  final String? tokenStandard;
  final int? tokenDecimals;
  final String? tokenSymbol;

  const HtlcCard({
    required this.title,
    required this.htlcId,
    required this.hashLock,
    required this.expirationTime,
    required this.recipient,
    required this.amount,
    required this.tokenStandard,
    required this.tokenDecimals,
    required this.tokenSymbol,
    Key? key,
  }) : super(key: key);

  factory HtlcCard.sending({
    required HtlcSwap swap,
  }) =>
      HtlcCard(
        title: 'You are sending',
        htlcId: swap.direction == P2pSwapDirection.outgoing
            ? swap.initialHtlcId
            : swap.counterHtlcId,
        hashLock: swap.hashLock,
        expirationTime: swap.direction == P2pSwapDirection.outgoing
            ? swap.initialHtlcExpirationTime
            : swap.counterHtlcExpirationTime,
        recipient: swap.counterpartyAddress,
        amount: swap.fromAmount,
        tokenStandard: swap.fromTokenStandard,
        tokenDecimals: swap.fromDecimals,
        tokenSymbol: swap.fromSymbol,
      );

  factory HtlcCard.receiving({
    required HtlcSwap swap,
  }) =>
      HtlcCard(
        title: 'You are receiving',
        htlcId: swap.direction == P2pSwapDirection.outgoing
            ? swap.counterHtlcId
            : swap.initialHtlcId,
        hashLock: swap.hashLock,
        expirationTime: swap.direction == P2pSwapDirection.outgoing
            ? swap.counterHtlcExpirationTime
            : swap.initialHtlcExpirationTime,
        recipient: swap.selfAddress,
        amount: swap.toAmount,
        tokenStandard: swap.toTokenStandard,
        tokenDecimals: swap.toDecimals,
        tokenSymbol: swap.toSymbol,
      );

  factory HtlcCard.fromHtlcInfo({
    required String title,
    required HtlcInfo htlc,
    required Token token,
  }) =>
      HtlcCard(
        title: title,
        htlcId: htlc.id.toString(),
        hashLock: FormatUtils.encodeHexString(htlc.hashLock),
        expirationTime: htlc.expirationTime,
        recipient: htlc.hashLocked.toString(),
        amount: htlc.amount,
        tokenStandard: token.tokenStandard.toString(),
        tokenDecimals: token.decimals,
        tokenSymbol: token.symbol,
      );

  @override
  State<HtlcCard> createState() => _HtlcCardState();
}

class _HtlcCardState extends State<HtlcCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  final Duration _expirationWarningThreshold = const Duration(minutes: 60);
  final Duration _animationDuration = const Duration(milliseconds: 100);
  final Cubic _animationCurve = Curves.easeInOut;

  bool _areDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _animationDuration,
      curve: _animationCurve,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xff282828),
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        child: widget.htlcId == null ? _getWaitingBody() : _getWidgetBody(),
      ),
    );
  }

  Widget _getWidgetBody() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 14.0, color: AppColors.subtitleColor),
              ),
              _getExpirationWarning(widget.expirationTime!),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${widget.amount!.addDecimals(widget.tokenDecimals!)} ${widget.tokenSymbol!}',
                    style: const TextStyle(fontSize: 18.0),
                  ),
                  const SizedBox(
                    width: 8.0,
                  ),
                  Container(
                    height: 6.0,
                    width: 6.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorUtils.getTokenColor(
                          TokenStandard.parse(widget.tokenStandard!)),
                    ),
                  ),
                ],
              ),
              _getDetailsButton()
            ],
          ),
          _getDetailsSection(),
        ],
      ),
    );
  }

  Widget _getWaitingBody() {
    return const SizedBox(
      height: 94,
      child: LoadingInfoText(
        text: 'Waiting for the counterparty to join the swap.',
      ),
    );
  }

  Widget _getExpirationWarning(int expirationTime) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final remaining = Duration(seconds: expirationTime - now);
    return Visibility(
      visible: !remaining.isNegative && remaining < _expirationWarningThreshold,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorColor,
            size: 16.0,
          ),
          const SizedBox(
            width: 5.0,
          ),
          TweenAnimationBuilder<Duration>(
            duration: remaining,
            tween: Tween(begin: remaining, end: Duration.zero),
            onEnd: () => setState(() {}),
            builder: (_, Duration d, __) {
              return Text(
                'Expires in ${d.toString().split('.').first}',
                style: const TextStyle(
                  fontSize: 12.0,
                  color: AppColors.errorColor,
                  height: 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _getDetailsButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _areDetailsExpanded = !_areDetailsExpanded;
          _areDetailsExpanded
              ? _animationController.forward()
              : _animationController.reverse();
        });
      },
      child: RotationTransition(
        turns: Tween(begin: 0.0, end: 0.5).animate(_animationController),
        child: const Icon(Icons.keyboard_arrow_down, size: 22.0),
      ),
    );
  }

  Widget _getDetailsSection() {
    return AnimatedSize(
      duration: _animationDuration,
      curve: _animationCurve,
      child: Visibility(
        visible: _areDetailsExpanded,
        child: Column(
          children: [
            const SizedBox(height: 20.0),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 20.0),
            _getDetailsList(),
          ],
        ),
      ),
    );
  }

  Widget _getDetailsList() {
    final List<Widget> children = [];
    final htlcId = Hash.parse(widget.htlcId!);
    final hashLock = Hash.parse(widget.hashLock!);
    children.add(_getExpirationRow(widget.expirationTime!));
    children.add(
      DetailRow(
          label: 'Deposit ID',
          value: htlcId.toString(),
          valueToShow: htlcId.toShortString()),
    );
    children.add(
      DetailRow(label: 'Token standard', value: widget.tokenStandard!),
    );
    children.add(
      DetailRow(
          label: 'Recipient',
          value: widget.recipient!,
          valueToShow: _tryGetLabelForAddress(widget.recipient!)),
    );
    children.add(
      DetailRow(
          label: 'Hashlock',
          value: hashLock.toString(),
          valueToShow: hashLock.toShortString()),
    );
    return Column(
      children: children.zip(
        List.generate(
          children.length - 1,
          (index) => const SizedBox(
            height: 15.0,
          ),
        ),
      ),
    );
  }

  Widget _getExpirationRow(int expirationTime) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final duration = Duration(seconds: expirationTime - now);
    if (duration.isNegative) {
      return const DetailRow(
          label: 'Expires in', value: 'Expired', canBeCopied: false);
    }
    return TweenAnimationBuilder<Duration>(
      duration: duration,
      tween: Tween(begin: duration, end: Duration.zero),
      builder: (_, Duration d, __) {
        return DetailRow(
            label: 'Expires in',
            value: d.toString().split('.').first,
            canBeCopied: false);
      },
    );
  }

  String _tryGetLabelForAddress(String address) {
    return kDefaultAddressList.contains(address)
        ? kAddressLabelMap[address]!
        : address;
  }
}
