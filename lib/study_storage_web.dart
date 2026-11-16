import 'package:web/web.dart' as web;

const _workspaceKey = 'istudy-workspace';

Future<String?> readWorkspace({
  required String Function(String?) normalize,
}) async => web.window.localStorage.getItem(_workspaceKey);

Future<void> writeWorkspace(String snapshot) async =>
    web.window.localStorage.setItem(_workspaceKey, snapshot);
