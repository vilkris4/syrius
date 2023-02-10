import 'dart:math';
import 'package:flutter/services.dart';
import 'package:hex/hex.dart';
import 'package:intl/intl.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class FormatUtils {
  static List<TextInputFormatter> getAmountTextInputFormatters(
    String replacementString,
  ) =>
      [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*?$'),
            replacementString: replacementString),
        FilteringTextInputFormatter.deny(
          RegExp(r'^0\d+'),
          replacementString: replacementString,
        ),
      ];

  static List<TextInputFormatter> getPlasmaAmountTextInputFormatters(
    String replacementString,
  ) =>
      [
        FilteringTextInputFormatter.digitsOnly,
        FilteringTextInputFormatter.deny(
          RegExp(r'^0\d+'),
          replacementString: replacementString,
        ),
      ];

  static String encodeHexString(List<int> input) => HEX.encode(input);
  static List<int> decodeHexString(String input) => HEX.decode(input);

  static String formatDate(int timestampMillis,
      {String dateFormat = kDefaultDateFormat}) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    return DateFormat(dateFormat).format(date);
  }

  static String formatExpirationTime(int expirationTime) {
    const int minute = 60;
    const int hour = 60 * minute;
    const int day = 24 * hour;

    int s, m, h, d = 0;
    String formattedTime = "";

    if (expirationTime > day) {
      d = expirationTime ~/ day;
      expirationTime %= day;
      formattedTime += "$d d ";
    }
    if (expirationTime > hour) {
      h = expirationTime ~/ hour;
      expirationTime %= hour;
      formattedTime += "$h h ";
    }
    if (expirationTime > minute) {
      m = expirationTime ~/ minute;
      expirationTime %= minute;
      formattedTime += "$m min ";
    }
    s = expirationTime.remainder(minute);
    formattedTime += "$s s";

    return (formattedTime);
  }

  static String extractNameFromEnum<T>(T enumValue) {
    String valueName = enumValue.toString().split('.')[1];
    if (RegExp(r'^[a-z]+[A-Z]+').hasMatch(valueName)) {
      List<String> parts = valueName
          .split(RegExp(r'(?<=[a-z])(?=[A-Z])'))
          .map((e) => e.toLowerCase())
          .toList();
      parts.first = parts.first.capitalize();
      return parts.join(' ');
    }
    return valueName.capitalize();
  }

  static int subtractDaysFromDate(int numDays, DateTime referenceDate) {
    return referenceDate
        .subtract(
          Duration(
            days: kStandardChartNumDays.toInt() - 1 - numDays,
          ),
        )
        .millisecondsSinceEpoch;
  }

  static String formatLongString(String longString) {
    try {
      return longString.substring(0, 7) +
          "..." +
          longString.substring(longString.length - 7, longString.length);
    } catch (e) {
      return longString;
    }
  }

  static String formatAtomicSwapAmount(
      int amount, TokenStandard tokenStandard) {
    NumberFormat commaFormat = NumberFormat.decimalPattern('en_us');
    return commaFormat.format(amount / pow(10, 8));
  }
}
