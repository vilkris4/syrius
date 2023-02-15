import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';

enum HtlcDetailsStatus {
  locking,
  unlocking,
  reclaiming,
  inProgress,
  expired,
}

class HtlcStatusDetails extends StatelessWidget {
  final int hashType;
  final int expirationTime;
  final HtlcDetailsStatus status;

  const HtlcStatusDetails({
    Key? key,
    required this.hashType,
    required this.expirationTime,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    if ([
      HtlcDetailsStatus.locking,
      HtlcDetailsStatus.unlocking,
      HtlcDetailsStatus.reclaiming
    ].contains(status)) {
      String statusText = 'Locking deposit';
      if (status == HtlcDetailsStatus.unlocking) {
        statusText = 'Unlocking deposit';
      } else if (status == HtlcDetailsStatus.reclaiming) {
        statusText = 'Reclaiming deposit';
      }
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SyriusLoadingWidget(
              size: 12.0,
              strokeWidth: 1.0,
            ),
            const SizedBox(
              width: 8.0,
            ),
            Text(
              statusText,
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      );
    }

    if (status == HtlcDetailsStatus.inProgress) {
      children.add(
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            final remaining = _computeSecondsRemaining(expirationTime);
            return Text(
              'Expires in ${_formatTime(remaining)}',
              style: Theme.of(context).textTheme.subtitle1,
            );
          },
        ),
      );
    }

    if (status == HtlcDetailsStatus.expired) {
      children.add(
        Text(
          'Swap has expired',
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }

    if (hashType == 1) {
      children.add(
        Text(
          'SHA-256',
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }

    return SizedBox(
      height: 20.0,
      child: Row(
        children: children.zip(
          List.generate(
            children.length - 1,
            (index) => Text(
              '   ●   ',
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ),
        ),
      ),
    );
  }

  int _computeSecondsRemaining(int expirationTime) {
    final remaining = expirationTime -
        ((DateTime.now().millisecondsSinceEpoch) / 1000).floor();
    return remaining > 0 ? remaining : 0;
  }

  String _formatTime(int seconds) {
    return Duration(seconds: seconds).toString().split('.').first;
  }
}
