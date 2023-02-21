// TODO: Hide expired GetByID swaps?? Confirm with Vilkris

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hive/hive.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/create_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/reclaim_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/unlock_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/deposit_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/unlock_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/htlc_status_details.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/info_item_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ActiveSwapsListItem extends StatefulWidget {
  final HtlcInfo? htlcInfo;
  final VoidCallback onStepperNotificationSeeMorePressed;

  const ActiveSwapsListItem({
    Key? key,
    required this.htlcInfo,
    required this.onStepperNotificationSeeMorePressed,
  }) : super(key: key);

  @override
  _ActiveSwapsListItemState createState() => _ActiveSwapsListItemState();
}

class _ActiveSwapsListItemState extends State<ActiveSwapsListItem> {
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _depositAmountController =
      TextEditingController();
  final GlobalKey<FormState> _secretKey = GlobalKey();
  final GlobalKey<FormState> _depositAmountKey = GlobalKey();

  late final Future<Token?> _tokenFuture;
  late final Future<bool?> _proxyUnlockFuture;
  late final Future<List> _futures;

  StreamSubscription? _expirationSubscription;
  StreamSubscription? _pendingIdSubscription;
  StreamSubscription? _autoUnlockSubscription;

  bool _isReclaiming = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _tokenFuture =
        zenon!.embedded.token.getByZts(widget.htlcInfo!.tokenStandard);
    _proxyUnlockFuture = zenon!.embedded.htlc
        .getHtlcProxyUnlockStatus(widget.htlcInfo!.hashLocked);
    _futures = Future.wait([_tokenFuture, _proxyUnlockFuture]);

    if (_isSwapInProgress()) {
      _expirationSubscription =
          Stream.periodic(const Duration(seconds: 1)).listen((_) {
        if (!_isSwapInProgress()) {
          _expirationSubscription?.cancel();
          // NOTE (vilkris): Is this necessary?
          // sl.get<ActiveSwapsWorker>().removeSwap(widget.htlcInfo!.id);
          setState(() {});
        }
      });
    } else {
      if (_isIncomingDeposit()) {
        sl.get<ActiveSwapsWorker>().removeSwap(widget.htlcInfo!.id);
      }
    }

    // TODO (vilkris): This is only a temporary solution
    if (!_hasDepositId()) {
      _pendingIdSubscription =
          Stream.periodic(const Duration(seconds: 5)).listen((_) {
        if (_hasDepositId()) {
          _pendingIdSubscription?.cancel();
          setState(() {});
        }
      });
    }

