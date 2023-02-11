import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';

class InfoItemWidget extends StatefulWidget {
  final String id;
  final String value;

  const InfoItemWidget({
    required this.id,
    required this.value,
    Key? key,
  }) : super(key: key);

  @override
  State<InfoItemWidget> createState() => _InfoItemWidgetState();
}

class _InfoItemWidgetState extends State<InfoItemWidget> {
  @override
  Widget build(BuildContext context) {
    double _width = MediaQuery.of(context).size.width * 0.139;
    if (_width >= 240) {
      _width = 240;
    }
    bool _shrink = (_width < 230) ? true : false;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      width: _width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          8.0,
        ),
        color: Theme.of(context).dividerTheme.color,
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 5.0,
          top: 5.0,
          bottom: 5.0,
        ),
        child: Column(
          children: [
            Visibility(
              visible: _shrink,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    widget.id,
                    style: Theme.of(context).textTheme.subtitle1,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Visibility(
                  visible: !_shrink,
                  child: Text(
                    widget.id,
                    style: Theme.of(context).textTheme.subtitle1,
                    textAlign: TextAlign.left,
                  ),
                ),
                Visibility(
                  visible: !_shrink,
                  child: const Spacer(),
                ),
                Row(
                  children: (widget.value == "0" * 64)
                      ? [
                          Text(
                            "Pending...",
                            style: Theme.of(context).textTheme.bodyText2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            width: 15.0,
                            height: 30.0,
                          ),
                        ]
                      : [
                          Text(
                            FormatUtils.formatLongString(widget.value),
                            style: Theme.of(context).textTheme.bodyText2,
                            textAlign: TextAlign.center,
                          ),
                          //const Spacer(),
                        ],
                ),
                Visibility(
                    visible: (widget.value != "0" * 64 && _shrink),
                    child: const Spacer()),
                Visibility(
                  visible: (widget.value != "0" * 64),
                  child: CopyToClipboardIcon(
                    widget.value,
                    iconColor: AppColors.lightPrimaryContainer,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
