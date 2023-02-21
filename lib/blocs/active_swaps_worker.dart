// TODO: simplify this class
// encrypt pre-images
// Fix scenario where incomplete pending swaps are not saved to box
// Save checkpoint
// box.add => Something like Map<String, String> item = {'htlcInfo': json, 'preimage': preimage};
// Don't save pending swaps when creation fails, must receive confirmation that the swap was created successfully
// Call evaluateSwapStatus for getbyid?

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:hive/hive.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/unlock_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ActiveSwapsWorker extends BaseBloc<WalletNotification> {
  static ActiveSwapsWorker? _instance;
  int _lastCheckpoint = 0;
  Box? _activeSwapsBox;
  bool _boxOpened = false;
  bool _loadedSavedSwaps = false;

  List<HtlcInfo> _cachedSwaps = [];
  List<HtlcInfo> get cachedSwaps => _cachedSwaps;

  List<Hash> _autoUnlockedSwaps = [];
  List<Hash> get autoUnlockedSwaps => _autoUnlockedSwaps;

  final StreamController _controller = StreamController.broadcast();
  StreamController get controller => _controller;

  bool _synced = false;
  bool get synced => _synced;

  static ActiveSwapsWorker getInstance() {
    _instance ??= ActiveSwapsWorker();
    return _instance!;
  }

  bool runningSync = false;

  // to be renamed
  // don't call this method when widget rebuilds (example: resize window)
  Future<List<HtlcInfo>> parseHtlcContractBlocks() async {
    if (!_boxOpened) {
      await _openActiveSwapsBox();
      _boxOpened = true;
    }

    if (!_loadedSavedSwaps) {
      await _loadSavedSwaps();
      _loadedSavedSwaps = true;
    }

    int frontierContractHeight =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))?.height ?? 0;
    if (frontierContractHeight > 0) {
      int earliestContractHeight = await _getEarliestContractHeight();
      if (earliestContractHeight == 0) {
        earliestContractHeight = 1;
      }

      if (_lastCheckpoint <= earliestContractHeight &&
          earliestContractHeight <= frontierContractHeight) {
        await _parseHtlcContractBlocks(earliestContractHeight);
      } else if (_lastCheckpoint > earliestContractHeight &&
          _lastCheckpoint < frontierContractHeight) {
        await _parseHtlcContractBlocks(_lastCheckpoint);
      }
    }

    _lastCheckpoint = frontierContractHeight;
    _synced = true;
    return _cachedSwaps;
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<void> _parseHtlcContractBlocks(int startingHeight) async {
    AccountBlock frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int delta = frontierContractBlock.height - startingHeight + 1;

    if (delta <= 200) {
      _parseBlocks(startingHeight, delta);
    } else {
      int _height = startingHeight;
      while (_height < frontierContractBlock.height) {
        int _delta = 200;
        if (_height + _delta > frontierContractBlock.height) {
          _delta = frontierContractBlock.height - _height + 1;
        }
        while (runningSync) {
          print('waiting for sync to finish...');
          await Future.delayed(const Duration(seconds: 5));
        }
        await _parseBlocks(_height, _delta);
        _height += _delta;
      }
    }
    //TODO: SAVE CHECKPOINT
    //await _saveLastCheckedHeightValueToCache(
    //   (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!.height);
  }

  //tmp fix
  Future<void> _parseBlocks(int startingHeight, int delta) async {
    runningSync = true;
    AccountBlockList contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, startingHeight, delta);

    for (var block in contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock innerBlock = block.pairedAccountBlock!;

        if (innerBlock.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(innerBlock.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
              }
            }
            if (f.name.toString() == 'Create') {
              var data = f.decode(innerBlock.data);

              if (kDefaultAddressList.contains(innerBlock.address.toString()) ||
                  kDefaultAddressList.contains(data[0].toString())) {
                final json = '{"id": "${innerBlock.hash}",'
                    '"timeLocked": "${innerBlock.address}",'
                    '"hashLocked": "${data[0]}",'
                    '"tokenStandard": "${innerBlock.tokenStandard}",'
                    '"amount": ${innerBlock.amount},'
                    '"expirationTime": ${data[1]},'
                    '"hashType": ${data[2]},'
                    '"keyMaxSize": ${data[3]},'
                    '"hashLock": "${base64.encode(data[4])}"}';

                HtlcInfo _createdHtlc = HtlcInfo.fromJson(jsonDecode(json));
                if (!await updatePendingSwaps(_createdHtlc)) {
                  await addCreatedSwap(_createdHtlc);
                }
              }
            } else if (f.name.toString() == 'Unlock') {
              var args = f.decode(innerBlock.data);
              final Hash hashId = args[0];
              final List<int> preimage = args[1];

              if (synced) {
                //TODO review this
                try {
                  await autoUnlock(preimage);
                } catch (e) {
                  print('autoUnlock(preimage) failed: $e');
                }
              }
              await removeSwap(hashId);
            } else if (f.name.toString() == 'Reclaim') {
              var args = f.decode(innerBlock.data);
              final Hash hashId = args[0];
              await removeSwap(hashId);
            }
          } catch (e) {
            //_sendErrorNotification(
            //todo: log this error but don't send a notification
            print('1 Failed to parse block ${innerBlock.hash}: $e');
          }
        }
      }
    }
    runningSync = false;
  }

  Future<void> _openActiveSwapsBox() async {
    await Hive.openBox(kHtlcActiveSwapsBox);
    _activeSwapsBox = Hive.box(kHtlcActiveSwapsBox);
  }

  Future<void> _loadSavedSwaps() async {
    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [],
        ) ??
        [];

    if (createdSwapsList.isEmpty) {
      return;
    }

    int count = 0;
    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        HtlcInfo pendingSwap = HtlcInfo.fromJson(jsonDecode(htlc));
        if (pendingSwap.id.toString() == '0' * 64) {
          count++;
        }
      });
    }

    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        _cachedSwaps.add(HtlcInfo.fromJson(jsonDecode(htlc)));
      });
    }
  }

  Future<void> removeSwap(Hash hashId) async {
    // if user unlocks a swap -- remove it from the list
    // if user reclaims a swap -- remove it from the list
    // if hashlocked swap expires -- remove it from the list

    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [],
        ) ??
        [];

    if (createdSwapsList.isEmpty && _cachedSwaps.isEmpty) {
      return;
    }

    if (createdSwapsList.isNotEmpty) {
      List _createdSwapsList = createdSwapsList.toList();
      for (var i = 0; i < _createdSwapsList.length; i++) {
        _createdSwapsList[i].forEach((htlc, preimage) {
          HtlcInfo savedSwap = HtlcInfo.fromJson(jsonDecode(htlc));
          if (savedSwap.id == hashId) {
            //print(
            //   'removed ${savedSwap.id.toString()} from createdSwapsList because it was unlocked, reclaimed, or expired');
            createdSwapsList.removeAt(i);
          }
        });
      }
      _activeSwapsBox?.put(kHtlcCreatedSwapsKey, createdSwapsList);
    }

    if (_cachedSwaps.isNotEmpty) {
      List cachedSwaps = _cachedSwaps.toList();
      for (var i = 0; i < cachedSwaps.length; i++) {
        if (cachedSwaps[i].id == hashId) {
          //print(
          //    'removed ${cachedSwaps[i].id.toString()} from cachedSwaps because it was unlocked, reclaimed, or expired');
          _cachedSwaps.removeAt(i);
          _controller.add(_cachedSwaps);
        }
      }
    }

    if (_autoUnlockedSwaps.isNotEmpty) {
      _autoUnlockedSwaps.remove(hashId);
    }
  }

  //TODO: encrypt preimage before saving
  Future<void> addPendingSwap({
    required HtlcInfo htlc,
    List<int>? preimage,
  }) async {
    HtlcInfo pendingCreatedSwap = htlc;
    _cachedSwaps.add(pendingCreatedSwap);

    String _preimage =
        (preimage != null) ? FormatUtils.encodeHexString(preimage) : '';

    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [],
        ) ??
        [];

    createdSwapsList.add({
      json: _preimage.toString(),
    });

    await _activeSwapsBox?.put(
      kHtlcCreatedSwapsKey,
      createdSwapsList,
    );
  }

  Future<bool> _confirmPendingSwap(Hash id) async {
    bool confirmed = false;
    while (!confirmed) {
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<bool> updatePendingSwaps(HtlcInfo _discoveredSwap) async {
    bool _valueChanged = false;
    List createdSwapsList = _activeSwapsBox?.get(
          kHtlcCreatedSwapsKey,
          defaultValue: [],
        ) ??
        [];

    int count = 0;
    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        HtlcInfo _pendingSwap = HtlcInfo.fromJson(jsonDecode(htlc));

        if (_pendingSwap.id.toString() == '0' * 64) {
          count++;
        }
      });
    }

    if (count == 0) {
      return _valueChanged;
    }

    for (var i = 0; i < createdSwapsList.length; i++) {
      createdSwapsList[i].forEach((htlc, preimage) {
        htlc = jsonDecode(htlc);

        HtlcInfo _pendingSwap = HtlcInfo.fromJson(htlc);

        if (_pendingSwap.id.toString() == '0' * 64) {
          if (_pendingSwap.amount == _discoveredSwap.amount &&
              _pendingSwap.expirationTime == _discoveredSwap.expirationTime &&
              _pendingSwap.hashLocked == _discoveredSwap.hashLocked &&
              Hash.fromBytes((_pendingSwap.hashLock)!) ==
                  Hash.fromBytes((_discoveredSwap.hashLock)!) &&
              _pendingSwap.hashType == _discoveredSwap.hashType &&
              _pendingSwap.keyMaxSize == _discoveredSwap.keyMaxSize &&
              _pendingSwap.tokenStandard == _discoveredSwap.tokenStandard &&
              _pendingSwap.timeLocked == _discoveredSwap.timeLocked) {
            for (HtlcInfo _cachedSwap in _cachedSwaps) {
              if (_cachedSwap.id == _pendingSwap.id) {
                if (_cachedSwap.amount == _discoveredSwap.amount &&
                    _cachedSwap.expirationTime ==
                        _discoveredSwap.expirationTime &&
                    _cachedSwap.hashLocked == _discoveredSwap.hashLocked &&
                    Hash.fromBytes((_cachedSwap.hashLock)!) ==
                        Hash.fromBytes((_discoveredSwap.hashLock)!) &&
                    _cachedSwap.hashType == _discoveredSwap.hashType &&
                    _cachedSwap.keyMaxSize == _discoveredSwap.keyMaxSize &&
                    _cachedSwap.tokenStandard ==
                        _discoveredSwap.tokenStandard &&
                    _cachedSwap.timeLocked == _discoveredSwap.timeLocked) {
                  _cachedSwap.id = _discoveredSwap.id;
                }
              }
            }

            final json = '{"id": "${_discoveredSwap.id}",'
                '"timeLocked": "${_discoveredSwap.timeLocked}",'
                '"hashLocked": "${_discoveredSwap.hashLocked}",'
                '"tokenStandard": "${_discoveredSwap.tokenStandard}",'
                '"amount": ${_discoveredSwap.amount},'
                '"expirationTime": ${_discoveredSwap.expirationTime},'
                '"hashType": ${_discoveredSwap.hashType},'
                '"keyMaxSize": ${_discoveredSwap.keyMaxSize},'
                '"hashLock": "${base64.encode((_discoveredSwap.hashLock)!)}"}';

            createdSwapsList[i] = {json: preimage};
            _valueChanged = true;
          }
        }
      });
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
    bool alreadyCached = false;

    for (HtlcInfo cachedSwap in _cachedSwaps) {
      if (cachedSwap.id == _createdSwap.id) {
        alreadyCached = true;
        break;
      }
    }

    if (!alreadyCached) {
      _cachedSwaps.add(_createdSwap);
      _controller.add(_cachedSwaps);

      final json = '{"id": "${_createdSwap.id}",'
          '"timeLocked": "${_createdSwap.timeLocked}",'
          '"hashLocked": "${_createdSwap.hashLocked}",'
          '"tokenStandard": "${_createdSwap.tokenStandard}",'
          '"amount": ${_createdSwap.amount},'
          '"expirationTime": ${_createdSwap.expirationTime},'
          '"hashType": ${_createdSwap.hashType},'
          '"keyMaxSize": ${_createdSwap.keyMaxSize},'
          '"hashLock": "${base64.encode((_createdSwap.hashLock)!)}"}';
      String _preimage = '';

      List createdSwapsList = _activeSwapsBox?.get(
            kHtlcCreatedSwapsKey,
            defaultValue: [],
          ) ??
          [];

      createdSwapsList.add({
        json: _preimage.toString(),
      });

      await _activeSwapsBox?.put(
        kHtlcCreatedSwapsKey,
        createdSwapsList,
      );
    }
  }

  Future<void> autoUnlock(unlockedHashlock) async {
    Function eq = const ListEquality().equals;
    List<int> unlockedSha3 = Hash.digest(unlockedHashlock).getBytes()!;
    List<int> unlockedSha256 = await Crypto.sha256Bytes(unlockedHashlock);

    for (HtlcInfo lockedSwap in _cachedSwaps) {
      if (kDefaultAddressList.contains(lockedSwap.hashLocked.toString()) ||
          (_isAtomicUnlockingEnabled() &&
              await _canProxyUnlock(lockedSwap.hashLocked) &&
              kDefaultAddressList.contains(lockedSwap.timeLocked.toString()))) {
        if (eq(lockedSwap.hashLock, unlockedSha3) ||
            eq(lockedSwap.hashLock, unlockedSha256)) {
          bool _isExpired = lockedSwap.expirationTime <
              ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();

          Map _status = await sl
              .get<ActiveSwapsWorker>()
              .evaluateSwapStatus(lockedSwap.id);
          if (_status.isNotEmpty) {
            if (_status.entries.first.key != 'Unlock' &&
                _status.entries.first.key != 'Reclaim' &&
                !_isExpired) {
              _autoUnlockedSwaps.add(lockedSwap.id);
              UnlockHtlcBloc().unlockHtlc(
                id: lockedSwap.id,
                preimage: hex.encode(unlockedHashlock),
                hashLocked: _isIncomingDeposit(lockedSwap)
                    ? lockedSwap.hashLocked
                    : Address.parse(kSelectedAddress!),
              );
            }
          } else if (!_isExpired) {
            _autoUnlockedSwaps.add(lockedSwap.id);
            UnlockHtlcBloc().unlockHtlc(
              id: lockedSwap.id,
              preimage: hex.encode(unlockedHashlock),
              hashLocked: _isIncomingDeposit(lockedSwap)
                  ? lockedSwap.hashLocked
                  : Address.parse(kSelectedAddress!),
            );
          }
        }
      }
    }
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<Map> evaluateSwapStatus(Hash hashId) async {
    int startingHeight = ((await zenon!.ledger.getAccountBlockByHash(hashId))
        ?.pairedAccountBlock
        ?.height)!;

    AccountBlock frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int _delta = frontierContractBlock.height - startingHeight + 1;
    AccountBlockList contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, startingHeight, _delta);

    for (var block in contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock innerBlock = block.pairedAccountBlock!;
        if (innerBlock.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(innerBlock.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
              }
            }
            if (f.name.toString() == 'Unlock') {
              var args = f.decode(innerBlock.data);
              final Hash htlcId = args[0];
              final preimage = hex.encode(args[1]);
              if (htlcId == hashId) {
                return {f.name.toString(): preimage};
              }
            } else if (f.name.toString() == 'Reclaim') {
              var args = f.decode(innerBlock.data);
              final Hash hashId = args[0];
              if (hashId == hashId) {
                return {f.name.toString(): ''};
              }
            }
          } catch (e) {
            _sendErrorNotification(
                'evaluateSwapStatus: Failed to parse block ${innerBlock.hash}: $e');
          }
        }
      }
    }
    return {};
  }

  // check all account blocks for the htlc contract from _startingHeight until now
  // then set _lastCheckedContractHeight to the last contract height checked
  Future<String> scanForSecret(Hash hashId) async {
    int startingHeight = ((await zenon!.ledger.getAccountBlockByHash(hashId))
        ?.pairedAccountBlock
        ?.height)!;

    AccountBlock frontierContractBlock =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;
    int delta = frontierContractBlock.height - startingHeight + 1;
    AccountBlockList _contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, startingHeight, delta);

    for (var block in _contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock pairedBlock = block.pairedAccountBlock!;
        if (pairedBlock.blockType == BlockTypeEnum.userSend.index) {
          Function eq = const ListEquality().equals;
          late AbiFunction f;
          try {
            for (var entry in Definitions.htlc.entries) {
              if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
                  AbiFunction.extractSignature(pairedBlock.data))) {
                f = AbiFunction(entry.name!, entry.inputs!);
              }
            }
            if (f.name.toString() == 'Unlock') {
              var args = f.decode(pairedBlock.data);
              final Hash htlcId = args[0];
              final preimage = hex.encode(args[1]);
              if (htlcId == hashId) {
                return preimage;
              }
            }
          } catch (e) {
            _sendErrorNotification(
                'scanForSecret: Failed to parse block ${pairedBlock.hash}: $e');
          }
        }
      }
    }
    return '';
  }

  // Determine htlc contract height kHtlcMaxCheckHours hours ago, within 10 blocks
  Future<int> _getEarliestContractHeight() async {
    int frontierMomentumHeight =
        (await zenon!.ledger.getFrontierMomentum()).height;
    int frontierContractBlockHeight =
        (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))?.height ?? 0;
    int earliestContractHeight = 0;

    if (frontierContractBlockHeight >= 10) {
      for (var i = frontierContractBlockHeight; i > 0; i -= 10) {
        var contractBlock =
            await zenon!.ledger.getAccountBlocksByHeight(htlcAddress, i, 1);

        if ((contractBlock.list?.first.momentumAcknowledged.height)! <
            frontierMomentumHeight - (kMomentumsPerHour * kHtlcMaxCheckHours)) {
          earliestContractHeight = i;
          break;
        }
      }
    } else {
      earliestContractHeight = 0;
    }
    return earliestContractHeight;
  }

  Future<void> _saveLastCheckedHeightValueToCache(int height) async {
    //await sharedPrefsService!.put(
    //   kHtlcLastCheckedHeightKey,
    //   height,
    //  );
  }

  bool _isAtomicUnlockingEnabled() {
    return sharedPrefsService!.get(
      kHtlcAtomicUnlocksKey,
      defaultValue: true,
    );
  }

  Future<bool> _canProxyUnlock(Address address) async {
    return await zenon!.embedded.htlc.getProxyUnlockStatus(address);
  }

  bool _isIncomingDeposit(HtlcInfo htlcInfo) {
    return kDefaultAddressList.contains(htlcInfo.hashLocked.toString());
  }

  bool _isSwapExpired(HtlcInfo htlcInfo) {
    final remaining = htlcInfo.expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining <= 0;
  }

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
