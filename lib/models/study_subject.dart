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
