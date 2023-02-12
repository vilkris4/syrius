import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';

class InfoItemWidget extends StatefulWidget {
  final String id;
  final String value;
  final double width;

  const InfoItemWidget({
    required this.id,
    required this.value,
    this.width = 240.0,
    Key? key,
  }) : super(key: key);

  @override
  State<InfoItemWidget> createState() => _InfoItemWidgetState();
}

class _InfoItemWidgetState extends State<InfoItemWidget> {
  @override
  Widget build(BuildContext context) {
    final shouldShrink = widget.width < 230;
    final hasValue = widget.value != "0" * 64;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
      width: widget.width,
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
              widget.id,
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ),
          Row(
            children: <Widget>[
              Visibility(
                visible: !shouldShrink,
                child: Text(
                  widget.id,
                  style: Theme.of(context).textTheme.subtitle1,
                ),
              ),
              Visibility(
                visible: !shouldShrink,
                child: const Spacer(),
              ),
              hasValue
                  ? Text(
                      FormatUtils.formatLongString(widget.value),
                      style: Theme.of(context).textTheme.bodyText2,
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      "Pending...",
                      style: Theme.of(context).textTheme.bodyText2,
                      textAlign: TextAlign.center,
                    ),
              Visibility(
                  visible: hasValue && shouldShrink, child: const Spacer()),
              Visibility(
                visible: hasValue,
                child: CopyToClipboardIcon(
                  widget.value,
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
