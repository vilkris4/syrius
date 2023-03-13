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

class P2pSwapsWorker extends BaseBloc<WalletNotification> {
  static P2pSwapsWorker? _instance;
  Box? _activeSwapsBox;
  bool _boxOpened = false;
  bool _loadedSavedSwaps = false;

  List<HtlcInfo> _cachedSwaps = [];
  List<HtlcInfo> get cachedSwaps => _cachedSwaps;

  List<Hash> _autoUnlockedSwaps = [];
  List<Hash> get autoUnlockedSwaps => _autoUnlockedSwaps;

  final StreamController _controller = StreamController.broadcast();
  StreamController get controller => _controller;

  StreamSubscription? _pendingSwapSubscription;

  Function eq = const ListEquality().equals;

  Future<List<HtlcInfo>> getSavedSwaps() async {
    await _openActiveSwapsBox();
    await _loadSavedSwaps();
    return _cachedSwaps;
  }

  //TODO: make sure this works when 'reset wallet' is called
  Future<void> _openActiveSwapsBox() async {
    if (_boxOpened != true) {
      await Hive.openBox(kP2pSwapsBox,
          encryptionCipher:
              HiveAesCipher((kKeyStore!.getKeyPair(0).getPrivateKey())!));
      _activeSwapsBox = Hive.box(kP2pSwapsBox);
      _boxOpened = true;
    }
  }

  Future<void> _loadSavedSwaps() async {
    if (!_loadedSavedSwaps) {
      for (int i = 0; i < (_activeSwapsBox?.length)!; i++) {
        _cachedSwaps.add(
            HtlcInfo.fromJson(jsonDecode(_activeSwapsBox?.getAt(i)['htlc'])));
      }
      _loadedSavedSwaps = true;
    }
  }

  // adds an htlc to the list of cached swaps
  // then does the following:
  // - confirms it has been acknowledged by the htlc contract
  // - updates the cached htlc with the correct hash id
  // - saves the htlc to the active swaps box
  Future<void> addPendingSwap({
    required HtlcInfo htlc,
    List<int>? preimage,
  }) async {
    _cachedSwaps.add(htlc);

    String _preimage =
        (preimage != null) ? FormatUtils.encodeHexString(preimage) : '';

    zenon!.wsClient.addOnConnectionEstablishedCallback((broadcaster) async {
      List<Hash> hashes = [];
      await zenon!.subscribe.toAccountBlocksByAddress(htlc.timeLocked);
      _pendingSwapSubscription = broadcaster.listen((event) async {
        if (event!["method"] == 'ledger.subscription') {
          for (var i = 0; i < event['params']['result'].length; i += 1) {
            var tx = event['params']['result'][i];
            if (tx['toAddress'] != htlcAddress.toString() &&
                tx['pairedAccountBlock'] == null) {
              continue;
            } else {
              Hash hash = Hash.parse(tx['hash']);
              if (hashes.contains(hash)) {
                break;
              }
              hashes.add(hash);
              AccountBlock block =
                  (await zenon!.ledger.getAccountBlockByHash(hash))!;

              AbiFunction f = _getAbiFunction(block);
              if (_isHtlcCreate(f)) {
                var data = f.decode(block.data);

                if (htlc.amount == block.amount &&
                    htlc.expirationTime == data[1].toInt() &&
                    htlc.hashLocked == data[0] &&
                    Hash.fromBytes((htlc.hashLock)) ==
                        Hash.fromBytes(data[4]) &&
                    htlc.hashType == data[2].toInt() &&
                    htlc.keyMaxSize == data[3].toInt() &&
                    htlc.tokenStandard == block.tokenStandard &&
                    htlc.timeLocked == block.address) {
                  for (var i = 0; i < _cachedSwaps.length; i++) {
                    if (_cachedSwaps[i].id ==
                            Hash.parse('0' * Hash.length * 2) &&
                        _cachedSwaps[i].amount == htlc.amount &&
                        _cachedSwaps[i].expirationTime == htlc.expirationTime &&
                        _cachedSwaps[i].hashLocked == htlc.hashLocked &&
                        _cachedSwaps[i].hashLock == htlc.hashLock &&
                        _cachedSwaps[i].hashType == htlc.hashType &&
                        _cachedSwaps[i].keyMaxSize == htlc.keyMaxSize &&
                        _cachedSwaps[i].tokenStandard == htlc.tokenStandard &&
                        _cachedSwaps[i].timeLocked == htlc.timeLocked) {
                      _cachedSwaps[i].id = htlc.id;
                    }
                  }

                  Map<String, String> swap = {
                    'htlc': jsonEncode(htlc.toJson()),
                    'preimage': _preimage.toString(),
                  };
                  await _activeSwapsBox?.add(swap);

                  _pendingSwapSubscription?.cancel();
                }
              }
            }
          }
        }
      });
    });
  }

