# Hyperion Books — Business workflow expansion

Hyperion Books provides local business records, reporting, record search, tax planning, and backup workflows.

## Implemented

- **Business performance dashboard:** independently selected last 7/30/90 calendar days, indicative tracked receipts, known costs, cash movement, revenue-vs-cost daily bars, expense category breakdown, recent PayMongo payments and recent expenses. Money is calculated from the locally imported PayMongo transactions and manually entered bank payouts and expenses.
- **Global record search:** find PayMongo transaction IDs, payout records, expenses, list items and reminders. Search is performed in the browser without a network request.
- **Transaction entry:** add sales from the Sales page and the dashboard; add payouts or expenses from Entries. CSV imports are available from the corresponding pages.
- **Bulk expense import:** download an example CSV and import expenses using `Reference,Date,Amount,Description,Category`. A stable Reference is mandatory to prevent duplicates. Import previews new and skipped records and never overwrites a matching existing reference. Date is `YYYY-MM-DD` or `MM/DD/YYYY`, money is PHP with at most two decimal places.
- **Local master lists:** editable customers, vendors, products and expense categories. Your expense category list appears when recording expenses. These lists are references; automatic stock movement and receivable aging have not been implemented.
- **Business profile:** optional business name, registration status, tax-method note, and private notes. These are user-selected informational fields; no BIR record is changed.
- **Tax & compliance planner:** editable personal due-date tasks, checkboxes and date picker. The app does not supply automatic BIR deadlines or notifications, or verify that a tax obligation applies to the business.
- **Backups and exports:** JSON backup v3 includes profile, lists, reminders, payouts, expenses, and PayMongo transactions. Existing v1 and v2 JSON backups remain importable. Excel exports include the four draft books, management summary, imported transactions, and the new local business lists/planner.

## Accounting boundaries

- Imported PayMongo successful customer payments are not the same as the amount transferred later to the bank; a later manual transfer must not be counted as a second sale.
- The business dashboard's **tracked receipts** use gross PayMongo transaction amounts and any provisional Google Play payout receipts. They are not verified taxable gross income.
- **Indicative result** subtracts known PayMongo fees and manually recorded expenses. It is not a CPA-certified net profit or an income-tax calculation. Some expenses or platform deductions may require different treatment.
- **Bank cash movement** uses manually entered payouts less manual expenses. It does not assume the amount of your imported PayMongo net transactions has already arrived in the bank.
- Manual tax reminders and registration-status fields do not claim compliance, create BIR forms, or submit filings.
- Books of Accounts are provisional working documents. See [Accounting and BIR scope](ACCOUNTING_AND_BIR_SCOPE.md).

## Privacy and persistence

All records are stored in the current device browser's IndexedDB. The only public files on GitHub Pages are application code and static assets. No imported CSV, BIR details, business master list or financial export is uploaded to GitHub. Data does not automatically sync between devices. Backups and exported Excel workbooks are unencrypted and may contain private business information; keep them in a secure location.

Importing any JSON backup **replaces**, rather than merges, device-local records. Export a fresh backup before restoring, especially when importing an older v1/v2 file which lacks the new business workspace.

## Intentionally not included

Automated statutory filings, DAT exports, invoice scanning, inventory valuation, and cross-device collaboration are not provided. These require additional accounting rules, authorization, or a supporting backend.

For BIR matters, verify current rules with your RDO and qualified accountant rather than treating local reminders or spreadsheet layouts as authorization to use computerized books.
