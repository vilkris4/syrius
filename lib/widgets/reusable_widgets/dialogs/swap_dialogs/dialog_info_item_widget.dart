import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class DialogInfoItemWidget extends StatefulWidget {
  final String id;
  final String value;
  final Address address;
  final Token token;

  const DialogInfoItemWidget({
    required this.id,
    required this.value,
    required this.address,
    required this.token,
    Key? key,
  }) : super(key: key);

  @override
  State<DialogInfoItemWidget> createState() => _DialogInfoItemWidgetState();
}

class _DialogInfoItemWidgetState extends State<DialogInfoItemWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          8.0,
        ),
        color: Theme.of(context).colorScheme.tertiaryContainer,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(
                width: 5.0,
              ),
              Text(
                widget.id,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: (Theme.of(context).textTheme.subtitle1?.color)),
                //.subtitle1,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(
            height: 5.0,
          ),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 5.0,
              ),
              Text(
                widget.value,
                style: Theme.of(context).textTheme.headline4?.copyWith(
                      color: Theme.of(context).colorScheme.inverseSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              Visibility(
                child: Row(children: [
                  Text(
                    " ${widget.token.symbol}",
                    style: Theme.of(context).textTheme.headline4?.copyWith(
                          color: Theme.of(context).colorScheme.inverseSurface,
                        ),
                  ),
                  Text(
                    "  ●",
                    style: Theme.of(context).textTheme.headline1!.copyWith(
                          color: ColorUtils.getTokenColor(
                              (widget.token.tokenStandard)),
                        ),
                  ),
                ]),
                visible: (
                    widget.id == "Locked amount" ||
                    widget.id == "You receive" ||
                    widget.id == "Sending"
                ),
              ),
              const Spacer(),
              Text(
                FormatUtils.formatLongString(widget.address.toString()),
                style: Theme.of(context).textTheme.subtitle2,
              ),
              CopyToClipboardIcon(
                widget.address.toString(),
                iconColor: AppColors.lightDividerColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
