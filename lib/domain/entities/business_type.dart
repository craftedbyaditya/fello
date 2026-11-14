/// Optional organisation business type used for personalisation.
enum BusinessType {
  bankFinancial(
    'bank_financial',
    'Bank / Financial Services',
  ),
  restaurantCafe(
    'restaurant_cafe',
    'Restaurant / Cafe',
  ),
  retail(
    'retail',
    'Retail',
  ),
  automobile(
    'automobile',
    'Automobile / Dealership',
  ),
  healthcare(
    'healthcare',
    'Healthcare',
  ),
  hospitality(
    'hospitality',
    'Hospitality',
  ),
  professionalServices(
    'professional_services',
    'Professional Services',
  ),
  education(
    'education',
    'Education',
  ),
  other(
    'other',
    'Other',
  );

  const BusinessType(this.id, this.label);

  final String id;
  final String label;

  static BusinessType? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final value in BusinessType.values) {
      if (value.id == id) return value;
    }
    return null;
  }
}
