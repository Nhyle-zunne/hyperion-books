# Hyperion Books — Books of Accounts & Tax Filing (local-first)

This is an **original, Hyperion-themed implementation** of workflows visible in CPAlly's sample Books of Accounts screen and its Tax Filing menu. No third-party source code or private demo records are included.

## Books of Accounts

- Books navigation opens four report views: **Journal**, **Ledger**, **Cash Receipt** and **Cash Disbursement**.
- A covered-period picker defaults to the current calendar month. Select **All dates** to see every record. The filter is inclusive by local calendar date.
- **Show optional columns** reveals source or classification information.
- **Export to Excel** exports the current book, period, and visible columns, with currency amounts stored numerically.
- **Print Report** opens a separate, offline-capable printable HTML report in a new browser tab (browser pop-up permission may be required).
- Ledger running balances carry forward earlier transactions, even when the display is filtered to a later period. Book classification is based on all imported PayMongo transactions, not just the selected date range.
- **Include voided entries** and **Include unverified** filter working-paper rows by local manual flags. Tap a reference number to mark it reviewed/verified or void it in draft reports. A void flag excludes the complete reference from draft book views without deleting the original transaction. Filtering recalculates the provisional ledger balances from all included historical entries. These flags **are not** official BIR verification, statutory void/reversal entries, or tamper-proof audit logs. Tax period management totals still use underlying source records.
- Separate **full Excel export** from Tools includes all four books, raw PayMongo records, business lists and tax tracking items.

## Tax Filing menu

Use **Tax Filing** on the desktop navigation rail or the mobile bottom navigation. It includes:

1. **Calendar** — month navigation, manually entered due-date reminders, completion checkboxes, and local filing history.
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
- No statutory filing deadline is populated automatically. BIR deadline extensions and changes, taxpayer-specific filing obligations and eligibility must be checked externally.
- Hyperion Books **does not** prepare/submit statutory BIR returns, issue BIR-registered electronic invoices, send 2307 certificates to BIR, or generate required .DAT submission files. Real official features require regulatory requirements, data validation and potentially an authorized integration.
- Provisional accounting working papers are **not authorized computerized books**.

## Privacy and backup

All tax records and reminders are stored in this browser's IndexedDB as part of the `BusinessWorkspace` model. Local JSON backup schema **v3** accepts these optional additions while retaining compatibility with prior v3 backups without tax records. JSON backup restore **replaces** local data. The full Excel export includes tax tracking data; protect both files. No automatic device sync exists and exported files are not encrypted. Never commit customer information, tax records, or financial backups into the public repository.

## Verification

Run `node scripts/check_source.mjs`, `flutter analyze`, `flutter test`, and `flutter build web` for each change. Check actual GitHub Actions run results before treating a build as production-ready.

Official form reference: [BIR 1701Q Schedule II and credit/payment sections](https://efps.bir.gov.ph/efps-war/EFPSWeb_war/forms2018Version/1701Q/1701q_v3_02.xhtml). Consult an accountant and your RDO to confirm which forms and deadlines apply.
