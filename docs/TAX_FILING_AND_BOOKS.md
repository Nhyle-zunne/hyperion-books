## Light & dark mode

Hyperion Books uses the same two-state preference behavior as Hyperion PWA: **Light** by default, and a persistent switch to **Dark**. On desktop, use the moon/sun icon in the top bar or the labeled control at the foot of the sidebar. On narrow phones, open the hamburger menu and use the sidebar Light/Dark switch.

The preference is stored in the browser under `hyperion-books-ui-theme-v1` via local shared preferences, independent from bookkeeping records. It survives normal page reloads, works offline, and is not transmitted with CSV files or financial exports. It does not sync between different devices or browsers. Clearing site storage resets the selection to Light.

Dark colors match Hyperion PWA's deep slate background/card/elevated surfaces, readable light text and green accent with Hyperion's navy/anchor identity retained.

# Hyperion Books — Books of Accounts & Tax Filing (local-first)

This workspace organizes locally recorded accounting entries, tax-related tasks, and invoice preparation records.

## Books of Accounts

- Books navigation opens four report views: **Journal**, **Ledger**, **Cash Receipt** and **Cash Disbursement**.
- A covered-period picker defaults to the current calendar month. Select **All dates** to see every record. The filter is inclusive by local calendar date.
- **Show optional columns** reveals source or classification information.
- **Export to Excel** exports the current book, period, and visible columns, with currency amounts stored numerically.
- A user-entered business name, optional TIN and business address appear in the report heading (and corresponding exports). Hyperion does not validate these details with BIR.
- **Print Report** opens a separate, offline-capable printable HTML report in a new browser tab (browser pop-up permission may be required).
- Ledger running balances carry forward earlier transactions, even when the display is filtered to a later period. Book classification is based on all imported PayMongo transactions, not just the selected date range.
- **Include voided entries** and **Include unverified** filter working-paper rows by local manual flags. Tap a reference number to mark it reviewed/verified or void it in draft reports. A void flag excludes the complete reference from draft book views without deleting the original transaction. Filtering recalculates the provisional ledger balances from all included historical entries. These flags **are not** official BIR verification, statutory void/reversal entries, or tamper-proof audit logs. Tax period management totals still use underlying source records.
- Separate **full Excel export** from Tools includes all four books, raw PayMongo records, business lists and tax tracking items.

## Navigation and report usability

The desktop navigation is a scrollable, hierarchical sidebar (a full drawer on phones). It contains **Dashboard, Compliance, Sales, Purchases, Expenses, Tax Filing, Accounting, Master List, Bulk Import and My Business**. It deliberately **does not** contain Inbox or Help & Docs.

- Purchases includes a product reference list, purchase records and business assets.
- Expenses includes manually recorded daily expenses and a payroll reference register.
- Accounting contains a single **Books of Accounts** destination with four built-in tabs (Journal, Ledger, Cash Receipt, Cash Disbursement), plus Financial Reports, Management Reports and Aging Reports. Journal and Ledger are no longer separate sidebar items.
- Master List links directly to editable local customers, vendors, products and expense categories.
- Tax Filing links to six sections: Calendar, Monthly, Quarterly, Annual, 2307 Certificates and e-Invoicing. The duplicate Books of Accounts tab and sidebar link were removed; all books are accessed from Accounting.

**Books of Accounts UX:** controls, period filters and the actual report now share one vertical scroll page; the top section is no longer fixed above and covering the table. The transaction grid has an independently scrollable viewport with a permanently visible horizontal scrollbar, a vertical scrollbar and explicit left/right arrows. Click a source reference to view all PayMongo fields retained by Hyperion or the complete manual entry. Source CSV columns excluded for privacy are not recoverable in the app; retain the original CSV securely.

**New local business data:** purchases, business assets and payroll entries are reference registers. They can be created, edited and removed. They do **not** automatically debit expenses, recognize payroll liabilities, value stock, calculate depreciation or appear as independent sales. Cash outflows must be recorded once separately under Entries → Expense. These registers are included in version 3 JSON backups and private Excel exports.

**Accounting reports:** Financial Reports show source-based trial balance and provisional account balances, *not* certified annual financial statements. Management Reports reuse dashboard trend analysis. Aging Reports group manually recorded unpaid invoices by **optional payment due date**; invoices without a due date are reported separately and cannot be aged reliably. Neither invoice registers nor due dates prove that legal BIR invoices were issued.

## Tax Filing menu

Open **Tax Filing** from the desktop sidebar or the mobile app drawer. It includes:

