import 'package:flutter/material.dart';
import '../models/book_table_view.dart';
import '../theme/hyperion_theme.dart';

/// A compact, non-horizontally-scrolling display of the four working books.
/// The exported report uses the same `BookTableData` headers and values.
class BooksCompactTable extends StatefulWidget {
  final BookTableData report;
  final int bookIndex;
  final ValueChanged<String> onOpenReference;
  final double height;

  const BooksCompactTable({
    super.key,
    required this.report,
    required this.bookIndex,
    required this.onOpenReference,
    this.height = 520,
  });

  @override
  State<BooksCompactTable> createState() => _BooksCompactTableState();
}

class _BooksCompactTableState extends State<BooksCompactTable> {
  final ScrollController _scroll = ScrollController();

  static const columnFlex = <List<int>>[
    [11, 16, 43, 15, 15],
    [11, 17, 30, 13, 13, 16],
    [11, 16, 29, 11, 10, 12, 11],
    [11, 17, 32, 25, 15],
  ];

  @override
  void didUpdateWidget(BooksCompactTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookIndex != widget.bookIndex ||
        oldWidget.report.ledgerAccount != widget.report.ledgerAccount ||
        oldWidget.report.title != widget.report.title) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _amountColumn(int index) => switch (widget.bookIndex) {
    0 || 1 || 2 => index >= 3,
    _ => index == 4,
  };

  @override
  Widget build(BuildContext context) {
    final data = widget.report;
    if (data.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 35),
        child: Text('No records in this period. Change the dates or record '
          'a sale, payout or expense.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HyperionColors.muted)),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final mobile = constraints.maxWidth < 630;
      return Column(children: [
        if (!mobile) _desktopRow(
          data.headers, header: true, summary: false),
        SizedBox(height: widget.height,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: data.rows.length > 7,
            child: ListView.builder(
              controller: _scroll,
              itemCount: data.rows.length,
              itemBuilder: (context, index) {
                final row = data.rows[index];
                final summary = data.summaryRows.contains(index);
                final ref = row.length > 1 ? row[1] : '';
                return Padding(
                  padding: EdgeInsets.only(bottom: mobile ? 7 : 0),
                  child: Material(
                    color: mobile ? (summary ? HyperionColors.accentSoft :
                      HyperionColors.elevated) : Colors.transparent,
                    borderRadius: mobile ? BorderRadius.circular(9) : null,
                    child: InkWell(
                      onTap: summary || ref.isEmpty ? null
                        : () => widget.onOpenReference(ref),
                      child: mobile
                        ? _mobileRow(data.headers, row, summary)
                        : _desktopRow(row,
                            header: false, summary: summary,
                            striped: index.isOdd),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]);
    });
  }

  Widget _desktopRow(List<String> cells,
      {required bool header, required bool summary, bool striped = false}) {
    final weights = columnFlex[widget.bookIndex];
    return Container(
      constraints: const BoxConstraints(minHeight: 45),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      decoration: BoxDecoration(
        color: header ? HyperionColors.elevated :
          summary ? HyperionColors.accentSoft :
          striped ? HyperionColors.elevated.withValues(alpha: .55) :
          HyperionColors.card,
        border: Border(bottom: BorderSide(
          color: HyperionColors.border.withValues(alpha: .65), width: .6)),
      ),
      child: Row(children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(flex: weights[i], child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(cells[i],
              maxLines: header ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: !header && _amountColumn(i)
                ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: header ? 10.5 : 11.5,
                fontWeight: header || summary
                  ? FontWeight.w800 : FontWeight.w500,
                color: !header && i == 1 && !summary
                  ? HyperionColors.brand : HyperionColors.ink,
                fontFeatures: _amountColumn(i)
                  ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          )),
      ]),
    );
  }

  Widget _mobileRow(List<String> headers, List<String> row, bool summary) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(row[0].isEmpty ? 'TOTAL' : row[0],
            style: TextStyle(color: HyperionColors.muted,
              fontSize: 11, fontWeight: FontWeight.w700))),
          if (!summary && row.length > 1)
            Expanded(child: Text(row[1], textAlign: TextAlign.right,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: HyperionColors.brand,
                fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        if (row.length > 2 && row[2].isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(row[2], maxLines: 3, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HyperionColors.ink,
              fontSize: 12, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 7),
        Wrap(spacing: 11, runSpacing: 6, children: [
          for (var i = 3; i < row.length; i++)
            if (row[i].isNotEmpty)
              Text('${headers[i]}: ${row[i]}',
                style: TextStyle(color: HyperionColors.ink,
                  fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
