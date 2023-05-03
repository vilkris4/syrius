import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

class ImportantTextContainer extends StatelessWidget {
  final String text;
  final bool showBorder;

  const ImportantTextContainer({
    required this.text,
    this.showBorder = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        border: showBorder
            ? Border.all(
                width: 1.0,
                color: AppColors.errorColor,
              )
            : null,
        borderRadius: const BorderRadius.all(
          Radius.circular(8.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15.0, 20.0, 15.0, 20.0),
        child: Row(
          children: [
            const Icon(
              Icons.info,
              size: 20.0,
              color: Colors.white,
            ),
            const SizedBox(
              width: 15.0,
            ),
            Text(text, style: const TextStyle(fontSize: 14.0, height: 1)),
          ],
        ),
      ),
    );
  }
}
