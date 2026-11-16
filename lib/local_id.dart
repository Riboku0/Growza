import 'dart:math';

String newLocalId(String kind) =>
    '$kind-${DateTime.now().toUtc().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
