import 'print_report_stub.dart'
    if (dart.library.html) 'print_report_web.dart' as platform;

class ReportPrinter {
  static bool printTable({
    required String title,
    required String period,
    required String businessName,
    required List<String> headers,
    required List<List<String>> rows,
  }) => platform.printTable(
    title: title, period: period, businessName: businessName,
    headers: headers, rows: rows);
}
