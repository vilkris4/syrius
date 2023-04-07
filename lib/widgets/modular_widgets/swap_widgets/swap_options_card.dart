import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/swap_options_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/swap_dialogs/initiate_swap_dialog.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';

class SwapOptionsCard extends StatefulWidget {
  const SwapOptionsCard({
    Key? key,
  }) : super(key: key);

  @override
  State<SwapOptionsCard> createState() => _SwapOptionsCardState();
}

class _SwapOptionsCardState extends State<SwapOptionsCard> {
  bool isSwapTutorialHovered = false;

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

  Column _getNativeOptions() {
    return Column(
      children: [
        SwapOptionsButton(
          primaryText: 'Start swap',
          secondaryText: 'Start a native swap with a counterparty.',
          onClick: () {
            showInitiateSwapDialog(context: context);
          },
        ),
        const SizedBox(
          height: 25.0,
        ),
        SwapOptionsButton(
          primaryText: 'Join swap',
          secondaryText: 'Join a native swap started by a counterparty.',
          onClick: () {
            print('Join swap');
          },
        ),
        const SizedBox(
          height: 40.0,
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (details) => setState(() => isSwapTutorialHovered = true),
          onExit: (details) => setState(() => isSwapTutorialHovered = false),
          child: GestureDetector(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View swap tutorial',
                  style: TextStyle(
                    color: isSwapTutorialHovered
                        ? Colors.white
                        : AppColors.subtitleColor,
                    fontSize: 14.0,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18.0,
                  color: isSwapTutorialHovered
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

  @override
  void dispose() {
    super.dispose();
  }
}
