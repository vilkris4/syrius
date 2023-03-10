import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/infinite_scroll_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/atomic_swap_widgets/active_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/tag_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

enum ActiveSwapsFilterTag {
  incoming,
  outgoing,
  inProgress,
  expired,
  sha256,
}

class ActiveSwapsCard extends StatefulWidget {
  final VoidCallback onStepperNotificationSeeMorePressed;

  const ActiveSwapsCard({
    required this.onStepperNotificationSeeMorePressed,
    Key? key,
  }) : super(key: key);

  @override
  _ActiveSwapsCardState createState() => _ActiveSwapsCardState();
}

class _ActiveSwapsCardState extends State<ActiveSwapsCard> {
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

  void _updateList(StreamController sc) async {
    sl.get<ActiveSwapsWorker>().controller.stream.listen((event) {
      if (!mounted) {
        return;
      } else {
        setState(() {
          //_activewapList = sl.get<ActiveSwapsWorker>().cachedSwaps;
        });
      }
    });

    //if (_activewapList != null) {
    //_filteredSwapList = _activewapList!;
    //sc.add(_filteredSwapList);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold(
        title: ' Active Swaps',
        childBuilder: () => FutureBuilder<List<HtlcInfo>>(
              future: sl.get<ActiveSwapsWorker>().getSavedSwaps(),
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
        description: 'This card displays a list of all active atomic swaps.\n '
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
                initialData: sl.get<ActiveSwapsWorker>().cachedSwaps,
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
                          return ActiveSwapsListItem(
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