    if (_isSwapInProgress()) {
      _autoUnlockSubscription =
          Stream.periodic(const Duration(seconds: 1)).listen((_) {
        if (sl
            .get<ActiveSwapsWorker>()
            .autoUnlockedSwaps
            .contains(widget.htlcInfo!.id)) {
          _autoUnlockSubscription?.cancel();
          setState(() {
            _isUnlocking = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _expirationSubscription?.cancel();
    _pendingIdSubscription?.cancel();
    _autoUnlockSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!,
      child: FutureBuilder<List>(
        future: _futures,
        builder: (_, snapshot) {
          if (snapshot.hasData && mounted) {
            return _getSwapItem(context, snapshot.data![0], snapshot.data![1]);
          } else if (snapshot.hasError) {
            return SyriusErrorWidget(snapshot.error!);
          }
          return Container();
        },
      ),
    );
  }

  Widget _getSwapItem(BuildContext context, Token token, bool canProxyUnlock) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0.0, 4),
            blurRadius: 6,
          ),
        ],
        borderRadius: BorderRadius.circular(
          8.0,
        ),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Column(
        children: [
          Row(children: [
            _getArrow(context),
            const SizedBox(
              width: 20.0,
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _getHeader(context, token),
                  const SizedBox(
                    height: 6.0,
                  ),
                  _getStatusDetails(),
                ]),
            const SizedBox(
              height: 10.0,
            ),
            const Spacer(),
            _getButtons(token, canProxyUnlock),
          ]),
          const SizedBox(
            height: 20.0,
          ),
          _getInfoItems(),
        ],
      ),
    );
  }

  Widget _getHeader(BuildContext context, Token token) {
    return Row(children: [
      Text(
        '${FormatUtils.formatAtomicSwapAmount(widget.htlcInfo!.amount, token)} ${token.symbol}',
        style: Theme.of(context).textTheme.headline5,
      ),
      Text(
        '  ●',
        style: Theme.of(context).textTheme.headline5!.copyWith(
              color: ColorUtils.getTokenColor(widget.htlcInfo!.tokenStandard),
            ),
      ),
    ]);
  }

  Widget _getArrow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 15.0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          6.0,
        ),
        color: _isIncomingDeposit()
            ? AppColors.znnColor.withOpacity(0.1)
            : AppColors.qsrColor.withOpacity(0.1),
      ),
      alignment: Alignment.center,
      child: Icon(
        _isIncomingDeposit() ? AntDesign.arrowdown : AntDesign.arrowup,
        color: _isIncomingDeposit() ? AppColors.znnColor : AppColors.qsrColor,
        size: 25,
      ),
    );
  }

  Widget _getStatusDetails() {
    HtlcDetailsStatus status = HtlcDetailsStatus.expired;
    if (!_hasDepositId()) {
      status = HtlcDetailsStatus.locking;
    } else if (_isUnlocking) {
      status = HtlcDetailsStatus.unlocking;
    } else if (_isReclaiming) {
      status = HtlcDetailsStatus.reclaiming;
    } else if (_isSwapInProgress()) {
      status = HtlcDetailsStatus.inProgress;
    }
    return HtlcStatusDetails(
      hashType: widget.htlcInfo!.hashType,
      expirationTime: widget.htlcInfo!.expirationTime,
      status: status,
    );
  }

  Widget _getInfoItems() {
    final hasId = widget.htlcInfo!.id.toString() != '0' * 64;
    final preimage = _getPreimage();
    final multiplier = preimage.isEmpty ? 0.18 : 0.139;
    double itemWidth = MediaQuery.of(context).size.width * multiplier;
    itemWidth = itemWidth > 240.0 ? 240.0 : itemWidth;
    final List<Widget> children = [];
    children.addAll([
      InfoItemWidget(
        label: 'Deposit ID',
        value: hasId ? widget.htlcInfo!.id.toString() : 'Pending...',
        width: itemWidth,
        canBeCopied: hasId,
        truncateValue: hasId,
      ),
      InfoItemWidget(
        label: 'Hashlock',
        value: FormatUtils.encodeHexString((widget.htlcInfo!.hashLock)!)
            .toString(),
        width: itemWidth,
      ),
      _isIncomingDeposit()
          ? InfoItemWidget(
              label: 'Sender',
              value: widget.htlcInfo!.timeLocked.toString(),
              width: itemWidth,
            )
          : InfoItemWidget(
              label: 'Recipient',
              value: widget.htlcInfo!.hashLocked.toString(),
              width: itemWidth,
            ),
    ]);
    if (preimage.isNotEmpty) {
      children.add(
        InfoItemWidget(
          label: 'Secret',
          value: preimage,
          width: itemWidth,
        ),
      );
    }
    return Row(
      children: children.zip(
        List.generate(
          children.length - 1,
          (index) => const SizedBox(
            width: 10.0,
          ),
        ),
      ),
    );
  }

  Widget _getButtons(Token token, bool canProxyUnlock) {
    final List<Widget> buttons = [];
    if (_isSwapInProgress() && !_isUnlocking) {
      if (_canMakeCounterDeposit() && _isIncomingDeposit()) {
        buttons.add(_getDepositButtonViewModel(token));
        buttons.add(_getUnlockButtonViewModel(token, canProxyUnlock));
      } else if (_isIncomingDeposit() ||
          (canProxyUnlock && !_isOutgoingDeposit())) {
        buttons.add(_getUnlockButtonViewModel(token, canProxyUnlock));
      }
    }
    if (_isSwapExpired() && _isOutgoingDeposit() && !_isReclaiming) {
      buttons.add(_getReclaimButtonViewModel());
    }
    return Row(
      children: buttons.zip(
        List.generate(
          buttons.isEmpty ? 0 : buttons.length - 1,
          (index) => const SizedBox(
            width: 10.0,
          ),
        ),
      ),
    );
  }

  Widget _getReclaimButtonViewModel() {
    return ViewModelBuilder<ReclaimHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //TODO: confirmation notification
              //_sendConfirmationNotification();
            }
          },
          onError: (error) {
            setState(() {
              _isReclaiming = false;
            });
            //TODO: error notification
            //_sendErrorNotification(error);
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              (!_isReclaiming) ? _reclaimSwap(model) : null;
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(AppColors.znnColor),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Reclaim',
                  style: Theme.of(context).textTheme.headline6,
                ),
              ],
            ),
          )),
      viewModelBuilder: () => ReclaimHtlcBloc(),
    );
  }

  void _reclaimSwap(ReclaimHtlcBloc model) {
    setState(() {
      _isReclaiming = true;
    });
    model.reclaimHtlc(
      id: widget.htlcInfo!.id,
      timeLocked: widget.htlcInfo!.timeLocked,
    );
  }

  Widget _getDepositButtonViewModel(Token token) {
    return ViewModelBuilder<CreateHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //TODO: confirmation notification
              //_sendConfirmationNotification();
            }
          },
          onError: (error) {
            //TODO: error notification
            //_sendErrorNotification(error);
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              _onDepositButtonPressed(model, token);
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(AppColors.znnColor),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Make Deposit',
                  style: Theme.of(context).textTheme.headline6,
                ),
              ],
            ),
          )),
      viewModelBuilder: () => CreateHtlcBloc(),
    );
  }

  void _onDepositButtonPressed(CreateHtlcBloc model, Token token) {
    showDepositDialog(
      context: context,
      title: 'Make Deposit',
      htlc: widget.htlcInfo!,
      token: token,
      controller: _depositAmountController,
      key: _depositAmountKey,
      onDepositButtonPressed: (_selectedToken) async {
        _depositFunds(model, _selectedToken);

        final json = '{"id": "${'0' * Hash.length * 2}",'
            '"timeLocked": "${widget.htlcInfo?.hashLocked}",'
            '"hashLocked": "${widget.htlcInfo?.timeLocked}",'
            '"tokenStandard": "${_selectedToken.tokenStandard}",'
            '"amount": ${AmountUtils.extractDecimals(double.parse(_depositAmountController.text), _selectedToken.decimals)},'
            '"expirationTime": ${widget.htlcInfo?.expirationTime},'
            '"hashType": ${widget.htlcInfo?.hashType},'
            '"keyMaxSize": ${widget.htlcInfo?.keyMaxSize},'
            '"hashLock": "${base64.encode((widget.htlcInfo?.hashLock)!)}"}';

        await sl.get<ActiveSwapsWorker>().addPendingSwap(json: json);
        setState(() {});
        Navigator.pop(context);
      },
    );
  }

  void _depositFunds(CreateHtlcBloc model, Token selectedToken) {
    model.createHtlc(
      timeLocked: widget.htlcInfo!.hashLocked,
      token: selectedToken,
      amount: _depositAmountController.text,
      hashLocked: widget.htlcInfo!.timeLocked,
      expirationTime: widget.htlcInfo!.expirationTime,
      hashType: widget.htlcInfo!.hashType,
      keyMaxSize: widget.htlcInfo!.keyMaxSize,
      hashLock: (widget.htlcInfo!.hashLock)!,
    );
  }

  Widget _getUnlockButtonViewModel(Token token, bool canProxyUnlock) {
    return ViewModelBuilder<UnlockHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //TODO: confirmation notification
              //_sendConfirmationNotification();
            }
          },
          onError: (error) {
            setState(() {
              _isUnlocking = false;
            });
            //TODO: error notification
            //_sendErrorNotification(error);
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              _onUnlockButtonPressed(model, token);
            },
            style: ButtonStyle(
              backgroundColor: _canMakeCounterDeposit()
                  ? MaterialStateProperty.all(AppColors.darkSecondary)
                  : _isIncomingDeposit() //(canProxyUnlock && !_isOutgoingDeposit())
                      ? MaterialStateProperty.all(AppColors.znnColor)
                      : MaterialStateProperty.all(AppColors.qsrColor),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unlock',
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      ?.copyWith(color: AppColors.backgroundLight),
                ),
              ],
            ),
          )),
      viewModelBuilder: () => UnlockHtlcBloc(),
    );
  }

  void _onUnlockButtonPressed(UnlockHtlcBloc model, Token token) {
    showUnlockDialog(
      context: context,
      title: 'Unlock Deposit',
      htlc: widget.htlcInfo!,
      token: token,
      description: 'Are you sure you want to unlock ${widget.htlcInfo!.id} ?',
      controller: _secretController,
      key: _secretKey,
      preimage: _getPreimage(),
      onUnlockButtonPressed: () {
        setState(() {
          _isUnlocking = true;
        });
        _unlockSwap(model);
        Navigator.pop(context);
      },
    );
  }

  void _unlockSwap(UnlockHtlcBloc model) {
    model.unlockHtlc(
      id: widget.htlcInfo!.id,
      preimage: _secretController.text,
      hashLocked: _isIncomingDeposit()
          ? widget.htlcInfo!.hashLocked
          : Address.parse(kSelectedAddress!),
    );
  }

  bool _hasDepositId() {
    return widget.htlcInfo!.id != Hash.parse('0' * Hash.length * 2);
  }

  bool _isSwapInProgress() {
    final remaining = widget.htlcInfo!.expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining > 0 && _hasDepositId();
  }

  bool _isSwapExpired() {
    final remaining = widget.htlcInfo!.expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining <= 0;
  }

  bool _isIncomingDeposit() {
    return kDefaultAddressList.contains(widget.htlcInfo!.hashLocked.toString());
  }

  bool _isOutgoingDeposit() {
    return kDefaultAddressList.contains(widget.htlcInfo!.timeLocked.toString());
  }

  bool _canMakeCounterDeposit() {
    // A counter deposit can be made if the deposit is incoming and the incoming
    // deposit isn't a counter deposit made by the counterparty.
    return _isIncomingDeposit() &&
        !sl.get<ActiveSwapsWorker>().cachedSwaps.any((e) =>
            Hash.fromBytes(e.hashLock!)
                .equals(Hash.fromBytes(widget.htlcInfo!.hashLock!)) &&
            e.id != widget.htlcInfo!.id);
  }

  String _getPreimage() {
    final activeSwapsBox = Hive.box(kHtlcActiveSwapsBox);
    List createdSwapsList = activeSwapsBox.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [],
        ) ??
        [];
    for (final swapMap in createdSwapsList) {
      for (MapEntry<dynamic, dynamic> swapAndPreimage in swapMap.entries) {
        final swap = swapAndPreimage.key;
        final preimage = swapAndPreimage.value;
        HtlcInfo createdSwap = HtlcInfo.fromJson(jsonDecode(swap));
        if (preimage != null &&
            preimage.isNotEmpty &&
            Hash.fromBytes((createdSwap.hashLock)!) ==
                Hash.fromBytes((widget.htlcInfo!.hashLock)!)) {
          return preimage;
        }
      }
    }
    return '';
  }
}
