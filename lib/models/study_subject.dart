import 'package:flutter/foundation.dart';

@immutable
class StudySubject {
  const StudySubject({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.sortOrder,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String colorHex;
  final int sortOrder;
  final bool isArchived;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'sortOrder': sortOrder,
      'isArchived': isArchived,
    };
  }

  factory StudySubject.fromJson(Map<String, Object?> json) {
    return StudySubject(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String,
      sortOrder: json['sortOrder'] as int,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  StudySubject copyWith({
    String? id,
    String? name,
    String? colorHex,
    int? sortOrder,
    bool? isArchived,
  }) {
    return StudySubject(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
