import 'package:equatable/equatable.dart';

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalResponses,
    required this.averageRating,
    required this.npsScore,
    required this.npsDistribution,
    required this.volumeByDay,
    required this.responseRateLabel,
  });

  final int totalResponses;
  final double? averageRating;
  final double? npsScore;
  final Map<int, int> npsDistribution;
  final Map<DateTime, int> volumeByDay;
  final String responseRateLabel;

  @override
  List<Object?> get props => [
        totalResponses,
        averageRating,
        npsScore,
        npsDistribution,
        volumeByDay,
        responseRateLabel,
      ];
}

class ResponseFilters extends Equatable {
  const ResponseFilters({
    this.formId,
    this.from,
    this.to,
    this.minRating,
    this.maxRating,
    this.npsBand,
  });

  final String? formId;
  final DateTime? from;
  final DateTime? to;
  final int? minRating;
  final int? maxRating;

  /// 'detractor' | 'passive' | 'promoter' | null
  final String? npsBand;

  ResponseFilters copyWith({
    String? formId,
    DateTime? from,
    DateTime? to,
    int? minRating,
    int? maxRating,
    String? npsBand,
    bool clearFormId = false,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearMinRating = false,
    bool clearMaxRating = false,
    bool clearNpsBand = false,
  }) {
    return ResponseFilters(
      formId: clearFormId ? null : (formId ?? this.formId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxRating: clearMaxRating ? null : (maxRating ?? this.maxRating),
      npsBand: clearNpsBand ? null : (npsBand ?? this.npsBand),
    );
  }

  @override
  List<Object?> get props =>
      [formId, from, to, minRating, maxRating, npsBand];
}
