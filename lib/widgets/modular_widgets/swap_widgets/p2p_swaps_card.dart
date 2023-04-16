import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/p2p_swaps_list_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/swap_widgets/p2p_swaps_list_item2.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';

class P2pSwapsCard extends StatefulWidget {
  final VoidCallback onStepperNotificationSeeMorePressed;

  const P2pSwapsCard({
    required this.onStepperNotificationSeeMorePressed,
    Key? key,
  }) : super(key: key);

  @override
  _P2pSwapsCardState createState() => _P2pSwapsCardState();
}

class _P2pSwapsCardState extends State<P2pSwapsCard> {
  final ScrollController _scrollController = ScrollController();
  final P2pSwapsListBloc _p2pSwapsListBloc = P2pSwapsListBloc();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold<List<P2pSwap>>(
        title: 'P2P Swaps',
        childStream: _p2pSwapsListBloc.stream,
        onCompletedStatusCallback: (data) => _getTable(data),
        onRefreshPressed: () => _p2pSwapsListBloc.getSwaps(),
        //TODO: Update description
        description:
            'This card displays a list of swaps that have been created '
            'by or added to this wallet.\n '
            'Once a swap has been reclaimed or unlocked, it will '
            'be removed from the list. ');
  }

  Widget _getTable(List<P2pSwap> swaps) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.separated(
                  controller: _scrollController,
                  cacheExtent: 10000,
                  itemCount: swaps.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(
                      height: 15.0,
                    );
                  },
                  itemBuilder: (_, index) {
                    return P2pSwapsListItem2(
                      key: ValueKey(swaps.elementAt(index).id),
                      swap: swaps.elementAt(index),
                    );
                  }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
