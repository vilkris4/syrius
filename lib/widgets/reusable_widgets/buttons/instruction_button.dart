import 'package:flutter/material.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

class InstructionButton extends StatefulWidget {
  final String text;
  final String instructionText;
  final bool isEnabled;
  final VoidCallback onPressed;

  const InstructionButton({
    required this.text,
    required this.instructionText,
    required this.isEnabled,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  _InstructionButtonState createState() => _InstructionButtonState();
}

class _InstructionButtonState extends State<InstructionButton> {
  late bool _showLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.0,
      child: TextButton(
        child: Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.3,
          child: Text(
            widget.isEnabled ? widget.text : widget.instructionText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        onPressed: widget.isEnabled ? widget.onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.znnColor,
          disabledBackgroundColor: AppColors.znnColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      ),
    );
  }
}
