# Hyperion Books: accounting working papers and Philippine BIR scope

These are **draft, locally generated accounting working papers**, not automatically registered or authorized Books of Accounts. Exporting an .xlsx file or installing a PWA does not obtain a BIR permit or approval.

## Four books displayed and exported

1. **Cash Receipts Journal:** chronological customer collection/processor receipts and actual bank payouts, clearly separated into gross payments, platform fees including VAT, net processor collections, and bank receipts. PayMongo-to-bank transfers are marked **transfers, not another sale**.
2. **Cash Disbursements Journal:** chronological manually entered expenses, account categories, source references and actual cash/bank paid. PayMongo fees withheld from collections do not pretend to be additional bank payments.
3. **General Journal:** a consolidated double-entry posting log covering source PayMongo transactions, subsequent bank transfers and manual expenses. Every transaction reference is traceable to source data. Do not re-post specialized journals again.
4. **General Ledger:** debit and credit movements and running debit/credit balances per provisional account, based on the General Journal.

All amounts are stored as integer centavos. The imported PayMongo CSV transaction date/time is preserved as exported. Manually entered bank payouts and expenses currently have dates, not time-of-day; exports show midnight for those entries. No account opening balance, sales invoice number, supplier TIN, officially issued invoice, ORUS QR stamp, audit trail for all historical edits or formal year-end closing entries is automatically produced.

## Classification assumptions requiring verification

- A successful **PayMongo customer payment** is treated provisionally as **Debit PayMongo clearing (net)**, **Debit PayMongo fees (VAT inclusive)**, **Credit PayMongo sales (gross)**. The fee's VAT portion is already included and must not be deducted twice.
- A **manual PayMongo bank transfer** is recorded as **Debit Bank / Credit PayMongo clearing** when there is imported PayMongo activity. It is an asset transfer and **not another sale**. Missing historical transactions, refunds, reserves, payouts and opening clearing balances will create unreconciled differences.
- **PayMongo refunds and adjustments** go to separate review accounts, rather than being silently classified as taxable income or expenses.
- **Google Play payout entries** or **PayMongo payouts without transaction CSV support** are treated as provisional/unmatched. Net cash transferred is not necessarily gross taxable revenue.
- Monthly dashboard "Imported PayMongo activity" uses customer transaction dates, while the "Bank and cash movements" figures use manually entered bank payout/expense dates. Never add the two sets of figures together as though they are independent sales.

This is not automatically the method required for a particular taxpayer. Actual BIR treatment depends on registration, invoice and accounting records, and whether the taxpayer is VAT or non-VAT, under the 8% rate, or has other taxable activity. Review with a qualified accountant or the registered RDO before treating exports as official books. If the business has formally closed, reconcile the coverage period and remaining filing/retention obligations with the RDO.

## Official Philippine references

- BIR Revenue Memorandum Circular No. 65-2025: new taxpayers may choose manual, loose-leaf or computerized books; loose-leaf/computerized books have additional permits or acknowledgments before use. https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2065-2025%20Digest.pdf
- BIR Revenue Memorandum Circular No. 4-2026: clarifies ORUS registration and QR stamp rules for loose-leaf/computerized books. https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%204-2026.pdf
- BIR Revenue Memorandum Order No. 1-2026 Annex B: examples of General Ledger, General Journal, Cash Receipts, Cash Disbursement and supporting records in audit documentation. https://bir-cdn.bir.gov.ph/BIR/pdf/RMO%20No.%201-2026%20Annex%20B%20%281%29.pdf
- BIR Revenue Regulations No. 7-2024: preservation of books and supporting documents. https://bir-cdn.bir.gov.ph/BIR/pdf/RR%20No.%207-%202024.pdf

Keep source invoices, PayMongo CSV exports, bank statements, expense invoices, and JSON backups in a secure private location. Imported and manually entered records remain in device-local browser storage. Do not commit them to the public GitHub repository.
