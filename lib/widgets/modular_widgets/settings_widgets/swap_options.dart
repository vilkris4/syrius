import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/loading_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_expandable_panel.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';

class SwapOptions extends StatefulWidget {
  final VoidCallback onResyncWalletPressed;

  const SwapOptions(this.onResyncWalletPressed, {Key? key}) : super(key: key);

  @override
  _SwapOptionsState createState() => _SwapOptionsState();
}

class _SwapOptionsState extends State<SwapOptions> {
  final GlobalKey<LoadingButtonState> _atomicUnlocksButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _autoReclaimButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return CardScaffold(
      title: 'Swap Options',
      description: 'Atomic Swap options',
      childBuilder: () => _getWidgetBody(),
    );
  }

  Widget _getWidgetBody() {
    return ListView(
      shrinkWrap: true,
      children: [
        CustomExpandablePanel(
            'Atomic Unlocking', _getAtomicUnlocksExpandedWidget()),
        CustomExpandablePanel(
            'Automatic Reclaiming', _getAutoReclaimExpandedWidget()),
      ],
    );
  }

  Column _getAtomicUnlocksExpandedWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'This option will automatically unlock swaps that have been initiated by the counterparty, as long as they have proxy-unlocking enabled.',
          style: Theme.of(context).textTheme.subtitle2,
        ),
        kVerticalSpacing,
        _getAtomicUnlocksButton(),
        kVerticalSpacing,
      ],
    );
  }

  Widget _getAtomicUnlocksButton() {
    bool currentSetting = sharedPrefsService!.get(
      kP2pAtomicUnlockKey,
      defaultValue: true,
    );
    String buttonText = currentSetting ? 'Disable' : 'Enable';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: LoadingButton.settings(
            text: buttonText,
            onPressed: () => _onAtomicUnlocksButtonPressed(currentSetting),
            key: _atomicUnlocksButtonKey,
          ),
        ),
      ],
    );
  }

  void _onAtomicUnlocksButtonPressed(bool currentSetting) {
    try {
      _atomicUnlocksButtonKey.currentState!.animateForward();
      sharedPrefsService!.put(
        kP2pAtomicUnlockKey,
        !currentSetting,
      );
      String message =
          currentSetting ? 'Atomic unlocks disabled' : 'Atomic unlocks enabled';
      sl.get<NotificationsBloc>().addNotification(
            WalletNotification(
              title: 'Atomic unlocks mode changed',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              details: message,
              type: NotificationType.paymentSent,
            ),
          );
    } catch (e) {
      NotificationUtils.sendNotificationError(
          e, 'Atomic unlocks mode change failed');
    } finally {
      _atomicUnlocksButtonKey.currentState!.animateReverse();
    }
  }

  Widget _getAutoReclaimExpandedWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This option will automatically reclaim swaps that have expired.',
          style: Theme.of(context).textTheme.subtitle2,
        ),
        kVerticalSpacing,
        _getAutoReclaimButton(),
        kVerticalSpacing,
      ],
    );
  }

  Widget _getAutoReclaimButton() {
    bool currentSetting = sharedPrefsService!.get(
      kP2pAutoReclaimKey,
      defaultValue: false,
    );
    String buttonText = currentSetting ? 'Disable' : 'Enable';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: LoadingButton.settings(
            text: buttonText,
            onPressed: () => _onAutoReclaimButtonPressed(currentSetting),
            key: _autoReclaimButtonKey,
          ),
        ),
      ],
    );
  }

  void _onAutoReclaimButtonPressed(bool currentSetting) {
    try {
      _autoReclaimButtonKey.currentState!.animateForward();
      sharedPrefsService!.put(
        kP2pAutoReclaimKey,
        !currentSetting,
      );
      String message = currentSetting
          ? 'Automatic reclaiming disabled'
          : 'Automatic reclaiming enabled';
      sl.get<NotificationsBloc>().addNotification(
            WalletNotification(
              title: 'Automatic reclaim mode changed',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              details: message,
              type: NotificationType.paymentSent,
            ),
          );
    } catch (e) {
      NotificationUtils.sendNotificationError(
          e, 'Automatic reclaim mode change failed');
    } finally {
      _autoReclaimButtonKey.currentState!.animateReverse();
    }
  }
}
