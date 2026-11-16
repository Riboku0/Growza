class AccountException implements Exception {
  const AccountException(this.code);
  final String code;
}

class AccountSession {
  const AccountSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    this.isLocal = false,
  });
  final String accessToken, refreshToken, userId, email;
  final bool isLocal;
  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map;
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    final id = user['id'] as String;
    final email = user['email'] as String;
    final local = json['local'] == true;
    if ((!local && (access.isEmpty || refresh.isEmpty)) || id.isEmpty) {
      throw const FormatException();
    }
    return AccountSession(
      accessToken: access,
      refreshToken: refresh,
      userId: id,
      email: email,
      isLocal: local,
    );
  }
  Map<String, dynamic> toJson() => {
    if (isLocal) 'local': true,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user': {'id': userId, 'email': email},
  };
}
