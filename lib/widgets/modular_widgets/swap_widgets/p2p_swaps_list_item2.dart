import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';

class P2pSwapsListItem2 extends StatefulWidget {
  final P2pSwap swap;

  const P2pSwapsListItem2({
    required this.swap,
    Key? key,
  }) : super(key: key);

  @override
  _P2pSwapsListItemState createState() => _P2pSwapsListItemState();
}

class _P2pSwapsListItemState extends State<P2pSwapsListItem2> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0.0, 4),
            blurRadius: 6,
          ),
        ],
        borderRadius: BorderRadius.circular(
          8.0,
        ),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.swap.id),
          Text(widget.swap.state.name),
          Text(DateTime.fromMillisecondsSinceEpoch(widget.swap.startTime * 1000)
              .toIso8601String()),
          Text(DateTime.fromMillisecondsSinceEpoch(
                  widget.swap.expirationTime * 1000)
              .toIso8601String()),
        ],
      ),
    );
  }
}
