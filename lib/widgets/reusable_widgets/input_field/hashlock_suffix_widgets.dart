import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

class HashlockSuffixWidgets extends StatelessWidget {
  final VoidCallback? onGeneratePressed;
  final VoidCallback? onClipboardPressed;

  const HashlockSuffixWidgets({
    this.onGeneratePressed,
    this.onClipboardPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
          visible: onGeneratePressed != null,
          child: HashlockSuffixGenerateWidget(
            onPressed: onGeneratePressed!,
            context: context,
          ),
        ),
        Visibility(
          visible: onClipboardPressed != null,
          child: HashlockSuffixClipboardWidget(
            onPressed: onClipboardPressed!,
            context: context,
          ),
        ),
      ],
    );
  }
}

class HashlockSuffixGenerateWidget extends InkWell {
  HashlockSuffixGenerateWidget({
    required VoidCallback onPressed,
    required BuildContext context,
    Key? key,
  }) : super(
          key: key,
          onTap: onPressed,
          child: Container(
            height: kAmountSuffixHeight,
            width: 75.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAmountSuffixRadius),
              border: Border.all(
                color: AppColors.maxAmountBorder,
              ),
            ),
            child: const Text(
              'GENERATE',
              style: TextStyle(
                fontSize: 12.0,
                color: AppColors.znnColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
}

class HashlockSuffixClipboardWidget extends RawMaterialButton {
  const HashlockSuffixClipboardWidget({
    required VoidCallback onPressed,
    required BuildContext context,
    Key? key,
  }) : super(
    key: key,
    child: const Icon(
      Icons.content_paste,
      color: AppColors.darkHintTextColor,
      size: 15.0,
    ),
    shape: const CircleBorder(),
    onPressed: onPressed,
    constraints: const BoxConstraints(),
  );
}