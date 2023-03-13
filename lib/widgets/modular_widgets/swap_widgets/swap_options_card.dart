import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
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
  @override
  void initState() {
    super.initState();
  }

  //TODO: Confirm CardScaffold description
  @override
  Widget build(BuildContext context) {
    return CardScaffold(
      title: '  Swap Options',
      description: 'update this text',
      childBuilder: () => _getWidgetBody(context),
    );
  }

  Widget _getWidgetBody(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      child: _getOptions(),
    );
  }

  Column _getOptions() {
    return Column(
      children: [
        SwapOptionsButton(
          primaryText: 'Initiate swap',
          secondaryText: 'Initiate a P2P swap with a counter-party.',
          onClick: () {
            showInitiateSwapDialog(context: context);
          },
        ),
        kVerticalSpacing,
        SwapOptionsButton(
          primaryText: 'Participate in a swap',
          secondaryText:
              'Participate in a P2P swap initiated by a counterparty.',
          onClick: () {
            print('Participate in a swap');
          },
        ),
        kVerticalSpacing,
        SwapOptionsButton(
          primaryText: 'Retrieve swap (WIP)',
          secondaryText: 'WIP',
          onClick: () {
            print('WIP');
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