  Future<void> removeSwap(Hash hashId) async {
    // if user unlocks a swap -- remove it from the list
    // if user reclaims a swap -- remove it from the list
    // if hashlocked swap expires -- remove it from the list

    for (int i = 0; i < (_activeSwapsBox?.length)!; i++) {
      if (HtlcInfo.fromJson(jsonDecode(_activeSwapsBox?.getAt(i)['htlc'])).id ==
          hashId) {
        await _activeSwapsBox?.deleteAt(i);
      } else {}
    }

    if (_cachedSwaps.isNotEmpty) {
      List cachedSwaps = _cachedSwaps.toList();
      for (var i = 0; i < cachedSwaps.length; i++) {
        if (cachedSwaps[i].id == hashId) {
          _cachedSwaps.removeAt(i);
          _controller.add(_cachedSwaps);
        }
      }
    }

    if (_autoUnlockedSwaps.isNotEmpty) {
      _autoUnlockedSwaps.remove(hashId);
    }
  }

  // After initiating a swap, monitor the htlc contract address for the secret
  void _unlockMonitoring() {}

  // auto-unlocks cached swaps if the preimage has been published
  // and one of the following requirements is met:
  // - the swap is incoming
  // - the swap is outgoing, atomic unlocking is enabled, and proxy unlocking is possible
  Future<void> autoUnlock(unlockedHashlock) async {
    List<int> unlockedSha3 = Hash.digest(unlockedHashlock).getBytes()!;
    List<int> unlockedSha256 = await Crypto.sha256Bytes(unlockedHashlock);

    for (HtlcInfo lockedSwap in _cachedSwaps) {
      if (_isIncomingDeposit(lockedSwap) ||
          (_isAtomicUnlockingEnabled() &&
              await _canProxyUnlock(lockedSwap.hashLocked) &&
              _isOutgoingDeposit(lockedSwap))) {
        if (eq(lockedSwap.hashLock, unlockedSha3) ||
            eq(lockedSwap.hashLock, unlockedSha256)) {
          if (!_isSwapExpired(lockedSwap)) {
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

  // parse all htlc contract account blocks from startingHeight until now
  // and extract the preimage if it has been published
  Future<String> scanForSecret(Hash hash) async {
    int startingHeight = ((await zenon!.ledger.getAccountBlockByHash(hash))
        ?.pairedAccountBlock
        ?.height)!;
    int delta = (await _getFrontierContractBlock()).height - startingHeight + 1;
    AccountBlockList contractBlocks = await zenon!.ledger
        .getAccountBlocksByHeight(htlcAddress, startingHeight, delta);

    for (var block in contractBlocks.list!) {
      if (block.blockType == BlockTypeEnum.contractReceive.index) {
        AccountBlock pairedBlock = block.pairedAccountBlock!;
        if (pairedBlock.blockType == BlockTypeEnum.userSend.index) {
          AbiFunction f = _getAbiFunction(pairedBlock);
          if (_isHtlcUnlock(f)) {
            var args = f.decode(pairedBlock.data);
            final Hash id = args[0];
            final preimage = hex.encode(args[1]);
            if (id == hash) {
              return preimage;
            }
          }
        }
      }
    }
    return '';
  }

  AbiFunction _getAbiFunction(AccountBlock block) {
    late AbiFunction f;
    try {
      for (var entry in Definitions.htlc.entries) {
        if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
            AbiFunction.extractSignature(block.data))) {
          f = AbiFunction(entry.name!, entry.inputs!);
        }
      }
    } catch (e) {
      _sendErrorNotification('Failed to parse block ${block.hash}: $e');
    }
    return f;
  }

  bool _isAtomicUnlockingEnabled() {
    return sharedPrefsService!.get(
      kP2pSwapsKey,
      defaultValue: true,
    );
  }

  Future<bool> _canProxyUnlock(Address address) async {
    return await zenon!.embedded.htlc.getProxyUnlockStatus(address);
  }

  bool _isIncomingDeposit(HtlcInfo htlcInfo) {
    return kDefaultAddressList.contains(htlcInfo.hashLocked.toString());
  }

  bool _isOutgoingDeposit(HtlcInfo htlcInfo) {
    return kDefaultAddressList.contains(htlcInfo.timeLocked.toString());
  }

  bool _isSwapExpired(HtlcInfo htlcInfo) {
    final remaining = htlcInfo.expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining <= 0;
  }

  bool _isHtlcCreate(AbiFunction f) => f.name.toString() == 'Create';
  bool _isHtlcUnlock(AbiFunction f) => f.name.toString() == 'Unlock';
  bool _isHtlcReclaim(AbiFunction f) => f.name.toString() == 'Reclaim';

  Future<AccountBlock> _getFrontierContractBlock() async =>
      (await zenon!.ledger.getFrontierAccountBlock(htlcAddress))!;

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

  static P2pSwapsWorker getInstance() {
    _instance ??= P2pSwapsWorker();
    return _instance!;
  }

  @override
  void dispose() {
    _activeSwapsBox?.close();

    super.dispose();
  }
}

/*
Future<void> _saveLastCheckedHeightValueToCache(int height) async {
  await sharedPrefsService!.put(
     kHtlcLastCheckedHeightKey,
     height,
    );
}
 */
