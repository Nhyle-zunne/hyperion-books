/// Standard Hyperion Maritime access products used for direct/manual sales.
///
/// Values are the persisted transaction descriptions. Keep these stable so
/// existing cash receipts, sales exports and locally stored backups continue
/// to display human-readable product names without a database migration.
///
/// This is a bookkeeping selector, not a license purchase or entitlement source.
class HyperionProductCatalog {
  static const List<String> products = [
    'OIC-NW weekly access',
    'OIC-NW monthly access',
    'OIC-NW yearly access',
    'OIC-EW weekly access',
    'OIC-EW monthly access',
    'OIC-EW yearly access',
    'Deck Management weekly access',
    'Deck Management monthly access',
    'Deck Management yearly access',
    'Engine Management weekly access',
    'Engine Management monthly access',
    'Engine Management yearly access',
    'GMDSS GOC weekly access',
    'GMDSS GOC monthly access',
    'GMDSS GOC yearly access',
  ];

  /// Older manual sales may contain a custom description. While editing,
  /// offer it as the current dropdown value so saving cannot overwrite the
  /// original accounting particulars merely by opening the editor.
  static List<String> choicesForExisting(String? description) {
    final existing = description?.trim() ?? '';
    if (existing.isEmpty || products.contains(existing)) return products;
    return [existing, ...products];
  }
}
