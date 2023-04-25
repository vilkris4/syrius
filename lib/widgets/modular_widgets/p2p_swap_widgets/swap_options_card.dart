import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/join_native_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/native_p2p_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/start_native_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/swap_options_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';

class SwapOptionsCard extends StatefulWidget {
  const SwapOptionsCard({
    Key? key,
  }) : super(key: key);

  @override
  State<SwapOptionsCard> createState() => _SwapOptionsCardState();
}

class _SwapOptionsCardState extends State<SwapOptionsCard> {
  bool _isSwapTutorialHovered = false;

  @override
  void initState() {
    super.initState();
  }

  //TODO: Confirm CardScaffold description
  @override
  Widget build(BuildContext context) {
    return CardScaffold(
      title: 'Swap Options',
      description: 'update this text',
      childBuilder: () => _getWidgetBody(context),
    );
  }

  Widget _getWidgetBody(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      child: _getNativeOptions(),
    );
  }

  void _showNativeSwapModal(String swapId) {
    Navigator.pop(context);
    Timer.run(
      () => showCustomDialog(
        context: context,
        content: NativeP2pSwapModal(
          swapId: swapId,
        ),
      ),
    );
  }

  Column _getNativeOptions() {
    return Column(
      children: [
        SwapOptionsButton(
          primaryText: 'Start swap',
          secondaryText: 'Start a native swap with a counterparty.',
          onClick: () => showCustomDialog(
            context: context,
            content: StartNativeSwapModal(onSwapStarted: _showNativeSwapModal),
          ),
        ),
        const SizedBox(
          height: 25.0,
        ),
        SwapOptionsButton(
          primaryText: 'Join swap',
          secondaryText: 'Join a native swap started by a counterparty.',
          onClick: () => showCustomDialog(
            context: context,
            content: JoinNativeSwapModal(onJoinedSwap: _showNativeSwapModal),
          ),
        ),
        const SizedBox(
          height: 40.0,
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isSwapTutorialHovered = true),
          onExit: (_) => setState(() => _isSwapTutorialHovered = false),
          child: GestureDetector(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View swap tutorial',
                  style: TextStyle(
                    color: _isSwapTutorialHovered
                        ? Colors.white
                        : AppColors.subtitleColor,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(
                  width: 3.0,
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18.0,
                  color: _isSwapTutorialHovered
                      ? Colors.white
                      : AppColors.subtitleColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
