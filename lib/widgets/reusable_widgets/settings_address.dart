//TODO: Update ViewModelBuilder when menu option is selected

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hive/hive.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/htlc/update_proxy_unlocking_htlc_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/loading_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/material_icon_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/outlined_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/settings_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/icons/copy_to_clipboard_icon.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_field/input_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class SettingsAddress extends StatefulWidget {
  final String? address;
  final void Function(String?) onAddressLabelPressed;

  const SettingsAddress({
    required this.address,
    required this.onAddressLabelPressed,
    Key? key,
  }) : super(key: key);

  @override
  _SettingsAddressState createState() => _SettingsAddressState();
}

class _SettingsAddressState extends State<SettingsAddress> {
  bool _editable = false;
  bool _proxyUnlockable = true;

  late final Future<bool?> _proxyUnlockFuture;
  final UpdateProxyUnlockingHtlcBloc _updateProxyUnlockingHtlcModel =
      UpdateProxyUnlockingHtlcBloc();

  final TextEditingController _labelController = TextEditingController();

  final GlobalKey<MyOutlinedButtonState> _changeButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _proxyUnlockButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _labelController.text = kAddressLabelMap[widget.address]!;
    _proxyUnlockFuture = zenon!.embedded.htlc
        .getProxyUnlockStatus(Address.parse(widget.address!));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _proxyUnlockFuture,
      builder: (_, snapshot) {
        if (snapshot.hasData && mounted) {
          _proxyUnlockable = snapshot.data!;
          return Container(
            margin: const EdgeInsets.symmetric(
              vertical: 5.0,
            ),
            child: _editable
                ? _getAddressLabelInputField()
                : _getAddressLabel(context),
          );
        } else if (snapshot.hasError) {
          return SyriusErrorWidget(snapshot.error!);
        }
        return Container();
      },
    );
  }

  Row _getAddressLabel(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(
              10.0,
            ),
            onTap: () => widget.onAddressLabelPressed(widget.address),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelController.text,
                    style: Theme.of(context).textTheme.bodyText1!.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyText1!
                              .color!
                              .withOpacity(0.7),
                        ),
                  ),
                  _getAddressTextWidget(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 5.0,
        ),
        _getProxyUnlockButtonViewModel(),
        const SizedBox(
          width: 5.0,
        ),
        MaterialIconButton(
          iconData: Icons.edit,
          onPressed: () {
            setState(() {
              _editable = true;
            });
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(
          width: 5.0,
        ),
        CopyToClipboardIcon(
          widget.address,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        _getPopupMenuButton(),
        const SizedBox(
          width: 5.0,
        ),
      ],
    );
  }

  Widget _getAddressLabelInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40.0,
                child: InputField(
                  controller: _labelController,
                  onSubmitted: (value) {
                    if (_labelController.text !=
                        kAddressLabelMap[widget.address]!) {
                      _onChangeButtonPressed();
                    }
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                  inputtedTextStyle:
                      Theme.of(context).textTheme.bodyText2!.copyWith(
                            color: AppColors.znnColor,
                          ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  contentLeftPadding: 5.0,
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.znnColor),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 2.0,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 15.0,
            ),
            SettingsButton(
              onPressed:
                  _labelController.text != kAddressLabelMap[widget.address]!
                      ? _onChangeButtonPressed
                      : null,
              text: 'Change',
              key: _changeButtonKey,
            ),
            MaterialIconButton(
              onPressed: () {
                setState(() {
                  _labelController.text = kAddressLabelMap[widget.address]!;
                  _editable = false;
                });
              },
              iconData: Icons.clear,
            ),
          ],
        ),
        _getAddressTextWidget(),
      ],
    );
  }

  Text _getAddressTextWidget() {
    return Text(
      widget.address!,
      style: Theme.of(context).textTheme.bodyText2,
    );
  }

  void _onChangeButtonPressed() async {
    try {
      _changeButtonKey.currentState!.showLoadingIndicator(true);
      if (_labelController.text.isNotEmpty &&
          _labelController.text.length <= kAddressLabelMaxLength &&
          !kAddressLabelMap.containsValue(_labelController.text)) {
        await Hive.box(kAddressLabelsBox).put(
          widget.address,
          _labelController.text,
        );
        kAddressLabelMap[widget.address!] = _labelController.text;
        setState(() {
          _editable = false;
        });
      } else if (_labelController.text.isEmpty) {
        NotificationUtils.sendNotificationError(
          'Label can\'t be empty',
          'Label can\'t be empty',
        );
      } else if (_labelController.text.length > kAddressLabelMaxLength) {
        NotificationUtils.sendNotificationError(
          'The label ${_labelController.text} is ${_labelController.text.length} '
              'characters long, which is more than the $kAddressLabelMaxLength limit.',
          'The label has more than $kAddressLabelMaxLength characters',
        );
      } else {
        NotificationUtils.sendNotificationError(
          'Label ${_labelController.text}'
              ' already exists in the database',
          'Label already exists',
        );
      }
    } catch (e) {
      NotificationUtils.sendNotificationError(
        e,
        'Something went wrong while changing the address label',
      );
    } finally {
      _changeButtonKey.currentState!.showLoadingIndicator(false);
    }
  }

  Widget _getPopupMenuButton() {
    final List<String> options = [
      '${_proxyUnlockable ? 'Disable' : 'Enable'} proxy unlock',
    ];
    return SizedBox(
      width: 40.0,
      child: PopupMenuButton<String>(
        onSelected: (String selection) {
          if (selection == options[0]) {
            _updateProxyUnlocking(_updateProxyUnlockingHtlcModel);
          }
        },
        icon: const Icon(
          Icons.more_vert,
          color: AppColors.znnColor,
        ),
        splashRadius: 15.0,
        itemBuilder: (BuildContext context) {
          return options.map((String selection) {
            return PopupMenuItem<String>(
              value: selection,
              height: kMinInteractiveDimension / 2,
              child: Row(
                children: [
                  Text(selection),
                  const SizedBox(width: 5.0),
                  const Icon(FontAwesome.question_circle, size: 15.0)
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _getProxyUnlockButtonViewModel() {
    return ViewModelBuilder<UpdateProxyUnlockingHtlcBloc>.reactive(
      fireOnModelReadyOnce: true,
      onModelReady: (model) {
        model.stream.listen(
          (event) async {
            if (event is AccountBlockTemplate) {
              bool unconfirmed = true;
              while (unconfirmed) {
                await Future.delayed(const Duration(seconds: 3));
                if (await zenon!.ledger.getAccountBlockByHash(event.hash) !=
                    null) {
                  unconfirmed = false;
                }
              }
              setState(() {
                _proxyUnlockButtonKey.currentState?.animateReverse();
              });
            }
          },
          onError: (error) {
            setState(() {
              _proxyUnlockable = !_proxyUnlockable;
              _proxyUnlockButtonKey.currentState?.animateReverse();
            });
          },
        );
      },
      builder: (_, model, __) => !_proxyUnlockable
          ? Tooltip(
              message: 'Proxy unlocking is disabled',
              child: LoadingButton.icon(
                key: _proxyUnlockButtonKey,
                minimumSize: const Size(25.0, 25.0),
                icon: const Icon(Octicons.primitive_dot, color: Colors.red),
                outlineColor: Theme.of(context).colorScheme.primary,
                onPressed: () {},
              ),
            )
          : Container(),
      viewModelBuilder: () => _updateProxyUnlockingHtlcModel,
    );
  }

  void _updateProxyUnlocking(UpdateProxyUnlockingHtlcBloc model) {
    setState(() {
      _proxyUnlockable = !_proxyUnlockable;
    });
    _proxyUnlockButtonKey.currentState?.animateForward();
    model.updateProxy(
      address: Address.parse(widget.address!),
      allowed: _proxyUnlockable,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }
}
