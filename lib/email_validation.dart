/// Checks common unquoted internet email syntax only. This makes no claim
/// about domain availability, mailbox existence or ownership.
bool isValidAccountEmail(String value) {
  final email = value.trim();
  if (email.length > 254) return false;
  final pieces = email.split('@');
  if (pieces.length != 2) return false;
  final local = pieces[0], domain = pieces[1];
  if (local.isEmpty ||
      local.length > 64 ||
      local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..')) {
    return false;
  }
  if (!RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.\-]+$").hasMatch(local)) {
    return false;
  }
  final labels = domain.split('.');
  if (labels.length < 2) return false;
  final labelPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?$',
  );
  if (labels.any((label) => !labelPattern.hasMatch(label))) return false;
  final top = labels.last;
  return RegExp(r'^[A-Za-z]{2,63}$').hasMatch(top) ||
      (top.toLowerCase().startsWith('xn--') && top.length > 4);
}
