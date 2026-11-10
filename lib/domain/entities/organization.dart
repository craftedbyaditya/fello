import 'package:equatable/equatable.dart';

class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  Organization copyWith({
    String? id,
    String? name,
    String? slug,
    DateTime? createdAt,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, createdAt];
}
