import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/swap_widgets/p2p_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

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

  final StreamController<List<HtlcInfo>> _streamController =
      StreamController<List<HtlcInfo>>.broadcast();
  StreamController<List<HtlcInfo>> get streamController => _streamController;

  Stream<List<HtlcInfo>> get dataStream => _streamController.stream;
  StreamSink<List<HtlcInfo>> get dataSink => _streamController.sink;

  @override
  void initState() {
    super.initState();
    streamController.stream.listen((event) {
      setState(() {
        //_filteredSwapList = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold(
        title: ' P2P Swaps',
        childBuilder: () => FutureBuilder<List<HtlcInfo>>(
              future: sl.get<P2pSwapsWorker>().getSavedSwaps(),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  // _activewapList = snapshot.data!;
                  // _filteredSwapList = _activewapList!;
                  return _getActiveSwapsList();
                } else if (snapshot.hasError) {
                  return const SyriusLoadingWidget();
                }
                return const SyriusLoadingWidget();
              },
            ),
        onRefreshPressed: () {
          //_searchKeyWordController.clear();
          //refreshResults();
          print("refresh??");
        },
        //TODO: Update description
        description:
            'This card displays a list of swaps that have been created '
            'by or added to this wallet.\n '
            'Once a swap has been reclaimed or unlocked, it will '
            'be removed from the list. ');
  }

  Widget _getActiveSwapsList() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: StreamBuilder<List<HtlcInfo>>(
                initialData: sl.get<P2pSwapsWorker>().cachedSwaps,
                stream: streamController.stream,
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return SyriusErrorWidget(snapshot.error!);
                  }
                  if ((snapshot.data?.length)! > 0) {
                    return ListView.separated(
                        controller: _scrollController,
                        cacheExtent: 10000,
                        itemCount: snapshot.data?.length ?? 0,
                        separatorBuilder: (BuildContext context, int index) {
                          return const SizedBox(
                            height: 15.0,
                          );
                        },
                        itemBuilder: (_, index) {
                          final htlc = snapshot.data![index];
                          return P2pSwapsListItem(
                            key: ValueKey(htlc.id.toString()),
                            htlcInfo: htlc,
                            onStepperNotificationSeeMorePressed:
                                widget.onStepperNotificationSeeMorePressed,
                          );
                        });
                  } else {
                    return const SyriusErrorWidget('No active swaps');
                  }
                },
              ),
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
