import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';

class InfoItemWidget extends StatelessWidget {
  final String label;
  final String value;
  final double width;
  final bool canBeCopied;
  final bool truncateValue;

  const InfoItemWidget({
    required this.label,
    required this.value,
    this.width = 240.0,
    this.canBeCopied = true,
    this.truncateValue = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shouldShrink = width < 230;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          8.0,
        ),
        color: Theme.of(context).dividerTheme.color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Visibility(
            visible: shouldShrink,
            child: Text(
              label,
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ),
          Row(
            children: <Widget>[
              Visibility(
                visible: !shouldShrink,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.subtitle1,
                ),
              ),
              Visibility(
                visible: !shouldShrink,
                child: const Spacer(),
              ),
              Text(
                truncateValue ? FormatUtils.formatLongString(value) : value,
                style: Theme.of(context).textTheme.bodyText2,
                textAlign: TextAlign.center,
              ),
              Visibility(
                  visible: canBeCopied && shouldShrink, child: const Spacer()),
              Visibility(
                visible: canBeCopied,
                child: CopyToClipboardIcon(
                  value,
                  iconColor: AppColors.lightPrimaryContainer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.only(left: 8.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
