import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';


/// Original, Hyperion-themed navigation for local business and tax workflows.
/// Inbox and Help & Docs are intentionally excluded.
class HyperionSidebar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const HyperionSidebar({super.key, required this.selected,
    required this.onSelect});

  @override Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SizedBox(width: 250, child: Column(children: [
      Padding(padding: EdgeInsets.fromLTRB(18, 16, 12, 10),
        child: Row(children: [
          Icon(Icons.dashboard_customize_outlined, size: 18, color: HyperionColors.brand),
          SizedBox(width: 9),
          Expanded(child: Text('BUSINESS WORKSPACE',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w900, color: HyperionColors.ink))),
        ])),
      Divider(height: 1),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        children: [
          _item('dashboard', 'Dashboard', Icons.dashboard_outlined),
          _item('compliance', 'Compliance', Icons.health_and_safety_outlined),
          _item('sales', 'Sales', Icons.point_of_sale_outlined),
          _group('Purchases', Icons.shopping_cart_outlined, 'purchases', [
            _item('product-to-sell', 'Product to Sell', Icons.inventory_2_outlined, indent: true),
            _item('purchase-records', 'Purchase Records', Icons.shopping_bag_outlined, indent: true),
            _item('business-assets', 'Business Assets', Icons.devices_other_outlined, indent: true),
          ]),
          _group('Expenses', Icons.receipt_long_outlined, 'expenses', [
            _item('daily-expenses', 'Daily Expenses', Icons.payments_outlined, indent: true),
            _item('payroll', 'Payroll', Icons.people_alt_outlined, indent: true),
          ]),
          _group('Tax Filing', Icons.account_balance_outlined, 'tax', [
            _item('tax-calendar', 'Calendar', Icons.calendar_month_outlined, indent: true),
            _item('tax-monthly', 'Monthly', Icons.calendar_today_outlined, indent: true),
            _item('tax-quarterly', 'Quarterly', Icons.date_range_outlined, indent: true),
            _item('tax-annual', 'Annual', Icons.event_outlined, indent: true),
            _item('tax-2307', '2307 Certificates', Icons.description_outlined, indent: true),
            _item('tax-invoices', 'e-Invoicing', Icons.receipt_outlined, indent: true),
            _item('tax-books', 'Books of Accounts', Icons.menu_book_outlined, indent: true),
          ]),
          _group('Accounting', Icons.calculate_outlined, 'accounting', [
            _item('journal', 'Journal Entries', Icons.menu_book_outlined, indent: true),
            _item('ledger', 'General Ledger', Icons.auto_stories_outlined, indent: true),
            _item('financial-reports', 'Financial Reports', Icons.bar_chart_outlined, indent: true),
            _item('management-reports', 'Management Reports', Icons.insights_outlined, indent: true),
            _item('aging-reports', 'Aging Reports', Icons.schedule_outlined, indent: true),
          ]),
          _group('Master List', Icons.list_alt_outlined, 'master', [
            _item('master-customers', 'Customers', Icons.groups_outlined, indent: true),
            _item('master-vendors', 'Vendors', Icons.store_outlined, indent: true),
            _item('master-products', 'Products', Icons.category_outlined, indent: true),
            _item('master-categories', 'Expense Categories', Icons.label_outline, indent: true),
          ]),
          Divider(height: 20),
          _item('bulk-import', 'Bulk Import', Icons.upload_file_outlined),
          _item('my-business', 'My Business', Icons.business_outlined),
          _item('paymongo', 'PayMongo Activity', Icons.account_balance_wallet_outlined),
          _item('backups', 'Backups & Exports', Icons.backup_outlined),
        ],
      )),
      Divider(height: 1),
      Padding(padding: EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: HyperionColors.brand),
          SizedBox(width: 9),
          Expanded(child: Text('Stored on this device · export backups',
            style: TextStyle(color: HyperionColors.muted, fontSize: 11))),
        ])),
    ])));

  Widget _group(String title, IconData icon, String key, List<Widget> children) {
    final active = selected.startsWith('$key-') ||
        (key == 'accounting' && ['journal','ledger','financial-reports',
          'management-reports','aging-reports'].contains(selected)) ||
        (key == 'purchases' && ['product-to-sell','purchase-records','business-assets'].contains(selected)) ||
        (key == 'expenses' && ['daily-expenses','payroll'].contains(selected));
    return ExpansionTile(
      key: PageStorageKey<String>('sidebar-$key'),
      initiallyExpanded: active,
      tilePadding: const EdgeInsets.symmetric(horizontal: 10),
      childrenPadding: const EdgeInsets.only(left: 8),
      dense: true, visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 19, color: HyperionColors.ink),
      title: Text(title, style: TextStyle(
        color: active ? HyperionColors.brand : HyperionColors.ink, fontWeight: FontWeight.w700,
        fontSize: 13)),
      children: children,
    );
  }

  Widget _item(String key, String label, IconData icon, {bool indent = false}) {
    final active = selected == key ||
        (key == 'tax-books' && selected == 'books');
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? HyperionColors.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.symmetric(horizontal: indent ? 10 : 11),
          leading: Icon(icon, size: indent ? 17 : 19,
            color: active ? HyperionColors.brand : HyperionColors.muted),
          title: Text(label, style: TextStyle(
            color: active ? HyperionColors.brand : HyperionColors.ink,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            fontSize: indent ? 12.5 : 13)),
          onTap: () => onSelect(key),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ));
  }
}
