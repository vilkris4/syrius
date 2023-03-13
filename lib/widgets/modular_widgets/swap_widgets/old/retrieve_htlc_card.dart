import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/retrieve_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/loading_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/card_scaffold.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class RetrieveHtlcCard extends StatefulWidget {
  const RetrieveHtlcCard({
    Key? key,
  }) : super(key: key);

  @override
  State<RetrieveHtlcCard> createState() => _RetrieveHtlcCardState();
}

class _RetrieveHtlcCardState extends State<RetrieveHtlcCard> {
  final GlobalKey<LoadingButtonState> _retrieveHtlcButtonKey = GlobalKey();

  TextEditingController _retrieveHtlcController = TextEditingController();

  String? _errorText;

  @override
  void initState() {
    super.initState();
  }

  //TODO: Confirm CardScaffold description
  @override
  Widget build(BuildContext context) {
    return CardScaffold(
      title: '  Retrieve HTLC',
      description: 'update this text',
      childBuilder: () => _getWidgetBody(context),
    );
  }

  Widget _getWidgetBody(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          _getInputField(), //TODO: fix this
          const SizedBox(width: 15.0),
          _getRetrieveHtlcViewModel(),
        ],
      ),
    );
  }

  Widget _getInputField() {
    return SizedBox(
      height: 50.0,
      width: 100.0,
      child: Expanded(
        child: InputField(
          onChanged: (value) {
            setState(() {
              _errorText = _retrieveHtlcController.text.isEmpty
                  ? null
                  : InputValidators.checkHash(value);
            });
          },
          validator: (value) => InputValidators.checkHash(value),
          controller: _retrieveHtlcController,
          suffixIcon: RawMaterialButton(
            child: const Icon(
              Icons.content_paste,
              color: AppColors.darkHintTextColor,
              size: 15.0,
            ),
            shape: const CircleBorder(),
            onPressed: () {
              ClipboardUtils.pasteToClipboard(context, (String value) {
                _retrieveHtlcController.text = value;
                setState(() {});
              });
            },
          ),
          suffixIconConstraints: const BoxConstraints(
            maxWidth: 45.0,
            maxHeight: 20.0,
          ),
          errorText: _errorText,
          contentLeftPadding: 20.0,
          hintText: 'HTLC ID',
        ),
      ),
    );
  }

  Widget _getRetrieveHtlcViewModel() {
    return ViewModelBuilder<RetrieveHtlcBloc>.reactive(
      onModelReady: (model) {
        model.stream.listen(
          (event) {
            if (event is HtlcInfo) {
              setState(() {
                _retrieveHtlcButtonKey.currentState?.animateReverse();
              });
              showDialogWithNoAndYesOptions(
                  context: context,
                  title: "Found ${event.id}",
                  description: "${event.id}",
                  onYesButtonPressed: onYesButtonPressed);
            }
          },
          onError: (error) {
            print("errored");

            setState(() {
              _errorText = error.toString();
              _retrieveHtlcButtonKey.currentState?.animateReverse();
            });
          },
        );
      },
      builder: (_, model, __) => _geRetrieveHtlcButton(model),
      viewModelBuilder: () => RetrieveHtlcBloc(),
    );
  }

  Widget _geRetrieveHtlcButton(RetrieveHtlcBloc model) {
    return LoadingButton.stepper(
      onPressed: _isInputValid() ? () => _onRetrieveButtonPressed(model) : null,
      text: 'Retrieve  HTLC',
      key: _retrieveHtlcButtonKey,
    );
  }

  void _onRetrieveButtonPressed(RetrieveHtlcBloc model) async {
    _retrieveHtlcButtonKey.currentState?.animateForward();
    await model.getHtlcInfo(Hash.parse(_retrieveHtlcController.text));
  }

  void onYesButtonPressed() {
    print("yes");
  }

  bool _isInputValid() =>
      InputValidators.checkHash(_retrieveHtlcController.text) == null;

  @override
  void dispose() {
    _retrieveHtlcController.dispose();
    super.dispose();
  }
}
