import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/p2p_swaps_list_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/native_p2p_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/p2p_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/dialogs.dart';
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

  bool _isListScrolled = false;

  @override
  void initState() {
    super.initState();
    _p2pSwapsListBloc.getDataPeriodically();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 0 && !_isListScrolled) {
        setState(() {
          _isListScrolled = true;
        });
      } else if (_scrollController.position.pixels == 0) {
        setState(() {
          _isListScrolled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold<List<P2pSwap>>(
        title: 'P2P Swaps',
        childStream: _p2pSwapsListBloc.stream,
        onCompletedStatusCallback: (data) => _getTable(data),
        onRefreshPressed: () => _p2pSwapsListBloc.getSwaps(),
        description:
            'This card displays a list of P2P swaps that have been created '
            'by or added to this wallet.');
  }

  void _onSwapTapped(String swapId) {
    showCustomDialog(
      context: context,
      content: NativeP2pSwapModal(
        swapId: swapId,
      ),
    );
  }

  Future<void> _onDeleteSwapTapped(P2pSwap swap) async {
    if (swap.mode == P2pSwapMode.htlc) {
      await htlcSwapsService!.deleteSwap(swap.id);
      _p2pSwapsListBloc.getSwaps();
    }
  }

  Widget _getTable(List<P2pSwap> swaps) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          _getHeader(),
          const SizedBox(
            height: 15.0,
          ),
          Visibility(
            visible: _isListScrolled,
            child: const Divider(),
          ),
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
                    return P2pSwapsListItem(
                      key: ValueKey(swaps.elementAt(index).id),
                      swap: swaps.elementAt(index),
                      onTap: _onSwapTapped,
                      onDelete: _onDeleteSwapTapped,
                    );
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: _getHeaderItem('Status'),
          ),
          Expanded(
            flex: 20,
            child: _getHeaderItem('Sent'),
          ),
          Expanded(
            flex: 20,
            child: _getHeaderItem('Received'),
          ),
          Expanded(
            flex: 20,
            child: _getHeaderItem('Started'),
          ),
          const Spacer(
            flex: 20,
          ),
        ],
      ),
    );
  }

  Widget _getHeaderItem(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.0),
    );
  }
}
