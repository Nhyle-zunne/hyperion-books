// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Opens a self-contained printable report, leaving the Flutter PWA untouched.
/// Data values are HTML-escaped and never sent to another service.
bool printTable({
  required String title,
  required String period,
  required String businessName,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final escape = const HtmlEscape(HtmlEscapeMode.element);
  String e(String value) => escape.convert(value);
  final markup = StringBuffer();
  markup.write('''
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Hyperion Books — Report</title>
<style>
body{font:13px Arial,sans-serif;padding:32px;color:#112940}
h1{margin:0;font-size:20px;color:#042353}
h2{font-size:17px;margin-bottom:5px}
p{color:#465871}
table{width:100%;border-collapse:collapse;margin-top:22px}
th,td{border:1px solid #cad5e3;padding:8px;text-align:left;vertical-align:top}
th{background:#edf2f8;font-weight:bold}
tr{break-inside:avoid}
.notice{margin-top:20px;font-size:11px;color:#465871}
button{background:#042353;color:#fff;border:0;padding:10px 18px;border-radius:6px}
@media print{@page{size:landscape;margin:12mm}button{display:none}body{padding:0}}
</style></head><body><button onclick="window.print()">Print Report</button>
''');
  markup.write('<h1>HYPERION BOOKS</h1>');
  if (businessName.trim().isNotEmpty) {
    markup.write('<p>${e(businessName.trim())}</p>');
  }
  markup.write('<h2>${e(title)}</h2><p>Covered period: ${e(period)}</p>');
  markup.write('<table><thead><tr>');
  for (final label in headers) { markup.write('<th>${e(label)}</th>'); }
  markup.write('</tr></thead><tbody>');
  for (final row in rows) {
    markup.write('<tr>');
    for (final value in row) { markup.write('<td>${e(value)}</td>'); }
    markup.write('</tr>');
  }
  markup.write('</tbody></table>');
  markup.write('<p class="notice">Provisional working records. Not BIR-registered computerized books. Verify with source documents.</p></body></html>');
  final blob = html.Blob([markup.toString()], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
