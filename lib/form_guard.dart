import 'app_strings.dart';

import 'package:flutter/material.dart';

class ConfirmDiscard extends StatefulWidget {
  const ConfirmDiscard({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;
  @override
  State<ConfirmDiscard> createState() => _ConfirmDiscardState();
}

class _ConfirmDiscardState extends State<ConfirmDiscard> {
  bool _leaving = false;
  bool _asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.dirty || _leaving,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _asking) return;
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, "تجاهل التغييرات؟")),
          content: Text(tr(context, "ستفقد التغييرات غير المحفوظة.")),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, "متابعة التعديل")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, "تجاهل")),
            ),
          ],
        ),
      );
      _asking = false;
      if (context.mounted && discard == true) {
        setState(() => _leaving = true);
        Navigator.pop(context);
      }
    },
    child: widget.child,
  );
}
