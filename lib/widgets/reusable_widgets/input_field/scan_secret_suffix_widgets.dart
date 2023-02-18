import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

class ScanSecretSuffixWidgets extends StatelessWidget {
  final VoidCallback? onScanPressed;
  final VoidCallback? onClipboardPressed;

  const ScanSecretSuffixWidgets({
    this.onScanPressed,
    this.onClipboardPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
          visible: onScanPressed != null,
          child: SecretSuffixScanWidget(
            onPressed: onScanPressed!,
            context: context,
          ),
        ),
        Visibility(
          visible: onClipboardPressed != null,
          child: SecretSuffixClipboardWidget(
            onPressed: onClipboardPressed!,
            context: context,
          ),
        ),
        const SizedBox(width: 10.0),
      ],
    );
  }
}

class SecretSuffixScanWidget extends InkWell {
  SecretSuffixScanWidget({
    required VoidCallback onPressed,
    required BuildContext context,
    Key? key,
  }) : super(
          key: key,
          onTap: onPressed,
          child: Container(
            height: kAmountSuffixHeight,
            width: 50.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAmountSuffixRadius),
              border: Border.all(
                color: AppColors.maxAmountBorder,
              ),
            ),
            child: const Text(
              'SCAN',
              style: TextStyle(
                fontSize: 12.0,
                color: AppColors.znnColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
}

class SecretSuffixClipboardWidget extends RawMaterialButton {
  const SecretSuffixClipboardWidget({
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
          constraints: const BoxConstraints(
            minWidth: 40.0,
            minHeight: 0.0,
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
}
