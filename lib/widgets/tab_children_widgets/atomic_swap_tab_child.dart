import 'package:flutter/material.dart';
import 'package:layout/layout.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/default_address_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/atomic_swap_widgets/create_atomic_swap_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/standard_fluid_layout.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/atomic_swap_widgets/active_swaps_card.dart';

class AtomicSwapTabChild extends StatelessWidget {
  final VoidCallback onStepperNotificationSeeMorePressed;

  const AtomicSwapTabChild({
    required this.onStepperNotificationSeeMorePressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _getLayout(context);
  }

  StandardFluidLayout _getLayout(BuildContext context) {
    return StandardFluidLayout(
      children: [
        FluidCell(
          height: kStaggeredNumOfColumns / 2,
          width: context.layout.value(
            xl: kStaggeredNumOfColumns ~/ 3,
            lg: kStaggeredNumOfColumns ~/ 3,
            md: kStaggeredNumOfColumns ~/ 3,
            sm: kStaggeredNumOfColumns,
            xs: kStaggeredNumOfColumns,
          ),
          child: const CreateAtomicSwapCard(),
        ),
        FluidCell(
          height: kStaggeredNumOfColumns / 2,
          width: context.layout.value(
            xl: kStaggeredNumOfColumns ~/ 1.5,
            lg: kStaggeredNumOfColumns ~/ 1.5,
            md: kStaggeredNumOfColumns ~/ 1.5,
            sm: kStaggeredNumOfColumns,
            xs: kStaggeredNumOfColumns,
          ),
          child: Consumer<SelectedAddressNotifier>(
            builder: (_, __, ___) =>
                ActiveSwapsCard(
                  onStepperNotificationSeeMorePressed:
                  onStepperNotificationSeeMorePressed,
                ),
          ),
        ),
      ],
    );
  }
}
