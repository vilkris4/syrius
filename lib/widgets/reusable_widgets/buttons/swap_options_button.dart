import 'package:flutter/material.dart';

class SwapOptionsButton extends StatefulWidget {
  final VoidCallback onClick;
  final String primaryText;
  final String secondaryText;

  const SwapOptionsButton({
    Key? key,
    required this.primaryText,
    required this.secondaryText,
    required this.onClick,
  }) : super(key: key);

  @override
  _SwapOptionsButtonState createState() => _SwapOptionsButtonState();
}

//TODO:
// Decide on splashColor
// fix text overflow when window is shrunk
// fix corner radius on hover

class _SwapOptionsButtonState extends State<SwapOptionsButton> {
  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(
        8.0,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        splashColor: Theme.of(context).colorScheme.secondaryContainer,
        // Other options
        // .tertiaryContainer,
        // Colors.transparent,
        // AppColors.znnColor,
        onTap: () {
          setState(() {
            widget.onClick.call();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(15.0),
          decoration: BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0.0, 4),
                blurRadius: 6,
                spreadRadius: 8.0,
              ),
            ],
            borderRadius: BorderRadius.circular(
              8.0,
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.primaryText,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(
                    height: 8.0,
                  ),
                  Text(
                    widget.secondaryText,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const Spacer(),
              Column(children: const [
                Icon(Icons.keyboard_arrow_right, size: 18.0),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
