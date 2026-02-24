import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../Component/theme_colors.dart';

class CustomToast {
  /// Shows a toast with Parasto theme styling
  /// Uses warm navy background with off-white text for consistency
  static void showToast(String text) {
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: cParastoSurface,  // Warm navy surface
      textColor: cParastoTextPrimary,    // Warm off-white
      fontSize: 14.0,
    );
  }
}

Snack(String msg, BuildContext ctx, Color color) {
  var snackBar = SnackBar(
      backgroundColor: color,
      content: Text(
        msg,
        textAlign: TextAlign.center,
      ));
  ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
}