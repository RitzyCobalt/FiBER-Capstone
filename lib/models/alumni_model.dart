class AlumniProfile {
  final String id;
  final String name;
  final String title;
  final String position;
  final String company;
  final String batchYear;
  final String salary;
  final String imageUrl;
  final String highlight;
  final bool isVisible;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlumniProfile({
    required this.id,
    required this.name,
    required this.title,
    this.position = '',
    required this.company,
    required this.batchYear,
    this.salary = '',
    required this.imageUrl,
    required this.highlight,
    required this.isVisible,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    if (raw != null) {
      try {
        return (raw as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return DateTime.now();
  }

  factory AlumniProfile.fromMap(String id, Map< String, dynamic > map) {
    final parsedPosition = (map['position'] ?? '').toString().trim();
    final parsedTitle = (map['title'] ?? '').toString().trim();
    final effectivePosition = parsedPosition.isNotEmpty
        ? parsedPosition
        : parsedTitle;
    return AlumniProfile(
      id: id,
      name: (map['name'] ?? '').toString(),
      title: parsedTitle.isNotEmpty ? parsedTitle : effectivePosition,
      position: effectivePosition,
      company: (map['company'] ?? '').toString(),
      batchYear: (map['batchYear'] ?? '').toString(),
      salary: (map['salary'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      highlight: (map['highlight'] ?? '').toString(),
      isVisible: map['isVisible'] != false,
      displayOrder: (map['displayOrder'] is num)
          ? (map['displayOrder'] as num).toInt()
          : int.tryParse((map['displayOrder'] ?? '0').toString()) ?? 0,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map< String, dynamic > toMap() {
    final effectivePosition = position.trim().isNotEmpty
        ? position.trim()
        : title.trim();
    return < String, dynamic >{
      'name': name,
      'title': effectivePosition,
      'position': effectivePosition,
      'company': company,
      'batchYear': batchYear,
      'salary': salary,
      'imageUrl': imageUrl,
      'highlight': highlight,
      'isVisible': isVisible,
      'displayOrder': displayOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AlumniProfile copyWith({
    String? id,
    String? name,
    String? title,
    String? position,
    String? company,
    String? batchYear,
    String? salary,
    String? imageUrl,
    String? highlight,
    bool? isVisible,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlumniProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? position ?? this.title,
      position: position ?? title ?? this.position,
      company: company ?? this.company,
      batchYear: batchYear ?? this.batchYear,
      salary: salary ?? this.salary,
      imageUrl: imageUrl ?? this.imageUrl,
      highlight: highlight ?? this.highlight,
      isVisible: isVisible ?? this.isVisible,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
