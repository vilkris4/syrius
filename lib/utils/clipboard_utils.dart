import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/toast_utils.dart';

class ClipboardUtils {
  static void copyToClipboard(String stringValue, BuildContext context) {
    Clipboard.setData(
      ClipboardData(
        text: stringValue,
      ),
    ).then((_) => ToastUtils.showToast(context, 'Copied to clipboard'));
  }

  static void pasteToClipboard(
      BuildContext context, Function(String) callback) {
    Clipboard.getData('text/plain').then((value) {
      if (value != null) {
        callback(value.text!);
      } else {
        NotificationUtils.sendNotificationError(
          Exception('The clipboard data could not be obtained'),
          'Something went wrong while getting the clipboard data',
        );
      }
    });
  }
}
