import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';

abstract final class LocalAuthRules {
  static const iterations = 600000;
  static const saltBytes = 16;
  static const digestBytes = 32;
  static const minPasswordCharacters = 8;
  static const maxPasswordCharacters = 256;
}

class PasswordFingerprint {
  const PasswordFingerprint(this.salt, this.digest, this.iterations);
  final String salt, digest;
  final int iterations;
}

class PasswordHasher {
  const PasswordHasher({this.iterations = LocalAuthRules.iterations});
  final int iterations;
  Future<PasswordFingerprint> create(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(
      LocalAuthRules.saltBytes,
      (_) => random.nextInt(256),
    );
    final bytes = await compute(_derivePassword, {
      'password': password,
      'salt': salt,
      'iterations': iterations,
    });
    return PasswordFingerprint(
      base64Encode(salt),
      base64Encode(bytes),
      iterations,
    );
  }

  Future<bool> verify(String password, PasswordFingerprint stored) async {
    if (stored.iterations < 1 ||
        stored.iterations > LocalAuthRules.iterations * 2) {
      throw const FormatException('Invalid password work factor');
    }
    final salt = base64Decode(stored.salt),
        expected = base64Decode(stored.digest);
    if (salt.length != LocalAuthRules.saltBytes ||
        expected.length != LocalAuthRules.digestBytes) {
      throw const FormatException('Invalid password fingerprint');
    }
    final bytes = await compute(_derivePassword, {
      'password': password,
      'salt': salt,
      'iterations': stored.iterations,
    });
    return constantTimeBytesEquality.equals(bytes, expected);
  }
}

Future<List<int>> _derivePassword(Map<String, Object> input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input['iterations'] as int,
    bits: LocalAuthRules.digestBytes * 8,
  );
  final key = await algorithm.deriveKeyFromPassword(
    password: input['password'] as String,
    nonce: input['salt'] as List<int>,
  );
  return key.extractBytes();
}
