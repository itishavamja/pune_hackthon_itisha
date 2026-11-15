import 'package:flutter/material.dart';

/// Opens a rounded bottom sheet that moves up with the keyboard.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder, {bool full = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: full ? BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94) : null,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: builder(ctx),
    ),
  );
}
