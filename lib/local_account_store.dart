import 'email_validation.dart';

import 'package:sqflite/sqflite.dart';

import 'account_models.dart';
import 'local_id.dart';
import 'password_hash.dart';

typedef LocalIdentity = ({String id, String email});

abstract class LocalAccounts {
  Future<LocalIdentity> create(String email, String password);
  Future<LocalIdentity> signIn(String email, String password);
  Future<LocalIdentity?> find(String id);
  Future<void> delete(String id);
  Future<void> close();
}

/// Account credentials live outside study snapshots and backups. This identity
/// does not create a separate workspace or encrypt the study database.
class LocalAccountStore implements LocalAccounts {
  LocalAccountStore({this._factory, this.path, PasswordHasher? hasher})
    : _hasher = hasher ?? const PasswordHasher();
  final DatabaseFactory? _factory;
  final String? path;
  final PasswordHasher _hasher;
  Future<Database>? _opening;
  Future<Database> get database =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });
  Future<Database> _open() async => (_factory ?? databaseFactory).openDatabase(
    path ?? '${await getDatabasesPath()}/growza-accounts.db',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE local_accounts (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, digest TEXT NOT NULL, iterations INTEGER NOT NULL, algorithm TEXT NOT NULL, created_at TEXT NOT NULL)',
      ),
    ),
  );
  String _email(String value) {
    final email = value.trim().toLowerCase();
    if (!isValidAccountEmail(email)) {
      throw const AccountException('invalid_email');
    }
    return email;
  }

  bool _validPassword(String password) =>
      password.length >= LocalAuthRules.minPasswordCharacters &&
      password.length <= LocalAuthRules.maxPasswordCharacters;
  @override
  Future<LocalIdentity> create(String email, String password) async {
    final normalized = _email(email);
    if (!_validPassword(password)) {
      throw const AccountException('weak_password');
    }
    final db = await database;
    if ((await db.query(
      'local_accounts',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalized],
    )).isNotEmpty) {
      throw const AccountException('email_exists');
    }
    final fingerprint = await _hasher.create(password);
    final id = newLocalId('local-user');
    try {
      await db.insert('local_accounts', {
        'id': id,
        'email': normalized,
        'salt': fingerprint.salt,
        'digest': fingerprint.digest,
        'iterations': fingerprint.iterations,
        'algorithm': 'pbkdf2-sha256',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AccountException('email_exists');
      }
      rethrow;
    }
    return (id: id, email: normalized);
  }

  @override
  Future<LocalIdentity> signIn(String email, String password) async {
    final normalized = _email(email);
    if (!_validPassword(password)) {
      throw const AccountException('invalid_credentials');
    }
    final rows = await (await database).query(
      'local_accounts',
      where: 'email = ?',
      whereArgs: [normalized],
    );
    if (rows.isEmpty) throw const AccountException('invalid_credentials');
    final row = rows.single;
    if (row['algorithm'] != 'pbkdf2-sha256') {
      throw const AccountException('unavailable');
    }
    if (!await _hasher.verify(
      password,
      PasswordFingerprint(
        row['salt'] as String,
        row['digest'] as String,
        row['iterations'] as int,
      ),
    )) {
      throw const AccountException('invalid_credentials');
    }
    return (id: row['id'] as String, email: row['email'] as String);
  }

  @override
  Future<LocalIdentity?> find(String id) async {
    final rows = await (await database).query(
      'local_accounts',
      columns: ['id', 'email'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return (
      id: rows.single['id'] as String,
      email: rows.single['email'] as String,
    );
  }

  @override
  Future<void> delete(String id) async {
    await (await database).delete(
      'local_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> close() async {
    final opened = _opening;
    if (opened != null) {
      await (await opened).close();
      _opening = null;
    }
  }
}
