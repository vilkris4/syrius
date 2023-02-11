import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:hive/hive.dart';

import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../utils/format_utils.dart';

class ActiveSwapsWorker extends BaseBloc<WalletNotification> {
  bool debug = true; // will be removed after testing
  bool running = false;
  bool checkingPastUnlocks = false;
  List<Hash> pool = [];
  List<HtlcInfo> cachedSwaps = [];
  List<Map> cachedUnlocks = []; // {hash: Hash, secret: String}
  List<Hash> cachedReclaims = [];

  StreamController controller = StreamController.broadcast();

  // How to inform Active Swaps Card of a change to cachedSwaps
  // controller.add(cachedSwaps);

  int _queryCooldown = ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
  final int _startupDelay = 3;
  static ActiveSwapsWorker? _instance;

  int lastCheckpoint = 0;

  Box? _activeSwapsBox;
  bool boxOpened = false;
  bool loadedSavedSwaps = false;

  bool _firstRun = true;

  static ActiveSwapsWorker getInstance() {
    _instance ??= ActiveSwapsWorker();
    return _instance!;
  }

  Future<List<HtlcInfo>> parseHtlcContractBlocks() async {
    print("parseHtlcContractBlocks() started");
    if (!boxOpened) {
      await _openActiveSwapsBox();
      boxOpened = true;
    }

    if (!loadedSavedSwaps) {
      await _loadSavedSwaps();
      loadedSavedSwaps = true;
    }

    print("starting _getContractHeightXHoursAgo");
    int _height = await _getContractHeightXHoursAgo();
    print("finished _getContractHeightXHoursAgo");
    int _currentHeight =
        ((await zenon!.ledger.getFrontierAccountBlock(htlcAddress))?.height)!;
    if (lastCheckpoint <= _height && _height < _currentHeight) {
      print("parsing htlc contract blocks from $_height to $_currentHeight");
      await _parseHtlcContractBlocks(_height);
    } else if (lastCheckpoint > _height && lastCheckpoint < _currentHeight) {
      print(
          "parsing htlc contract blocks from $lastCheckpoint to $_currentHeight");
      await _parseHtlcContractBlocks(lastCheckpoint);
    } else {
      print("$_currentHeight: no new htlc activity");
    }
    lastCheckpoint = _currentHeight;

    print("parseHtlcContractBlocks() finished");

    return cachedSwaps;
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<void> _parseHtlcContractBlocks(int _startingHeight) async {
    AccountBlock _frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _delta = _frontierContractBlock.height - _startingHeight + 1;
    AccountBlockList _contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, _startingHeight, _delta);

    for (var block in _contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock _block = block.pairedAccountBlock!;
        print("pairdedAccountBlock hash: ${_block.hash}");
        if (_block.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(_block.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
                //   (debug) ? print("found function ${f.name} and ${f.inputs} in ${_block
                //       .hash} with data ${f.decode(_block.data)} || sent from: ${_block.address}") :null;
              }
            }
            if (f.name.toString() == "CreateHtlc") {
              var data = f.decode(_block.data);
              print(data);
              //print("Found CreateHtlc in ${_block.hash}, sent from: ${_block.address}");

              if (kDefaultAddressList.contains(_block.address.toString()) ||
                  kDefaultAddressList.contains(data[0].toString())) {
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
                HtlcInfo _createdHtlc = HtlcInfo.fromJson(jsonDecode(json));
                //cachedSwaps.add(_createdHtlc);
                if (!await updatePendingSwaps(_createdHtlc)) {
                  await addCreatedSwap(_createdHtlc);
                }
                //controller.add(cachedSwaps);
              }
            } else if (f.name.toString() == "UnlockHtlc") {
              var args = f.decode(_block.data);
              //   print("Found UnlockHtlc in ${_block.hash}, sent from: ${_block.address}");
              final Hash hashId = args[0];
              final String preimage = hex.encode(args[1]);
              //  (debug)
              //       ? print(
              //       "${_block.hash.toString()}: htlc id ${hashId.toString()} unlocked with pre-image: $preimage")
              //       : null;
              await removeSwap(hashId);
              //TODO: uncomment this line when auto unlock is implemented
              ///_autoUnlock(hashId, preimage);
              //cachedUnlocks.add({hashId : preimage});
              //controller.add(cachedSwaps);
            } else if (f.name.toString() == "ReclaimHtlc") {
              var args = f.decode(_block.data);
              final Hash hashId = args[0];
              //    (debug)
              //       ? print(
              //        "htlc id ${hashId.toString()} reclaimed")
              //        : null;

              await removeSwap(hashId);
            } else {
              print("ERROR COULD NOT DECODE BLOCK ${_block.hash}");
            }
          } catch (e) {
            _sendErrorNotification(
                "1 Failed to parse block ${_block.hash}: $e");
          }
        }
      }
    }
    //sl.get<HtlcListBloc>().addDiscoveredSwaps(cachedSwaps);

    //await _saveLastCheckedHeightValueToCache(
    //   (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!.height);
  }

