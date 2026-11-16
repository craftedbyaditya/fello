import 'package:equatable/equatable.dart';

class FeatureFlags extends Equatable {
  const FeatureFlags(this._values);

  static const launchDefaults = FeatureFlags({
    'feedback_forms_enabled': true,
    'feedback_submissions_enabled': true,
    'analytics_enabled': true,
    'task_board_enabled': false,
    'ai_processing_enabled': false,
    'reviews_api_enabled': false,
    'team_invites_enabled': false,
    'billing_enabled': false,
    'growth_plan_sales_enabled': false,
    'pro_plan_sales_enabled': false,
  });

  final Map<String, bool> _values;

  bool enabled(String key, {bool fallback = false}) => _values[key] ?? fallback;

  Map<String, bool> get values => Map.unmodifiable(_values);

  @override
  List<Object?> get props => [_values];
}
