import 'dart:async';
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:hive/hive.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/unlock_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_pair.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class P2pSwapsHandler {
  static P2pSwapsHandler? _instance;

  static P2pSwapsHandler getInstance() {
    _instance ??= P2pSwapsHandler();
    return _instance!;
  }

  // Note: Should these be moved to their own services?
  Future<void> storeHtlcPair(HtlcPair pair) async {
    await _openBoxes();
    Hive.box(kHtlcPairsBox).put(pair.hashLock, jsonEncode(pair.toJson()));
  }

  Future<void> storeSwap(P2pSwap swap) async {
    await _openBoxes();
    Hive.box(kP2pSwapsBox).put(swap.id, jsonEncode(swap.toJson()));
  }

  Future<void> deleteHtlcPair(HtlcPair pair) async {
    await _openBoxes();
    Hive.box(kHtlcPairsBox).delete(pair.hashLock);
  }

  Future<void> deleteSwap(P2pSwap swap) async {
    await _openBoxes();
    Hive.box(kP2pSwapsBox).delete(swap.id);
  }

  Future<void> run() async {
    Future.delayed(const Duration(seconds: 5), () async {
      await _openBoxes();
      final activeSwaps = _getActiveSwaps();
      if (activeSwaps.isNotEmpty) {
        if (await _areThereNewHtlcBlocks()) {
          final newBlocks = await _getNewHtlcBlocks();
          await _handleHtlcBlocks(newBlocks.reversed.toList());
        }
        await _checkForExpiredSwaps(activeSwaps);
      }
      run();
    });
  }

  Future<void> _openBoxes() async {
    if (!Hive.isBoxOpen(kP2pSwapsBox)) {
      await Hive.openBox(kP2pSwapsBox);
    }

    if (!Hive.isBoxOpen(kHtlcPairsBox)) {
      await Hive.openBox(kHtlcPairsBox,
          encryptionCipher:
              HiveAesCipher((kKeyStore!.getKeyPair(0).getPrivateKey())!));
    }

    if (!Hive.isBoxOpen(kLastCheckedHtlcBlockBox)) {
      await Hive.openBox(kLastCheckedHtlcBlockBox);
    }
  }

  Future<bool> _areThereNewHtlcBlocks() async {
    final frontier = await zenon!.ledger.getFrontierAccountBlock(htlcAddress);
    return frontier != null &&
        frontier.height > _getLastCheckedHtlcBlockHeight();
  }

  Future<List<AccountBlock>> _getNewHtlcBlocks() async {
    final List<AccountBlock> blocks = [];
    final oldestStartTime = _getOldestActiveSwapStartTime() ?? 0;
    final lastCheckedHeight = _getLastCheckedHtlcBlockHeight();

    int pageIndex = 0;
    while (true) {
      final fetched = await zenon!.ledger.getAccountBlocksByPage(htlcAddress,
          pageIndex: pageIndex, pageSize: 100);

      // Check if the last fetched block is older than the oldest active swap.
      final lastBlockConfirmation = fetched.list!.last.confirmationDetail;
      if (lastBlockConfirmation == null ||
          lastBlockConfirmation.momentumTimestamp < oldestStartTime) {
        for (final block in fetched.list!) {
          final confirmation = block.confirmationDetail;
          if (confirmation == null ||
              confirmation.momentumTimestamp < oldestStartTime) {
            break;
          }
          blocks.add(block);
        }
        break;
      }

      // Check if the last fetched block height is less than or equal to the
      // last checked block height.
      if (fetched.list!.last.height <= lastCheckedHeight) {
        for (final block in fetched.list!) {
          if (block.height <= lastCheckedHeight) {
            break;
          }
          blocks.add(block);
        }
        break;
      }

      blocks.addAll(fetched.list!);

      if (fetched.more == null || !fetched.more!) {
        break;
      }

      pageIndex += 1;
    }

    return blocks;
  }

  Future<void> _handleHtlcBlocks(List<AccountBlock> blocks) async {
    // Check through blocks from oldest to newest
    for (final block in blocks) {
      await _extractSwapDataFromBlock(block);
      //_storeLastCheckedHtlcBlockHeight(block.height);
    }
  }

  Future<void> _extractSwapDataFromBlock(AccountBlock htlcBlock) async {
    if (htlcBlock.blockType != BlockTypeEnum.contractReceive.index) {
      return;
    }

    final pairedBlock = htlcBlock.pairedAccountBlock!;
    final blockData =
        AccountBlockUtils.getDecodedBlockData(Definitions.htlc, pairedBlock);

    if (blockData == null) {
      return;
    }

    if (['Create', 'Unlock'].contains(blockData.function)) {
      if (!blockData.params.containsKey('hashLock')) {
        return;
      }
      final hashLock = Hash.fromBytes(blockData.params['hashLock']).toString();

      final htlcPair = _getHtlcPairByHashLock(hashLock);
      if (htlcPair == null) {
        return;
      }

      final swap = _getSwapById(htlcPair.initialHtlcId);
      if (swap == null) {
        return;
      }

      switch (blockData.function) {
        case 'Create':
          if (swap.state == P2pSwapState.pending) {
            swap.state = P2pSwapState.active;
            await storeSwap(swap);
          } else if (pairedBlock.hash.toString() != htlcPair.initialHtlcId &&
              htlcPair.counterHtlcId.isEmpty) {
            htlcPair.counterHtlcId = pairedBlock.hash.toString();
            swap.toAmount = pairedBlock.amount;
            swap.toToken = pairedBlock.token;
            await storeHtlcPair(htlcPair);
            await storeSwap(swap);
          }
          return;
        case 'Unlock':
          if (htlcPair.preimage.isEmpty) {
            if (!blockData.params.containsKey('preimage')) {
              return;
            }
            htlcPair.preimage = hex.encode(blockData.params['preimage']);
            await storeHtlcPair(htlcPair);
          }
          if (swap.direction == P2pSwapDirection.incoming) {
            UnlockHtlcBloc().unlockHtlc(
              id: Hash.parse(htlcPair.initialHtlcId),
              preimage: htlcPair.preimage,
              hashLocked: swap.selfAddress,
            );
            swap.state = P2pSwapState.completed;
            await storeSwap(swap);
          }
          return;
      }
    }
  }

  Future<void> _checkForExpiredSwaps(List<P2pSwap> activeSwaps) async {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final swap in activeSwaps) {
      if (swap.expirationTime < now) {
        swap.state = P2pSwapState.reclaimable;
        await storeSwap(swap);
      }
    }
  }

  void _storeLastCheckedHtlcBlockHeight(int height) {
    Hive.box(kLastCheckedHtlcBlockBox).put(kLastCheckedHtlcBlockKey, height);
  }

  int _getLastCheckedHtlcBlockHeight() {
    return Hive.box(kLastCheckedHtlcBlockBox)
        .get(kLastCheckedHtlcBlockKey, defaultValue: 0);
  }

  int? _getOldestActiveSwapStartTime() {
    final swaps = _getActiveSwaps();
    return swaps.isNotEmpty
        ? swaps
            .reduce((e1, e2) => e1.startTime > e2.startTime ? e1 : e2)
            .startTime
        : null;
  }

  List<P2pSwap> _getActiveSwaps() {
    print(Hive.box(kP2pSwapsBox).values.toList().toString());
    return Hive.box(kP2pSwapsBox)
        .values
        .where((e) => [P2pSwapState.pending, P2pSwapState.active]
            .contains(P2pSwap.fromJson(jsonDecode(e)).state))
        .map((e) => P2pSwap.fromJson(jsonDecode(e)))
        .toList();
  }

  HtlcPair? _getHtlcPairByHashLock(String hashLock) {
    final pair = Hive.box(kHtlcPairsBox).get(hashLock, defaultValue: null);
    return pair != null ? HtlcPair.fromJson(jsonDecode(pair)) : null;
  }

  P2pSwap? _getSwapById(String id) {
    final swap = Hive.box(kP2pSwapsBox).get(id, defaultValue: null);
    return swap != null ? P2pSwap.fromJson(jsonDecode(swap)) : null;
  }
}
