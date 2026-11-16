import 'package:flutter/widgets.dart';

class WorkspaceActions extends InheritedWidget {
  const WorkspaceActions({
    super.key,
    required this.onBackup,
    required super.child,
  });
  final VoidCallback onBackup;
  static WorkspaceActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceActions>();
  @override
  bool updateShouldNotify(WorkspaceActions oldWidget) => false;
}
