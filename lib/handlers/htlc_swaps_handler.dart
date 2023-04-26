import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/blocs/auto_unlock_htlc_worker.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/block_data.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class HtlcSwapsHandler {
  static HtlcSwapsHandler? _instance;

  static HtlcSwapsHandler getInstance() {
    _instance ??= HtlcSwapsHandler();
    return _instance!;
  }

  Future<void> run() async {
    final activeSwaps = htlcSwapsService!.getPendingAndActiveSwaps();
    if (activeSwaps.isNotEmpty) {
      if (await _areThereNewHtlcBlocks()) {
        final newBlocks = await _getNewHtlcBlocks();
        await _goThroughHtlcBlocks(newBlocks.reversed.toList());
      }
      await _checkForExpiredSwaps(activeSwaps);
      _checkForAutoUnlockableSwaps(activeSwaps);
    }
    sl<AutoUnlockHtlcWorker>().autoUnlock();

    Future.delayed(const Duration(seconds: 5), () async {
      run();
    });
  }

  Future<int?> _getHtlcFrontierHeight() async {
    final frontier = await zenon!.ledger.getFrontierAccountBlock(htlcAddress);
    return frontier?.height;
  }

  Future<bool> _areThereNewHtlcBlocks() async {
    final frontier = await _getHtlcFrontierHeight();
    return frontier != null &&
        frontier > htlcSwapsService!.getLastCheckedHtlcBlockHeight();
  }

  Future<List<AccountBlock>> _getNewHtlcBlocks() async {
    final List<AccountBlock> blocks = [];
    final oldestStartTime = _getOldestActiveSwapStartTime() ?? 0;
    final lastCheckedHeight = htlcSwapsService!.getLastCheckedHtlcBlockHeight();

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

  Future<void> _goThroughHtlcBlocks(List<AccountBlock> blocks) async {
    // Check through blocks from oldest to newest
    for (final block in blocks) {
      await _extractSwapDataFromBlock(block);

      // TODO: Take into use. Not used for now to make debugging easier.
      // htlcSwapsService!.storeLastCheckedHtlcBlockHeight(block.height);
    }
  }

  Future<void> _extractSwapDataFromBlock(AccountBlock htlcBlock) async {
    if (htlcBlock.blockType != BlockTypeEnum.contractReceive.index) {
      return;
    }

    final pairedBlock = htlcBlock.pairedAccountBlock!;
    final blockData = AccountBlockUtils.getDecodedBlockData(
        Definitions.htlc, pairedBlock.data);

    if (blockData == null) {
      return;
    }

    final swap = _tryGetSwapFromBlockData(blockData);
    if (swap == null) {
      return;
    }
    switch (blockData.function) {
      case 'Create':
        if (swap.state == P2pSwapState.pending) {
          swap.state = P2pSwapState.active;
          await htlcSwapsService!.storeSwap(swap);
        } else if (pairedBlock.hash.toString() != swap.initialHtlcId &&
            swap.counterHtlcId == null) {
          if (!_isValidCounterHtlc(pairedBlock, blockData, swap)) {
            return;
          }
          swap.counterHtlcId = pairedBlock.hash.toString();
          swap.toAmount = pairedBlock.amount;
          swap.toTokenStandard = pairedBlock.token!.tokenStandard.toString();
          swap.toDecimals = pairedBlock.token!.decimals;
          swap.toSymbol = pairedBlock.token!.symbol;
          swap.counterHtlcExpirationTime =
              blockData.params['expirationTime'].toInt();
          await htlcSwapsService!.storeSwap(swap);
        }
        return;
      case 'Unlock':
        if (swap.preimage == null) {
          if (!blockData.params.containsKey('preimage')) {
            return;
          }
          swap.preimage =
              FormatUtils.encodeHexString(blockData.params['preimage']);
          await htlcSwapsService!.storeSwap(swap);
        }

        if (swap.direction == P2pSwapDirection.incoming &&
            blockData.params['id'].toString() == swap.initialHtlcId) {
          swap.state = P2pSwapState.completed;
          await htlcSwapsService!.storeSwap(swap);
        }
        return;
      /*case 'Reclaim':
        bool isSelfReclaim = false;
        if (swap.direction == P2pSwapDirection.outgoing &&
            blockData.params['id'].toString() == swap.initialHtlcId) {
          isSelfReclaim = true;
        } else if (swap.direction == P2pSwapDirection.incoming &&
            blockData.params['id'].toString() == swap.counterHtlcId!) {
          isSelfReclaim = true;
        }
        if (isSelfReclaim) {
          swap.state = P2pSwapState.unsuccessful;
          await htlcSwapsService!.storeSwap(swap);
        }
        return;*/
    }
  }

  HtlcSwap? _tryGetSwapFromBlockData(BlockData data) {
    if (data.params.containsKey('hashLock')) {
      final hashLock = Hash.fromBytes(data.params['hashLock']).toString();
      return htlcSwapsService!.getSwapByHashLock(hashLock);
    }
    if (data.params.containsKey('id')) {
      return htlcSwapsService!.getSwapById(data.params['id'].toString()) ??
          htlcSwapsService!
              .getSwapByCounterHtlcId(data.params['id'].toString());
    }
    return null;
  }

  bool _isValidCounterHtlc(AccountBlock block, BlockData data, HtlcSwap swap) {
    // Verify that the recipient is the initiator's address
    if (!data.params.containsKey('hashLocked') ||
        data.params['hashLocked'] != Address.parse(swap.selfAddress)) {
      return false;
    }

    // Verify that the creator is the counterparty.
    if (block.address != Address.parse(swap.counterpartyAddress)) {
      return false;
    }

    // Verify that the hash types match.
    if (!data.params.containsKey('hashType') ||
        data.params['hashType'].toInt() != swap.hashType) {
      return false;
    }

    // Verify that block data contains an expiration time parameter.
    if (!data.params.containsKey('expirationTime')) {
      return false;
    }

    return true;
  }

  Future<void> _checkForExpiredSwaps(List<HtlcSwap> activeSwaps) async {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final swap in activeSwaps) {
      if (swap.initialHtlcExpirationTime < now ||
          (swap.counterHtlcExpirationTime != null &&
              swap.counterHtlcExpirationTime! < now)) {
        swap.state = P2pSwapState.reclaimable;
        await htlcSwapsService!.storeSwap(swap);
      }
    }
  }

  void _checkForAutoUnlockableSwaps(List<HtlcSwap> activeSwaps) {
    for (final swap in activeSwaps) {
      if (swap.direction == P2pSwapDirection.incoming &&
          swap.state == P2pSwapState.active &&
          swap.preimage != null) {
        sl<AutoUnlockHtlcWorker>().addHash(Hash.parse(swap.initialHtlcId));
      }
    }
  }

  int? _getOldestActiveSwapStartTime() {
    final swaps = htlcSwapsService!.getPendingAndActiveSwaps();
    return swaps.isNotEmpty
        ? swaps
            .reduce((e1, e2) => e1.startTime > e2.startTime ? e1 : e2)
            .startTime
        : null;
  }
}
