import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

class SecretSuffixScanWidget extends InkWell {
  SecretSuffixScanWidget({
    required VoidCallback onPressed,
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
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
}

class SecretCancelScanWidget extends InkWell {
  SecretCancelScanWidget({
    required VoidCallback onPressed,
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
              'Cancel',
              style: TextStyle(
                fontSize: 12.0,
                color: AppColors.znnColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
}
