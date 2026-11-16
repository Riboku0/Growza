import 'sqlite_device_test.dart' as sqlite;
import 'calendar_device_test.dart' as calendar;
import 'export_device_test.dart' as backup_export;

void main() {
  sqlite.main();
  calendar.main();
  backup_export.main();
}
