import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hive/hive.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/create_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/reclaim_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/unlock_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/deposit_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/unlock_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/info_item_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ActiveSwapsListItem extends StatefulWidget {
  final HtlcInfo? htlcInfo;
  final bool getCurrentStatus;
  final VoidCallback onStepperNotificationSeeMorePressed;

  const ActiveSwapsListItem({
    Key? key,
    required this.htlcInfo,
    required this.getCurrentStatus,
    required this.onStepperNotificationSeeMorePressed,
  }) : super(key: key);

  @override
  _ActiveSwapsListItemState createState() => _ActiveSwapsListItemState();
}

class _ActiveSwapsListItemState extends State<ActiveSwapsListItem> {
  int _currentTime = ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();

  final TextEditingController _secretController = TextEditingController();
  final GlobalKey<FormState> _secretKey = GlobalKey();

  bool _depositing = false;
  bool _reclaiming = false;
  bool _unlocking = false;
  bool _depositAvailable = false;
  bool _isExpired = false;
  bool _isPending = false;
  bool? _recipientIsSelf;
  bool? _senderIsSelf;

  Token? token;
  Future? getToken;
  String? preimage;
  HtlcInfo? _htlc;
  String? _swapStatus;
  bool? _isActive;

  @override
  void initState() {
    super.initState();
    _setVariables();
    getToken = _getToken(_htlc!.tokenStandard);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!,
      child: (token == null) ? _getFutureBuilder() : _swapItem(context),
    );
  }

  Widget _getFutureBuilder() {
    return FutureBuilder(
      future: getToken,
      builder: (context, snapshot) {
        if (snapshot.hasData && mounted) {
          return _swapItem(context);
        } else if (snapshot.hasError) {
          return SyriusErrorWidget(snapshot.error!);
        }
        return Container();
      },
    );
  }

  Stream<int> _updateCurrentTime() async* {
    while (true && mounted && !_isExpired) {
      setState(() {
        _currentTime = ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
      });
      yield _currentTime;
      if (_currentTime >= _htlc!.expirationTime) {
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<Token> _getToken(TokenStandard tokenStandard) async {
    Token _token = (await zenon!.embedded.token.getByZts(tokenStandard))!;
    setState(() {
      token = _token;
    });
    return _token;
  }

  Widget _swapItem(BuildContext context) {
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _getHeader(context),
              const SizedBox(
                height: 10.0,
              ),
              Row(children: [
                _getHashType(context),
                StreamBuilder(
                    stream: _updateCurrentTime(),
                    builder: (context, snapshot) {
                      return _getHtlcExpirationTime(context);
                    }),
              ]),
            ]),
            const SizedBox(
              height: 10.0,
            ),
            const Spacer(),
            FutureBuilder(
              future: _setVariables(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _getAllButtons(context);
                } else if (snapshot.hasError) {
                  return SyriusErrorWidget(snapshot.error!);
                }
                return Container();
              },
            ),
          ]),
          const SizedBox(
            height: 20.0,
          ),
          Row(children: [
            InfoItemWidget(
              id: "Deposit ID",
              value: (_htlc!.id.toString()),
            ),
            const SizedBox(
              width: 10.0,
            ),
            InfoItemWidget(
              id: "Hashlock",
              value: FormatUtils.encodeHexString((_htlc!.hashLock)!).toString(),
            ),
            const SizedBox(
              width: 10.0,
            ),
            (_recipientIsSelf == true)
                ? InfoItemWidget(
                    id: "Sender",
                    value: _htlc!.timeLocked.toString(),
                  )
                : InfoItemWidget(
                    id: "Recipient",
                    value: _htlc!.hashLocked.toString(),
                  ),
            const SizedBox(
              width: 10.0,
            ),
            _getKeyWidget(),
          ]),
        ],
      ),
    );
  }

  Widget _getHeader(BuildContext context) {
    return Row(children: [
      Text(
        "${FormatUtils.formatAtomicSwapAmount(_htlc!.amount, _htlc!.tokenStandard)} ${token!.symbol}",
        style: Theme.of(context).textTheme.headline5,
      ),
      Text(
        "  ●",
        style: Theme.of(context).textTheme.headline5!.copyWith(
              color: ColorUtils.getTokenColor(_htlc!.tokenStandard),
            ),
      ),
    ]);
  }

  Widget _getHashType(BuildContext context) {
    String _text = "";
    if (_htlc!.hashType == 1) {
      _text = "SHA-256    ●    ";
    }

    return SizedBox(
      height: 20,
      child: Text(
        _text,
        style: Theme.of(context).textTheme.subtitle1,
      ),
    );
  }

  Widget _getHtlcExpirationTime(BuildContext context) {
    if (widget.getCurrentStatus && _swapStatus == null) {
      return SizedBox(
        height: 20,
        child: Row(
          children: [
            const SyriusLoadingWidget(
              size: 12.0,
              strokeWidth: 1.0,
            ),
            Text(
              "   Retrieving current status...",
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      );
    }

    if (widget.getCurrentStatus && _swapStatus != "") {
      return SizedBox(
        height: 20,
        child: Text(
          _swapStatus!,
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }

    if (_reclaiming || _unlocking) {
      return SizedBox(
        height: 20,
        child: Row(
          children: [
            const SyriusLoadingWidget(
              size: 12.0,
              strokeWidth: 1.0,
            ),
            Text(
              "   Unlocking deposit...",
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      );
    }

    if (_htlc!.id.toString() == "0" * 64 || _depositing) {
      return SizedBox(
        height: 20,
        child: Row(
          children: [
            const SyriusLoadingWidget(
              size: 12.0,
              strokeWidth: 1.0,
            ),
            Text(
              "   Locking deposit...",
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      );
    }

    String _expired = "Swap has expired";
    if (_isExpired && !_senderIsSelf!) {
      _expired += ", waiting for counterparty to reclaim";
      // Remove it from our active list
      sl.get<ActiveSwapsWorker>().removeSwap(_htlc!.id);
    }

    int _remainingTime = _htlc!.expirationTime - _currentTime;
    String _text = (_remainingTime > 0)
        ? "Expires in ${FormatUtils.formatExpirationTime(_remainingTime)}"
        : _expired;

    if (_remainingTime <= 0) {
      _isExpired = true;
    }

    return SizedBox(
      height: 20,
      child: Text(
        _text,
        style: Theme.of(context).textTheme.subtitle1,
      ),
    );
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
        color: (_recipientIsSelf == true)
            ? AppColors.znnColor.withOpacity(0.1)
            : AppColors.qsrColor.withOpacity(0.1),
      ),
      alignment: Alignment.center,
      child: Icon(
        (_recipientIsSelf == true) ? AntDesign.arrowdown : AntDesign.arrowup,
        color: (_recipientIsSelf == true)
            ? AppColors.znnColor
            : AppColors.qsrColor,
        size: 25,
      ),
    );
  }

  Widget _getKeyWidget() {
    if (preimage == null) {
      _getPreimage();
    }
    return Visibility(
      visible: preimage != "",
      child: InfoItemWidget(
        id: "Secret",
        value: preimage!,
      ),
    );
  }

  Widget _getAllButtons(BuildContext context) {
    return (_isActive == null)
        ? FutureBuilder<bool>(
            future: _getCurrentStatus(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!) {
                return Visibility(
                  visible: !_isPending,
                  child: Visibility(
                    child: _isExpired && _senderIsSelf!
                        ? _getReclaimButtonViewModel()
                        : Visibility(
                            visible: !_isExpired && _recipientIsSelf!,
                            child: _depositAvailable
                                ? Row(children: [
                                    _getDepositButtonViewModel(),
                                    const SizedBox(
                                      width: 10.0,
                                    ),
                                    _getUnlockButtonViewModel(),
                                  ])
                                : _getUnlockButtonViewModel(),
                          ),
                  ),
                );
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }
              return const SyriusLoadingWidget();
            },
          )
        : (_isActive!)
            ? Visibility(
                visible: !_isPending, //!_isPending,
                child: Visibility(
                  child: _isExpired && _senderIsSelf!
                      ? _getReclaimButtonViewModel()
                      : Visibility(
                          visible: !_isExpired && _recipientIsSelf!,
                          child: _depositAvailable
                              ? Row(children: [
                                  _getDepositButtonViewModel(),
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  _getUnlockButtonViewModel(),
                                ])
                              : _getUnlockButtonViewModel(),
                        ),
                ),
              )
            : Container();
  }

  Future<bool> _getCurrentStatus() async {
    //return true if swap is still active (displays default buttons)
    //return false if swap has been claimed or unlocked

    if (widget.getCurrentStatus) {
      Map _status =
          await sl.get<ActiveSwapsWorker>().evaluateSwapStatus(_htlc!.id);

      String _swapAction = _status.entries.first.key;
      String _preimage = _status.entries.first.value;

      if (_swapAction == "UnlockHtlc") {
        _swapStatus = "Swap has been unlocked";
        preimage = _preimage;
        _isActive = false;
      } else if (_swapAction == "ReclaimHtlc") {
        _swapStatus = "Swap has been reclaimed";
        _isActive = false;
      } else {
        _swapStatus = (_isExpired) ? "Swap is expired" : "";
        _isActive = (_isExpired) ? false : true;
      }
    }

    return true;
  }

  Widget _getReclaimButtonViewModel() {
    return ViewModelBuilder<ReclaimHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //_sendConfirmationNotification();
              print("reclaim successful!");
            }
          },
          onError: (error) {
            //_sendPaymentButtonKey.currentState?.animateReverse();
            setState(() {
              _reclaiming = false;
            });
            //_sendErrorNotification(error);
            print("reclaim error");
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              (!_reclaiming) ? _reclaimSwap(model) : null;
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
                  "Reclaim",
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
      _reclaiming = true;
    });
    model.reclaimHtlc(
      id: _htlc!.id,
      timeLocked: _htlc!.timeLocked,
    );
  }

  Widget _getDepositButtonViewModel() {
    return ViewModelBuilder<CreateHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //_sendConfirmationNotification();
              print("deposit successful!");
            }
          },
          onError: (error) {
            //_sendPaymentButtonKey.currentState?.animateReverse();
            setState(() {
              _depositing = false;
            });
            //_sendErrorNotification(error);
            print("deposit error");
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              _onDepositButtonPressed(model);
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
                  "Make Deposit",
                  style: Theme.of(context).textTheme.headline6,
                ),
              ],
            ),
          )),
      viewModelBuilder: () => CreateHtlcBloc(),
    );
  }

  void _onDepositButtonPressed(CreateHtlcBloc model) {
    showDepositDialog(
      context: context,
      title: 'Make Deposit',
      htlc: _htlc!,
      token: token!,
      controller: _secretController,
      key: _secretKey,
      onDepositButtonPressed: () {
        _depositFunds(model);
        setState(() {
          _depositing = true;
        });
        //_sendUnlockHtlcBlock();
        //_sendSwapBlock();
        Navigator.pop(context);
      },
    );
  }

  void _depositFunds(CreateHtlcBloc model) {
    //Navigator.pop(context);
    //_sendPaymentButtonKey.currentState?.animateForward();
    model.createHtlc(
      timeLocked: _htlc!.hashLocked,
      token: token!,
      amount: "10",
      //_amountController.text, //TODO: change to amount
      hashLocked: _htlc!.timeLocked,
      expirationTime: _htlc!.expirationTime,
      hashType: _htlc!.hashType,
      keyMaxSize: _htlc!.keyMaxSize,
      hashLock: (_htlc!.hashLock)!,
    );
  }

  Widget _getUnlockButtonViewModel() {
    return ViewModelBuilder<UnlockHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is AccountBlockTemplate) {
              //_sendConfirmationNotification();
              print("unlock successful!");
            }
          },
          onError: (error) {
            //_sendPaymentButtonKey.currentState?.animateReverse();
            setState(() {
              _unlocking = false;
            });
            //_sendErrorNotification(error);
            print("unlock error");
          },
        );
      },
      builder: (_, model, __) => SizedBox(
          width: 135,
          child: ElevatedButton(
            onPressed: () {
              _onUnlockButtonPressed(model);
            },
            style: ButtonStyle(
              backgroundColor: _depositAvailable
                  ? MaterialStateProperty.all(AppColors.darkSecondary)
                  : MaterialStateProperty.all(AppColors.znnColor),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Unlock",
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      ?.copyWith(color: AppColors.backgroundLight),
                ),
                //),
              ],
            ),
          )),
      viewModelBuilder: () => UnlockHtlcBloc(),
    );
  }

  void _onUnlockButtonPressed(UnlockHtlcBloc model) {
    showUnlockDialog(
      context: context,
      title: 'Unlock Deposit',
      htlc: _htlc!,
      token: token!,
      description: 'Are you sure you want to unlock ${_htlc!.id} ?',
      controller: _secretController,
      key: _secretKey,
      preimage: preimage,
      onUnlockButtonPressed: () {
        setState(() {
          _unlocking = true;
        });
        _unlockSwap(model);
        //_sendUnlockHtlcBlock();
        //_sendSwapBlock();
        Navigator.pop(context);
      },
    );
  }

  void _unlockSwap(UnlockHtlcBloc model) {
    model.unlockHtlc(
      id: _htlc!.id,
      preimage: _secretController.text,
      hashLocked: _htlc!.hashLocked,
    );
  }

  // Returns true if a swap is eligible for a deposit
  // Then displays the "Deposit" button
  bool _getDepositAvailable(Hash _id, List<int> _hashLock) {
    for (var swap in sl.get<ActiveSwapsWorker>().cachedSwaps) {
      if (Hash.fromBytes(swap.hashLock!).equals(Hash.fromBytes(_hashLock)) &&
          swap.id != _id) {
        //print("_getDepositAvailable: swap id: ${swap.id}");
        return false;
      }
    }
    return true;
  }

  void _getPreimage() {
    if (preimage == null) {
      Box _activeSwapsBox = Hive.box(kHtlcActiveSwapsBox);
      List createdSwapsList = _activeSwapsBox.get(
            kHtlcCreatedSwapsKey,
            defaultValue: [],
          ) ??
          [];
      for (var i = 0; i < createdSwapsList.length; i++) {
        createdSwapsList[i].forEach((_swap, _preimage) {
          _swap = jsonDecode(_swap);
          HtlcInfo _createdSwap = HtlcInfo.fromJson(_swap);
          if (_createdSwap.id.toString() == "0" * 64) {
            if (_createdSwap.amount == _htlc!.amount &&
                _createdSwap.expirationTime == _htlc!.expirationTime &&
                _createdSwap.hashLocked == _htlc!.hashLocked &&
                Hash.fromBytes((_createdSwap.hashLock)!) ==
                    Hash.fromBytes((_htlc!.hashLock)!) &&
                _createdSwap.hashType == _htlc!.hashType &&
                _createdSwap.keyMaxSize == _htlc!.keyMaxSize &&
                _createdSwap.tokenStandard == _htlc!.tokenStandard &&
                _createdSwap.timeLocked == _htlc!.timeLocked) {
              preimage = _preimage;
            }
          } else if (_createdSwap.id == _htlc!.id) {
            preimage = _preimage;
          }
        });
      }

      preimage ??= "";
    }
  }

  Future<bool> _setVariables() async {
    _htlc = widget.htlcInfo;
    _recipientIsSelf =
        kDefaultAddressList.contains(_htlc!.hashLocked.toString());
    _senderIsSelf = kDefaultAddressList.contains(_htlc!.timeLocked.toString());
    _isPending = (_htlc!.id == Hash.parse("0" * 64));
    _depositAvailable = _getDepositAvailable(_htlc!.id, (_htlc!.hashLock)!);
    return true;
  }
}
