import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

showOkDialog({
  required BuildContext context,
  required String title,
  required String description,
  required VoidCallback onActionButtonPressed,
}) =>
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            child: Text(
              'OK',
              style: Theme.of(context).textTheme.bodyText1,
            ),
            onPressed: onActionButtonPressed,
          ),
        ],
      ),
    );

showDialogWithNoAndYesOptions({
  required BuildContext context,
  required String title,
  required String description,
  required VoidCallback onYesButtonPressed,
}) =>
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            child: Text(
              'No',
              style: Theme.of(context).textTheme.bodyText1,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text(
              'Yes',
              style: Theme.of(context).textTheme.bodyText1,
            ),
            onPressed: onYesButtonPressed,
            style: Theme.of(context).textButtonTheme.style!.copyWith(
                  backgroundColor: MaterialStateColor.resolveWith(
                      (states) => AppColors.errorColor),
                ),
          ),
        ],
      ),
    );

showCustomDialog({required BuildContext context, required Widget content}) =>
    showGeneralDialog(
      context: context,
      barrierLabel: '',
      barrierDismissible: true,
      pageBuilder: (context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          Center(child: content),
    );