/*
  // Only hashes that are parsed from live momentums are added to the pool
  void addHash(Hash hash) {
    zenon!.stats.syncInfo().then((syncInfo) {
      if (syncInfo.state == SyncState.syncDone ||
          (syncInfo.targetHeight > 0 && syncInfo.currentHeight > 0 &&
              (syncInfo.targetHeight - syncInfo.currentHeight) < 3)) {
        pool.add(hash);
        autoUnlock();
      }
    });
  }

 */

  Future<void> _openActiveSwapsBox() async {
    await Hive.openBox(kHtlcActiveSwapsBox);
    _activeSwapsBox = Hive.box(kHtlcActiveSwapsBox);
  }

  Future<void> _loadSavedSwaps() async {
    print("[!] loading saved swaps");

    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [], //[{}],
        ) ??
        [];

    if (createdSwapsList.isEmpty) {
      print("No saved swaps found");
      return;
    }

    int count = 0;
    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        HtlcInfo _pendingSwap = HtlcInfo.fromJson(jsonDecode(htlc));
        if (_pendingSwap.id.toString() == "0" * 64) {
          count++;
        }
      });
    }
    print(
        "Initially: There are $count pending swaps (try to get this as close to 0 as possible)");
    print(
        "Initially: There are ${createdSwapsList.length} total swaps in the list");

    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        //HtlcInfo _pendingSwap =
        //print("adding swap to cachedswaps");
        cachedSwaps.add(HtlcInfo.fromJson(jsonDecode(htlc)));
      });
    }
    print("[!] loaded ${cachedSwaps.length} saved swaps");
  }

  Future<void> removeSwap(Hash hashId) async {
    print(
        "[!] checking if unlocked, reclaimed, or expired swap needs to be removed");
    // if user unlocks a swap -- remove it from the list
    // if user reclaims a swap -- remove it from the list
    // if hashlocked swap expires -- remove it from the list
    print("hashId: ${hashId.toString()}");

    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [], //[{}],
        ) ??
        [];

    if (createdSwapsList.isEmpty && cachedSwaps.isEmpty) {
      print("No saved or cached swaps found");
      return;
    }

    if (createdSwapsList.isNotEmpty) {
      List _createdSwapsList = createdSwapsList.toList();
      for (var i = 0; i < _createdSwapsList.length; i++) {
        _createdSwapsList[i].forEach((htlc, preimage) {
          HtlcInfo _savedSwap = HtlcInfo.fromJson(jsonDecode(htlc));
          if (_savedSwap.id == hashId) {
            print(
                "removed ${_savedSwap.id.toString()} from createdSwapsList because it was unlocked, reclaimed, or expired");
            createdSwapsList.removeAt(i);
          }
        });
      }
      _activeSwapsBox?.put(kHtlcCreatedSwapsKey, createdSwapsList);
    }

    if (cachedSwaps.isNotEmpty) {
      List _cachedSwaps = cachedSwaps.toList();
      for (var i = 0; i < _cachedSwaps.length; i++) {
        if (_cachedSwaps[i].id == hashId) {
          print(
              "removed ${_cachedSwaps[i].id.toString()} from cachedSwaps because it was unlocked, reclaimed, or expired");
          cachedSwaps.removeAt(i);
          controller.add(cachedSwaps);
        }
      }
    }
  }

  Future<void> addPendingSwap({
    required String json,
    required List<int> preimage,
  }) async {
    HtlcInfo _pendingCreatedSwap = HtlcInfo.fromJson(jsonDecode(json));
    cachedSwaps.add(_pendingCreatedSwap);
    //pendingCreatedSwaps.add(_pendingCreatedSwap);

    String _preimage = FormatUtils.encodeHexString(preimage);

/*
    const String kHtlcCreatedSwapsKey = 'htlc_created_swaps_key';
    const String kHtlcDiscoveredSwapsKey = 'htlc_discovered_swaps_key';
    const String kHltcLastCheckpointKey = 'htlc_last_checkpoint_key';

 */

    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [], //[{}],
        ) ??
        [];

    //createdSwapsList.add([{_pendingCreatedSwap.toJson().toString(): _preimage.toString(),}]);
    createdSwapsList.add({
      json: _preimage.toString(),
    });

    await _activeSwapsBox?.put(
      kHtlcCreatedSwapsKey,
      createdSwapsList,
    );

    print(
        'saved created swap: ${_pendingCreatedSwap.toJson()} || preimage: $_preimage');
    //print(_activeSwapsBox?.get(kHtlcCreatedSwapsKey)[0]['id']);
    print(_activeSwapsBox?.get(kHtlcCreatedSwapsKey).length);

    for (var x in _activeSwapsBox?.get(kHtlcCreatedSwapsKey) ?? []) {
      print(x);
    }
  }

  Future<bool> updatePendingSwaps(HtlcInfo _discoveredSwap) async {
    print("updating pending swaps");
    bool _valueChanged = false;
    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [], //[{}],
        ) ??
        [];
    // print("createdSwapsList: ${createdSwapsList.length}");
    //  print(createdSwapsList);

    int count = 0;
    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        //htlc = jsonDecode(htlc);
        //  print("htlc: $htlc || ${htlc.runtimeType}");
        HtlcInfo _pendingSwap = HtlcInfo.fromJson(jsonDecode(htlc));
        // print("did it work? ${_pendingSwap.id}");
        if (_pendingSwap.id.toString() == "0" * 64) {
          count++;
        }
      });
    }

    if (count == 0) {
      return _valueChanged;
    }
    print("There are $count pending swaps");

    //print("swap: ${_discoveredSwap.id}");
    for (var i = 0; i < createdSwapsList.length; i++) {
      //HtlcInfo _tmp = HtlcInfo.fromJson(jsonDecode(createdSwapsList[i].keys.toList().first));
      //HtlcInfo _tmp = HtlcInfo.fromJson(jsonDecode(createdSwapsList[i].keys));
      createdSwapsList[i].forEach((htlc, preimage) {
        htlc = jsonDecode(htlc);
        // print("json htlc: $htlc || ${htlc.runtimeType}");
        HtlcInfo _pendingSwap = HtlcInfo.fromJson(htlc);
        // print("preimage: $preimage");

        // print("_pendingSwap: ${_pendingSwap.id}");

        if (_pendingSwap.id.toString() == "0" * 64) {
          //print("found pending swap: ${_pendingSwap.id}");
          print("---------------------------------------------");
          print("json htlc: $htlc || ${htlc.runtimeType}");
          print("pending swap: ${_pendingSwap.toJson()}");
          print("discovered swap: ${_discoveredSwap.toJson()}");
          print("---------------------------------------------");
          if (_pendingSwap.amount == _discoveredSwap.amount &&
              _pendingSwap.expirationTime == _discoveredSwap.expirationTime &&
              //_discoveredSwap.expirationTime - _pendingSwap.expirationTime <= 60 &&
              _pendingSwap.hashLocked == _discoveredSwap.hashLocked &&
              Hash.fromBytes((_pendingSwap.hashLock)!) ==
                  Hash.fromBytes((_discoveredSwap.hashLock)!) &&
              _pendingSwap.hashType == _discoveredSwap.hashType &&
              _pendingSwap.keyMaxSize == _discoveredSwap.keyMaxSize &&
              _pendingSwap.tokenStandard == _discoveredSwap.tokenStandard &&
              _pendingSwap.timeLocked == _discoveredSwap.timeLocked) {
            print("found match!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

            for (HtlcInfo _cachedSwap in cachedSwaps) {
              if (_cachedSwap.id == _pendingSwap.id) {
                if (_cachedSwap.amount == _discoveredSwap.amount &&
                    _cachedSwap.expirationTime ==
                        _discoveredSwap.expirationTime &&
                    //_discoveredSwap.expirationTime - _cachedSwap.expirationTime <= 60 &&
                    _cachedSwap.hashLocked == _discoveredSwap.hashLocked &&
                    Hash.fromBytes((_cachedSwap.hashLock)!) ==
                        Hash.fromBytes((_discoveredSwap.hashLock)!) &&
                    _cachedSwap.hashType == _discoveredSwap.hashType &&
                    _cachedSwap.keyMaxSize == _discoveredSwap.keyMaxSize &&
                    _cachedSwap.tokenStandard ==
                        _discoveredSwap.tokenStandard &&
                    _cachedSwap.timeLocked == _discoveredSwap.timeLocked) {
                  print(
                      "found match in cached swaps!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                  print("updating its id to ${_discoveredSwap.id}");
                  _cachedSwap.id = _discoveredSwap.id;
                }
              }
            }

            final json = '{'
                '"id": "${_discoveredSwap.id}",'
                '"timeLocked": "${_discoveredSwap.timeLocked}",'
                '"hashLocked": "${_discoveredSwap.hashLocked}",'
                '"tokenStandard": "${_discoveredSwap.tokenStandard}",'
                '"amount": ${_discoveredSwap.amount},'
                '"expirationTime": ${_discoveredSwap.expirationTime},'
                '"hashType": ${_discoveredSwap.hashType},'
                '"keyMaxSize": ${_discoveredSwap.keyMaxSize},'
                '"hashLock": "${base64.encode((_discoveredSwap.hashLock)!)}"'
                '}';

            createdSwapsList[i] = {json: preimage};
            _valueChanged = true;
            print("updated swap: ${createdSwapsList[i]}");
          }
        }
      });
      //print("createdSwapsList[i].keys: ${createdSwapsList[i].keys} -> ${createdSwapsList[i].keys.runtimeType}");

      //print("${createdSwapsList[i]}");
      //print("${createdSwapsList[i].keys}");
      //print("${createdSwapsList[i].values}");

    }
    if (_valueChanged) {
      await _activeSwapsBox?.put(
        kHtlcCreatedSwapsKey,
        createdSwapsList,
      );
    }
    return _valueChanged;
  }

  Future<void> addCreatedSwap(HtlcInfo _createdSwap) async {
    bool _alreadyCached = false;
    bool _stillActive = false;

    for (HtlcInfo _cachedSwap in cachedSwaps) {
      if (_cachedSwap.id == _createdSwap.id) {
        _alreadyCached = true;
        break;
      }
    }

    // print(await zenon!.ledger.get)

    if (!_alreadyCached) {
      cachedSwaps.add(_createdSwap);
      controller.add(cachedSwaps);

      final json = '{'
          '"id": "${_createdSwap.id}",'
          '"timeLocked": "${_createdSwap.timeLocked}",'
          '"hashLocked": "${_createdSwap.hashLocked}",'
          '"tokenStandard": "${_createdSwap.tokenStandard}",'
          '"amount": ${_createdSwap.amount},'
          '"expirationTime": ${_createdSwap.expirationTime},'
          '"hashType": ${_createdSwap.hashType},'
          '"keyMaxSize": ${_createdSwap.keyMaxSize},'
          '"hashLock": "${base64.encode((_createdSwap.hashLock)!)}"'
          '}';
      String _preimage = "";

      List createdSwapsList = _activeSwapsBox?.get(
            kHtlcCreatedSwapsKey,
            defaultValue: [], //[{}],
          ) ??
          [];

      createdSwapsList.add({
        json: _preimage.toString(),
      });

      await _activeSwapsBox?.put(
        kHtlcCreatedSwapsKey,
        createdSwapsList,
      );

      print(
          'added created swap: ${_createdSwap.toJson()} || preimage: $_preimage');
    }
  }

  /*
  // Only hashes that are parsed from live momentums are passed to this
  // TODO: consolidate autoUnlock and checkPastUnlocks
  Future<void> autoUnlock() async {
    if (kCurrentPage != Tabs.lock) {
      int _currentTime = ((DateTime
          .now()
          .millisecondsSinceEpoch) / 1000).floor();
      List<HtlcInfo> _htlcs = _getInProgressSwaps(_currentTime);
      if (_htlcs.isEmpty && _currentTime > _queryCooldown) {
        //await sl<HtlcListBloc>().getData(0, 10, null);
        _htlcs = _getInProgressSwaps(_currentTime);
        _refreshQueryCooldown();
        if (_htlcs.isEmpty) {
          pool.clear();
          await _saveLastCheckedHeightValueToCache(
              (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!
                  .height);
        }
      }
      if (!running && _htlcs.isNotEmpty) {
        while (pool.isNotEmpty) {
          running = true;
          List<Hash> _pool = pool.toList();
          for (Hash currentHash in _pool) {
            AccountBlock block = (await zenon!.ledger.getAccountBlockByHash(
                currentHash))!;

            if (block.blockType != BlockTypeEnum.userSend.index) {
              pool.remove(currentHash);
              continue;
            }

            if (block.pairedAccountBlock == null ||
                block.pairedAccountBlock?.blockType !=
                    BlockTypeEnum.contractReceive.index) {
              // spam avoidance
              await Future.delayed(const Duration(seconds: 5));
              continue;
            }

            Function eq = const ListEquality().equals;
            late AbiFunction f;
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(block.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
              }
            }

            if (f.name == null) {
              continue;
            }

            if (f.name.toString() == "UnlockHtlc") {
              for (var htlc in _htlcs) {
                if (block.address != htlc.hashLocked) {
                  continue;
                }

                var args = f.decode(block.data);

                if (args.length != 2) {
                  continue;
                }

                if (args[0].toString() != htlc.id.toString()) {
                  continue;
                }

                if ((block.pairedAccountBlock?.descendantBlocks)!.any((x) =>
                x.blockType == BlockTypeEnum.contractSend.index &&
                    x.toAddress == htlc.hashLocked &&
                    x.tokenStandard == htlc.tokenStandard &&
                    x.amount == htlc.amount)) {
                  final preimage = hex.encode(args[1]);
                  (debug) ? print(
                      "htlc id ${htlc.id
                          .toString()} unlocked with pre-image: $preimage") : null;

                  var unlockedHashLock = htlc.hashLock;
/*
                  List<HtlcInfo> hashLockedHtlcs = [];
                  for (var address in kDefaultAddressList) {
                    hashLockedHtlcs += (await zenon!.embedded.htlc
                        .getHtlcInfosByHashLockedAddress(
                      Address.parse(address!),
                      pageIndex: 0,
                      pageSize: rpcMaxPageSize,
                    )).list;
                  }

                  if (hashLockedHtlcs.isNotEmpty) {
                    await Future.wait(
                        hashLockedHtlcs.map((var lockedHtlc) async {
                          if (eq(lockedHtlc.hashLock, unlockedHashLock)) {
                            sl<HtlcListBloc>().addAutoUnlockedSwaps(lockedHtlc.id); // to be fixed

                            (debug) ? {
                            print(
                            'Unlocking htlc id ${lockedHtlc.id
                                .toString()} with amount ${lockedHtlc
                                .amount}'),
                            print("preimage: $preimage"),
                            print("recipient: ${lockedHtlc.hashLocked}"),
                          } : null;

                            UnlockHtlcBloc().unlockHtlc(
                              id: lockedHtlc.id,
                              preimage: preimage,
                              recipient: lockedHtlc.hashLocked,
                            );
                          }
                        }));
                  }

 */
                }
              }
            }
            pool.remove(currentHash);
          }
        }
        running = false;
        await _saveLastCheckedHeightValueToCache(
            (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!.height);
      }
    }
  }

  // Called every time wallet is unlocked
  // Avoids unlocking swaps when wallet is locked
  // "checked height" refers to the htlc contract's block height
  // momentum/chain height is explicitly mentioned when applicable
  Future initCheckHtlcContractBlocks() async {
    await Future.delayed(Duration(seconds: _startupDelay));
    if (!checkingPastUnlocks && kCurrentPage != Tabs.lock) {
      checkingPastUnlocks = true;

      int _currentTime = ((DateTime
          .now()
          .millisecondsSinceEpoch) / 1000).floor();
      List<HtlcInfo> _htlcs = _getInProgressSwaps(_currentTime);

      // If there aren't any active swaps, set last checked height to current height
      if (_htlcs.isEmpty && _currentTime > _queryCooldown) {
        //await sl<HtlcListBloc>().getData(0, 10, null);
        _htlcs = _getInProgressSwaps(_currentTime);
        _refreshQueryCooldown();
        if (_htlcs.isEmpty) {
          (debug) ? print("initCheckHtlcContractBlocks: no htlcs found") : null;
          await _saveLastCheckedHeightValueToCache(
              (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!
                  .height);
          return;
        }
      }

      if (_htlcs.isNotEmpty) {
        // determine oldest swap
        // whichever is greater (i.e. more recent) of (oldest swap acknowledgeMomentum height) or (momentum height kHtlcMaxCheckHours hours ago)
        // then find the nearest contract height to that momentum height (margin of error 10)
        // and check all account blocks for the htlc contract until the end is reached

        /*
        int _lastCheckedContractHeight = sharedPrefsService!.get(
          kHtlcLastCheckedHeightKey,
          defaultValue: 0,
        );

         */
        //AccountBlockList block = await zenon!.ledger.getAccountBlocksByHeight(
        //    htlcAddress, _lastCheckedContractHeight, 1);

        (debug) ? {
       //print("_lastCheckedContractHeight: $_lastCheckedContractHeight"),
        //print("_lastCheckedContractHeight blocks: ${block.list?.length}"),
       // print("_lastCheckedContractHeight block height: ${block.list?.first.height}"),
       // print("_lastCheckedContractHeight block momentum acknowledged: ${block.list?.first.momentumAcknowledged.height}"),
      } : null;

       // var _lastCheckedContractMomentum = block.list?.first
       //     .momentumAcknowledged
     //       .height;
        var _frontierMomentumHeight = (await zenon!.ledger.getFrontierMomentum())
            .height;
        (debug) ? {
        print("_currentMomentumHeight: $_frontierMomentumHeight"),
        print(
            "kHtlcMaxCheckHours: $kHtlcMaxCheckHours || kHtlcMaxCheckHours * kMomentumsPerHour: ${kHtlcMaxCheckHours *
                kMomentumsPerHour}"),
        print("Oldest momentum we will check: ${_frontierMomentumHeight -
            (kMomentumsPerHour * kHtlcMaxCheckHours)}"),
      } : null;
        // Should not encounter this branch on mainnet
        if (_frontierMomentumHeight <= kMomentumsPerDay) {
          //check all momentums since inception
          _initCheckHtlcContractBlocks(0);
        } else {
          // compare all active swaps to determine which is the oldest one
          Map _oldestSwapContractHeight;
          if (_htlcs.length > 1) {
            List<Map> _swaps = [];
            for (var _htlc in _htlcs) {
              _swaps.add(
                  {
                    "htlc": _htlc,
                    "blockHeight": (await zenon!.ledger.getAccountBlockByHash(
                        _htlc.id))!.pairedAccountBlock!.height,
                  });
            }
            _oldestSwapContractHeight =
                _swaps.reduce((a, b) =>
                a['blockHeight'] < b['blockHeight']
                    ? a
                    : b);
          } else {
            _oldestSwapContractHeight =
            {
              "htlc": _htlcs.first,
              "blockHeight": (await zenon!.ledger.getAccountBlockByHash(
                  _htlcs.first.id))!.pairedAccountBlock!.height,
            };
          }
          (debug) ? {
          print("${_oldestSwapContractHeight.values.first
              .id} is the oldest swap"),
          print("${_oldestSwapContractHeight.values
              .last} is the oldest swap contract height"),
        } : null;

          int _oldestSwapMomentumHeight = (await zenon!.ledger
              .getAccountBlockByHash(
              _oldestSwapContractHeight.values.first.id))!
              .pairedAccountBlock!.momentumAcknowledged.height!;

/*
            (debug) ? {
          (_lastCheckedContractMomentum! <
          _frontierMomentumHeight - (kMomentumsPerHour * kHtlcMaxCheckHours)) ?
          print("_lastCheckedContractMomentum is more than $kHtlcMaxCheckHours hours old")
              :
          print("_lastCheckedContractMomentum is less than $kHtlcMaxCheckHours hours old"),
          } : null;

          if (_oldestSwapMomentumHeight >
              _frontierMomentumHeight - (kMomentumsPerHour * kHtlcMaxCheckHours)) {
            print("_oldestSwapMomentumHeight is less than $kHtlcMaxCheckHours hours old");

            if (_lastCheckedContractMomentum! > _oldestSwapMomentumHeight) {
              //example: if oldestswap is 1 hr old but we last checked 10 mins ago, then...
              print("check from last check time until now");
              _initCheckHtlcContractBlocks(_lastCheckedContractHeight);
            } else {
              //example: if oldestswap is 1 hr old but we last checked 6 hrs ago, then...
              //example: if oldestswap is 1 hr old but we last checked 3 days ago, then...
              print("check from oldestswap -> htlc contract height until now");
              _initCheckHtlcContractBlocks(_oldestSwapContractHeight.values.last);
            }
          } else {
            print("_oldestSwapMomentumHeight is more than $kHtlcMaxCheckHours hours old");
            if (_lastCheckedContractMomentum! >=
                _frontierMomentumHeight - (kMomentumsPerHour * kHtlcMaxCheckHours)) {
              //example: if oldestswap is > kHtlcMaxCheckHours hours old but we last checked < kHtlcMaxCheckHours hours ago, then...
              print("check from last check time until now");
              _initCheckHtlcContractBlocks(_lastCheckedContractHeight);
            } else {
              //example: if oldestswap is > kHtlcMaxCheckHours hours old but we last checked >= kHtlcMaxCheckHours hours ago, then...
              print("check from $kHtlcMaxCheckHours hours ago until now");
              // need to find which contract block height matches momentum height $kHtlcMaxCheckHours hours ago
              int _contractHeightXHoursAgo = await _getContractHeightXHoursAgo(_frontierMomentumHeight);
              _initCheckHtlcContractBlocks(_contractHeightXHoursAgo);
            }
          }

 */
        }
      }
    }
    checkingPastUnlocks = false;
  }

   */

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future _initCheckHtlcContractBlocks(int _startingHeight) async {
    AccountBlock _frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _delta = _frontierContractBlock.height - _startingHeight + 1;
    AccountBlockList _contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, _startingHeight, _delta);

    for (var block in _contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock _block = block.pairedAccountBlock!;
        if (_block.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(_block.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
                // (debug) ? print("found function ${f.name} and ${f.inputs} in ${_block
                //    .hash} with data ${f.decode(_block.data)}") :null;
              }
            }
            if (f.name.toString() == "UnlockHtlc") {
              var args = f.decode(_block.data);
              final preimage = hex.encode(args[1]);
              //  (debug) ? print(
              //       "htlc id ${_block.hash} unlocked with pre-image: $preimage") : null;

              /*
              List<HtlcInfo> hashLockedHtlcs = [];
              for (var address in kDefaultAddressList) {
                hashLockedHtlcs += (await zenon!.embedded.htlc
                    .getHtlcInfosByHashLockedAddress(
                  Address.parse(address!),
                  pageIndex: 0,
                  pageSize: rpcMaxPageSize,
                )).list;
              }

              if (hashLockedHtlcs.isNotEmpty) {
                await Future.wait(hashLockedHtlcs.map((var lockedHtlc) async {
                  if ((await InputValidators.checkSecret(
                      lockedHtlc, preimage)) == null) {
                    (debug) ? {
                    print(
                    'Unlocking htlc id ${lockedHtlc.id
                        .toString()} with amount ${lockedHtlc
                        .amount}'),
                    print("preimage: $preimage"),
                    print("recipient: ${lockedHtlc.hashLocked}")
                  } : null;

                    UnlockHtlcBloc().unlockHtlc(
                      id: lockedHtlc.id,
                      preimage: preimage,
                      recipient: lockedHtlc.hashLocked,
                    );
                    _sendSuccessNotification();
                  }
                }));
              }

               */
            }
          } catch (e) {
            _sendErrorNotification(
                "2 Failed to parse block ${_block.hash}: $e");
          }
        }
      }
    }
    await _saveLastCheckedHeightValueToCache(
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!.height);
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<Map> evaluateSwapStatus(Hash hashId) async {
    //Map: {f.name.toString(): preimage ?? ""}

    int _startingHeight = ((await zenon!.ledger.getAccountBlockByHash(hashId))
        ?.pairedAccountBlock
        ?.height)!;

    AccountBlock _frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _delta = _frontierContractBlock.height - _startingHeight + 1;
    AccountBlockList _contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, _startingHeight, _delta);

    for (var block in _contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock _block = block.pairedAccountBlock!;
        if (_block.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(_block.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
                // (debug) ? print("found function ${f.name} and ${f.inputs} in ${_block
                //    .hash} with data ${f.decode(_block.data)}") :null;
              }
            }
            if (f.name.toString() == "UnlockHtlc") {
              var args = f.decode(_block.data);
              final Hash htlcId = args[0];
              final preimage = hex.encode(args[1]);
              if (htlcId == hashId) {
                return {f.name.toString(): preimage};
              }
            } else if (f.name.toString() == "ReclaimHtlc") {
              var args = f.decode(_block.data);
              final Hash hashId = args[0];
              if (hashId == hashId) {
                return {f.name.toString(): ""};
              }
            }
          } catch (e) {
            _sendErrorNotification(
                "2 Failed to parse block ${_block.hash}: $e");
          }
        }
      }
    }
    return {};
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<String> scanForSecret(Hash hashId) async {
    int _startingHeight = ((await zenon!.ledger.getAccountBlockByHash(hashId))
        ?.pairedAccountBlock
        ?.height)!;

    AccountBlock _frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _delta = _frontierContractBlock.height - _startingHeight + 1;
    AccountBlockList _contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, _startingHeight, _delta);

    for (var block in _contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock _block = block.pairedAccountBlock!;
        if (_block.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(_block.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
                // (debug) ? print("found function ${f.name} and ${f.inputs} in ${_block
                //    .hash} with data ${f.decode(_block.data)}") :null;
              }
            }
            if (f.name.toString() == "UnlockHtlc") {
              var args = f.decode(_block.data);
              final Hash htlcId = args[0];
              final preimage = hex.encode(args[1]);
              if (htlcId == hashId) {
                return preimage;
              }
            }
          } catch (e) {
            _sendErrorNotification(
                "2 Failed to parse block ${_block.hash}: $e");
          }
        }
      }
    }
    return "";
  }

  // Input: current momentum height
  // Output: htlc contract height kHtlcMaxCheckHours hours ago, within 10 blocks
  Future<int> _getContractHeightXHoursAgo() async {
    int _currentMomentumHeight =
        (await zenon!.ledger.getFrontierMomentum()).height;
    AccountBlock _frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _contractHeightXHoursAgo = 0;

    (debug)
        ? {
            //   print("_initCheckHtlcContractBlocksReverse: $_currentMomentumHeight"),
            //  print("_frontierContractBlock height for htlcaddress: ${_frontierContractBlock?.height}"),
            // print("_frontierContractBlock momentumAcknowledged for htlcaddress: ${_frontierContractBlock?.momentumAcknowledged.height}"),
            //  print("_frontierContractBlock?.height = ${_frontierContractBlock?.height}"),
          }
        : null;

    if (_frontierContractBlock!.height >= 10) {
      for (var i = _frontierContractBlock.height; i >= 0; i -= 10) {
        // (debug) ? print("i=$i") : null;

        var _contractBlock =
            await zenon!.ledger.getAccountBlocksByHeight(htlcAddress, i, 1);

        //  (debug) ? {
        //   print("_contractBlock height: ${_contractBlock.list?.first.height}"),
        //    print("_contractBlock momentumAcknowledged: ${_contractBlock.list?.first.momentumAcknowledged.height}"),
        //   } : null;

        if ((_contractBlock.list?.first.momentumAcknowledged.height)! <
            _currentMomentumHeight - (kMomentumsPerHour * kHtlcMaxCheckHours)) {
          (debug)
              ? {
                  //   print("found contract block that was submitted $kHtlcMaxCheckHours hours ago, within 10 blocks of accuracy"),
                  //     print("_contractBlock height: ${_contractBlock.list?.first.height}"),
                  //     print("_contractBlock momentumAcknowledged: ${_contractBlock.list?.first.momentumAcknowledged.height}"),
                }
              : null;
          _contractHeightXHoursAgo = i;
          break;
        }
      }
    } else {
      _contractHeightXHoursAgo = 0;
    }
    return _contractHeightXHoursAgo;
  }

  Future<void> _saveLastCheckedHeightValueToCache(int _height) async {
    //await sharedPrefsService!.put(
    //   kHtlcLastCheckedHeightKey,
    //   _height,
    //  );
  }

  void _refreshQueryCooldown() {
    _queryCooldown += 60;
  }

  /*
  // Swaps that have not expired yet
  List<HtlcInfo> _getInProgressSwaps(int _currentTime) {
    List<HtlcInfo> _htlcs = sl<HtlcListBloc>().allActiveSwaps;
    return _htlcs.where((swap) => swap.expirationTime >= _currentTime).toList();
  }

   */

  //TODO: improve notifications
  void _sendSuccessNotification() {
    addEvent(
      WalletNotification(
        title: 'Automatic swap unlock was successful',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: 'Automatic swap unlock was successful.',
        type: NotificationType.paymentReceived,
      ),
    );
  }

  void _sendErrorNotification(String errorText) {
    addEvent(
      WalletNotification(
        title: 'Failed to automatically unlock swap',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: 'Failed to automatically unlock swap: $errorText',
        type: NotificationType.error,
      ),
    );
  }
}
