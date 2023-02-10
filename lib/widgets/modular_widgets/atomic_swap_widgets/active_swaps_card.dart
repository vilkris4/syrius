import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/active_swaps_worker.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/atomic_swap_widgets/active_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/tag_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../../blocs/infinite_scroll_bloc.dart';
import '../../../utils/global.dart';
import '../../../utils/input_validators.dart';
import 'package:collection/collection.dart';


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
  final TextEditingController _searchKeyWordController = TextEditingController();
  final StreamController<String> _textChangeStreamController = StreamController();
  late StreamSubscription _textChangesSubscription;

  //late StreamController<List<HtlcInfo>> streamController;


  bool _sortAscending = true;

  final StreamController<List<HtlcInfo>> _streamController = StreamController<
      List<HtlcInfo>>.broadcast();
  StreamController<List<HtlcInfo>> get streamController => _streamController;
  Stream<List<HtlcInfo>> get dataStream => _streamController.stream;
  StreamSink<List<HtlcInfo>> get dataSink => _streamController.sink;
  List<HtlcInfo>? _activewapList;// = [];
  List<HtlcInfo> _filteredSwapList = [];

  bool _inspectHtlc = false;


  final _onSearchInputChangedSubject = BehaviorSubject<String?>.seeded(null);
  Sink<String?> get onRefreshResultsRequest =>
      _onSearchInputChangedSubject.sink;
  String? get searchInputTerm => _onSearchInputChangedSubject.value;

  final _onNewListingStateController =
  BehaviorSubject<InfiniteScrollBlocListingState<HtlcInfo>>.seeded(
    InfiniteScrollBlocListingState<HtlcInfo>(),
  );

  //static const _pageSize = 10;
  final _subscriptions = CompositeSubscription();

  final List<ActiveSwapsFilterTag> selectedActiveSwapsFilterTag = [];

  @override
  void initState() {
    super.initState();
    _initStream();
    //streamController = StreamController.broadcast();
    streamController.stream.listen((event) {
      setState(() {
        _filteredSwapList = event;
        //_htlcList.add(event);
      });
    });
    //load(streamController);

    _onSearchInputChangedSubject.stream
        .flatMap((_) => _doRefreshResults())
        .listen(_onNewListingStateController.add)
        .addTo(_subscriptions);


    _textChangesSubscription = _textChangeStreamController.stream.debounceTime(
      const Duration(milliseconds: 100),).distinct().listen((text) {
          onRefreshResultsRequest
          .add(text);
    });

    /*
    _textChangesSubscription = _textChangeStreamController.stream.debounceTime(
      const Duration(milliseconds: 100),).distinct().listen((text) {
      sl
          .get<HtlcListBloc>()
          .onRefreshResultsRequest
          .add(text);
    });

     */
  }

  load(StreamController sc) async {
    //var htlcList = await sl.get<HtlcListBloc>().getHtlcList();
    //var htlcList = sl.get<ActiveSwapsWorker>().cachedSwaps;
    //sc.add(sl.get<ActiveSwapsWorker>().cachedSwaps);
    print("[!] Load()");

    sl.get<ActiveSwapsWorker>().controller.stream.listen((event) {
     // print('event: ${event.length}');
      //refreshResultsWithData();
      if (!mounted) {
        return;
      }
      else {
        setState(() {
          _activewapList = sl
              .get<ActiveSwapsWorker>()
              .cachedSwaps;
        });
      }
    });


      //sc.add(sl.get<ActiveSwapsWorker>().cachedSwaps);

    if (_activewapList != null) {

      print('load: ${_activewapList?.length}');
      _filteredSwapList = _activewapList!;
      if (searchInputTerm != null && (searchInputTerm?.isNotEmpty)!) {
        _filteredSwapList = await _filterActiveSwapsBySearchTerm(
            _filteredSwapList, searchInputTerm!);

        if (_filteredSwapList.isEmpty && InputValidators.checkHash(searchInputTerm) == null) {
          sc.add(await _swapLookupByHash(searchInputTerm!));
          return;
        }
      }
      _inspectHtlc = false;

      _filteredSwapList = await _filterActiveSwapsByTags(_filteredSwapList);

      _sortAscending
          ? _filteredSwapList.sort((a, b) => a.expirationTime.compareTo(b.expirationTime))
          : _filteredSwapList.sort((a, b) => b.expirationTime.compareTo(a.expirationTime));
      //_sortActiveSwapsByExpirationTime();

      sc.add(_filteredSwapList); // <<< THIS LINE
    }

    //for (var htlc in htlcList) {
   //   sc.add(htlc);
   // }
  }

  @override
  Widget build(BuildContext context) {
    return CardScaffold(
        title: ' Active Swaps',
        childBuilder: () => _getActiveSwapsList(),
        onRefreshPressed: () {
          _searchKeyWordController.clear();
          //sl.get<HtlcListBloc>().refreshResults();
          refreshResults();
        },
        description: 'This card displays a list of all active atomic swaps. '
            'The list can be sorted by expiration time and filtered by type of '
            'swap (incoming, outgoing, in progress, expired, hash) or with a '
            'search query. Once a swap has been reclaimed or unlocked, it will '
            'be removed from the list. '
    );
  }

  Widget _getActiveSwapsList() {
    print('getActiveSwapsList: ${_filteredSwapList.length}');
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          _getSearchInputField(),
          kVerticalSpacing,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _getActiveSwapsFilterTags(),
              InkWell(
                onTap: _sortActiveSwapsByExpirationTime,
                child: Icon(
                  Entypo.select_arrows,
                  size: 15.0,
                  color: Theme
                      .of(context)
                      .iconTheme
                      .color,
                ),
              ),
            ],
          ),
          kVerticalSpacing,
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              // TODO: THROW A FUTUREBUILDER IN HERE TO WAIT FOR THE DATA TO LOAD FIRST

              child: (_activewapList == null) ?
              FutureBuilder<List<HtlcInfo>>(
                future: sl.get<ActiveSwapsWorker>().parseHtlcContractBlocks(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && !snapshot.hasError) {
                    _activewapList = snapshot.data!;
                    _filteredSwapList = _activewapList!;
                    print("FUTURE: LOADING STREAM CONTROLLER");
                    load(streamController);
                    print("RETURNING ACTIVE SWAPS LIST");
                    return _getActiveSwapsList();
                  } else if (snapshot.hasError) {
                    return const SyriusLoadingWidget();
                  }
                  return const SyriusLoadingWidget();
                },
              ) :  StreamBuilder<List<HtlcInfo>>(
                //child: StreamBuilder<HtlcInfo>(
                initialData: _activewapList,
                //sl.get<ActiveSwapsWorker>().cachedSwaps, //sl.get<HtlcListBloc>().allActiveSwaps,
                stream: streamController.stream,
                //sl.get<HtlcListBloc>().streamController.stream,
                //streamController.stream,
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return SyriusErrorWidget(snapshot.error!);
                  }
                  /*
                  if (snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.hasData) {
                    } else {
                      return const SyriusLoadingWidget();
                    }
                  }

                   */
                  if ((snapshot.data?.length)! > 0) {
                    print('StreamBuilder snapshot.data?.length: ${snapshot.data
                        ?.length}');
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
                            getCurrentStatus: _inspectHtlc,
                            onStepperNotificationSeeMorePressed:
                            widget.onStepperNotificationSeeMorePressed,
                          );
                        });
                  }
                  else {
                    if (_searchKeyWordController.text.isNotEmpty) {
                      return const SyriusErrorWidget('No results found');
                    } else {
                      return const SyriusErrorWidget('No active swaps');
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSearchInputField() {
    return InputField(
      controller: _searchKeyWordController,
      hintText: 'Search by Deposit ID, Hashlock, or Address',
      suffixIcon: const Icon(
        Icons.search,
        color: Colors.green,
      ),
      onChanged: _textChangeStreamController.add,
    );
  }

  _getActiveSwapsFilterTags() {
    List<TagWidget> children = [];
    for (var tag in ActiveSwapsFilterTag.values) {
      (!_inspectHtlc)
          ? children.add(_getActiveSwapsFilterTag(tag))
          : children.add(_getDisabledActiveSwapsFilterTag(tag));
    }

    return Row(
      children: children,
    );
  }

  _getActiveSwapsFilterTag(ActiveSwapsFilterTag filterTag) {
    return TagWidget(
      text: (filterTag != ActiveSwapsFilterTag.sha256) ?
      FormatUtils.extractNameFromEnum<ActiveSwapsFilterTag>(filterTag) :
      "SHA-256",
      hexColorCode: Theme
          .of(context)
          .colorScheme
          .primaryContainer
          .value
          .toRadixString(16)
          .substring(2),
      iconData: selectedActiveSwapsFilterTag.contains(filterTag)
          ? Icons.check_rounded
          : null,
      onPressed: () {
        setState(() {
          if (selectedActiveSwapsFilterTag.contains(filterTag)) {
            selectedActiveSwapsFilterTag.remove(filterTag);
          } else {
            selectedActiveSwapsFilterTag.add(filterTag);
          }
          refreshResultsWithData();
        });
      },
    );
  }

  _getDisabledActiveSwapsFilterTag(ActiveSwapsFilterTag filterTag) {
    return TagWidget(
      text: (filterTag != ActiveSwapsFilterTag.sha256) ?
      FormatUtils.extractNameFromEnum<ActiveSwapsFilterTag>(filterTag) :
      "SHA-256",
      hexColorCode: Theme
          .of(context)
          .colorScheme
          .primaryContainer
          .value
          .toRadixString(16)
          .substring(2),
      textColor: Theme
          .of(context)
          .colorScheme
          .tertiaryContainer,
      iconData: null,
    );
  }

  void _sortActiveSwapsByExpirationTime() {
    setState(() {
      _sortAscending = !_sortAscending;
    });
    load(streamController);
  }

  Future<List<HtlcInfo>> _swapLookupByHash(String hashId) async {
    /*try {
      HtlcInfo _htlc = await zenon!.embedded.htlc.getHtlcInfoById(Hash.parse(hashId));
      return [_htlc];
    } catch (e) {
      print('HtlcInfo parsing error in _swapLookupByHash: $e');
    }

     */

    try {
      AccountBlock _block = (await zenon!.ledger.getAccountBlockByHash(Hash.parse(hashId)))!;
      Function eq = const ListEquality().equals;
      AbiFunction? f;
      for (var entry in Definitions.htlc.entries) {
        if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
            AbiFunction.extractSignature(_block.data))) {
          f = AbiFunction(entry.name!, entry.inputs!);
          print("${f.name}: ${f.decode(_block.data)}");

          if (f.name == "CreateHtlc") {
            _inspectHtlc = true;
            var data = f.decode(_block.data);
            final json = '{ '
                '"id": "${_block.hash}",'
                '"timeLocked": "${_block.address}",'
                '"hashLocked": "${data[0]}",'
                '"tokenStandard": "${_block.tokenStandard}",'
                '"amount": ${_block.amount},'
                '"expirationTime": ${data[1]},'
                '"hashType": ${data[2]},'
                '"keyMaxSize": ${data[3]},'
                '"hashLock": "${base64.encode(data[4])}"'
                '}';
            return [HtlcInfo.fromJson(jsonDecode(json))];
          }

          //_inspectHtlcBlock = _block;
        }
      }
    } catch (e) {
      print('AccountBlock Error in _swapLookupByHash: $e');
    }

    return [];
  }

  /*
  _getActiveSwapsFilterTag(ActiveSwapsFilterTag filterTag) {
    return TagWidget(
      text: (filterTag != ActiveSwapsFilterTag.sha256) ?
      FormatUtils.extractNameFromEnum<ActiveSwapsFilterTag>(filterTag) :
      "SHA-256",
      hexColorCode: Theme
          .of(context)
          .colorScheme
          .primaryContainer
          .value
          .toRadixString(16)
          .substring(2),
      iconData: sl
          .get<HtlcListBloc>()
          .selectedActiveSwapsFilterTag
          .contains(filterTag)
          ? Icons.check_rounded
          : null,
      onPressed: () {
        setState(() {
          if (sl
              .get<HtlcListBloc>()
              .selectedActiveSwapsFilterTag
              .contains(filterTag)) {
            sl
                .get<HtlcListBloc>()
                .selectedActiveSwapsFilterTag
                .remove(filterTag);
          } else {
            sl
                .get<HtlcListBloc>()
                .selectedActiveSwapsFilterTag
                .add(filterTag);
          }
          sl.get<HtlcListBloc>().refreshResultsWithData();
        });
      },
    );
  }

   */

  Future<void> _initStream() async {
    //await sl.get<ActiveSwapsWorker>().parseHtlcContractBlocks();
    //_filteredSwapList = sl.get<ActiveSwapsWorker>().cachedSwaps;
    //_activewapList = sl.get<ActiveSwapsWorker>().cachedSwaps;

    //sl.get<HtlcListBloc>().running = true;
    //sl.get<HtlcListBloc>().filteredSwapsStream();
    //sl.get<HtlcListBloc>().refreshData();

  }

  /*
  void _sortActiveSwapsByExpirationTime() {
    setState(() {
      _sortAscending = !_sortAscending;
      sl
          .get<HtlcListBloc>()
          .sortAscending =
      !sl
          .get<HtlcListBloc>()
          .sortAscending;
    });
  }

   */

  void refreshResults() {
    //print('refreshResults');
    if (!_onSearchInputChangedSubject.isClosed) {
      onRefreshResultsRequest.add(null);
    }
  }

  void refreshResultsWithData() {
    //print('refreshResultsWithData');
    if (!_onSearchInputChangedSubject.isClosed) {
      onRefreshResultsRequest.add(searchInputTerm);
    }
  }

  Stream<InfiniteScrollBlocListingState<HtlcInfo>> _doRefreshResults() async* {
    //print('_doRefreshResults');
    yield InfiniteScrollBlocListingState<HtlcInfo>();
    load(streamController);
    //yield* _fetchList(0);
  }

  Future<List<HtlcInfo>> _filterActiveSwapsBySearchTerm(
      List<HtlcInfo> _activeSwaps, String searchTerm) async {
    List<HtlcInfo> _filteredSwaps = [];
    //print('_filterActiveSwapsBySearchTerm');
    if (Address.isValid(searchTerm)) {
      for (var htlc in _activeSwaps) {
        if (htlc.hashLocked.equals(Address.parse(searchTerm)) ||
            htlc.timeLocked.equals(Address.parse(searchTerm))) {
          _filteredSwaps.add(htlc);
        }
      }
    }
    if (InputValidators.checkHash(searchTerm) == null) {
      for (var htlc in _activeSwaps) {
        if (htlc.id.equals(Hash.parse(searchTerm)) ||
            Hash.fromBytes(htlc.hashLock!).equals(Hash.parse(searchTerm))) {
          _filteredSwaps.add(htlc);
        }
      }
    }
    //_doRefreshResults();
    return _filteredSwaps;
  }

  Future<List<HtlcInfo>> _filterActiveSwapsByTags(
      List<HtlcInfo> _activeSwaps) async {
    //print('_filterActiveSwapsByTags');
    if (selectedActiveSwapsFilterTag.isNotEmpty) {
      int _currentTime = ((DateTime
          .now()
          .millisecondsSinceEpoch) / 1000).floor();

      if (selectedActiveSwapsFilterTag.contains(
          ActiveSwapsFilterTag.outgoing)) {
        _activeSwaps = _activeSwaps.where((swap) =>
            kDefaultAddressList.contains(swap.timeLocked.toString())).toList();
      }
      if (selectedActiveSwapsFilterTag.contains(
          ActiveSwapsFilterTag.incoming)) {
        _activeSwaps = _activeSwaps.where((swap) =>
            kDefaultAddressList.contains(swap.hashLocked.toString())).toList();
      }
      if (selectedActiveSwapsFilterTag.contains(
          ActiveSwapsFilterTag.inProgress)) {
        _activeSwaps =
            _activeSwaps.where((swap) => swap.expirationTime >= _currentTime)
                .toList();
      }
      if (selectedActiveSwapsFilterTag.contains(ActiveSwapsFilterTag.expired)) {
        _activeSwaps =
            _activeSwaps.where((swap) => swap.expirationTime < _currentTime)
                .toList();
      }
      if (selectedActiveSwapsFilterTag.contains(ActiveSwapsFilterTag.sha256)) {
        _activeSwaps =
            _activeSwaps.where((swap) => swap.hashType == 1).toList();
      }
    }
    //_doRefreshResults();
    return _activeSwaps;
  }


  @override
  void dispose() {
    _textChangesSubscription.cancel();
    _scrollController.dispose();
    //sl.get<HtlcListBloc>().running = false;
    super.dispose();
  }
}