1. **Calendar** — Sunday-first month grid and year/upcoming views, month/year selectors, cadence filters (monthly/quarterly/annual), audience/category filter and Due Date Only toggle. Click deadlines to see filing-window opening dates, standard due dates, estimated weekend rollover, applicability, official source link, and save them as editable local reminders. Personal reminders, completion checkboxes and filing logs remain available.
2. **Monthly** — monthly management totals and manually recorded filing references/status.
3. **Quarterly** — quarterly management totals, a filing register, and examples of potentially relevant return categories.
4. **Annual** — yearly management totals and a filing register.
5. **2307 Certificates** — manual received/issued certificate tracker with status, reference, date, counterparty and amount withheld.
6. **e-Invoicing** — **manual invoice register only**, with recipient, invoice reference, date, amount and status.
7. **Books of Accounts** — embeds the same four-report Books component.

Status selections (such as **Filed**, **Issued**, or **Received**) are user-entered labels; they are **not confirmations from BIR**. No BIR credentials or remote connections are used.

## Accounting and tax calculation limits

- Monthly/quarterly/annual **tracked receipts** come from gross successful imported PayMongo payments and provisional receipts from manual Google Play/unsupported payouts. Later PayMongo-bank transfers are not counted as second sales.
- Manually recorded expenses and PayMongo fees are shown separately. Refunds/adjustments are isolated for review; they are not silently netted into taxable income.
- When the user's business profile explicitly selects **8% income tax (if elected)**, an *illustrative* year-to-date calculation displays 8% × max(0, tracked receipts − ₱250,000). It assumes an eligible purely self-employed taxpayer who qualifies for that reduction. It is **not** a calculation of tax due or payable and excludes credits, withholding, previous returns and other income.
- **Reference BIR filing dates are now generated automatically** for the selected year from the official BIR online-seller guide and related withholding-form filing rules. The schedule includes recurring 1701/1701A/1701-MS/1701Q, 1702Q/1702-RT, 2550Q, 2551Q, 0619-E/F, 1601-C/EQ/FQ, 1604-C/E/F, 2316 and conditional annual inventory-list dates. It is an intentionally scoped set, not every BIR return. For TY2025 individual annual ITRs due in 2026, RMC 30-2026's May 15, 2026 extension is included (confirmed by RMC 36-2026).
- **Future-year dates are projections, not official calendars**. For weekend deadlines, the UI estimates the following Monday; it does not calculate Philippine holidays, exceptions, special RMC/RR deadlines, eFPS staggered-group filing dates, taxpayer-specific fiscal years, or filing applicability. Always verify using the latest official BIR Interactive Tax Calendar and current RDO guidance. Similar annual ITR forms are alternatives, not cumulative obligations.
- Hyperion Books **does not** prepare/submit statutory BIR returns, issue BIR-registered electronic invoices, send 2307 certificates to BIR, or generate required .DAT submission files. Real official features require regulatory requirements, data validation and potentially an authorized integration.
- Provisional accounting working papers are **not authorized computerized books**.

## Privacy and backup

All tax records and reminders are stored in this browser's IndexedDB as part of the `BusinessWorkspace` model. Local JSON backup schema **v3** accepts these optional additions while retaining compatibility with prior v3 backups without tax records. JSON backup restore **replaces** local data. The full Excel export includes tax tracking data; protect both files. No automatic device sync exists and exported files are not encrypted. Never commit customer information, tax records, or financial backups into the public repository.

## Verification

Run `node scripts/check_source.mjs`, `flutter analyze`, `flutter test`, and `flutter build web` for each change. Check actual GitHub Actions run results before treating a build as production-ready.

Official form reference: [BIR 1701Q Schedule II and credit/payment sections](https://efps.bir.gov.ph/efps-war/EFPSWeb_war/forms2018Version/1701Q/1701q_v3_02.xhtml). Consult an accountant and your RDO to confirm which forms and deadlines apply.


### Primary BIR calendar references

- [RMC 110-2025: BIR 2026 Interactive Tax Calendar announced](https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%20110-2025.pdf)
- [BIR Online Sellers Guide: individual and corporate tax schedules](https://bir-cdn.bir.gov.ph/BIR/pdf/TAXPAYERS%20GUIDE%20FOR%20ONLINE%20SELLERS.pdf)
- [RMC 36-2026: confirms RMC 30-2026 2025 annual ITR extension to May 15, 2026](https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2036-2026.pdf)
- [BIR forms directory and filing notes](https://www.bir.gov.ph/bir-forms)
