class Module {
  final String? id;
  final String title;
  final String content;
  final List< Question > questions;
  final bool isValid;
  final bool isPublished;
  final String category; // 'module', 'quiz', or 'mock_exam'
  final String? classCode;
  final String? teacherId;

  // Original uploaded file information
  final String? fileName;
  final String? fileType;
  final String? mimeType;
  final String? fileUrl;
  final String? storagePath;
  final int? fileSize;
  final int? pageCount;
  final DateTime? uploadedAt;

  Module({
    this.id,
    required this.title,
    required this.content,
    this.questions = const [],
    this.isValid = true,
    this.isPublished = true,
    this.category = 'module',
    this.classCode,
    this.teacherId,
    this.fileName,
    this.fileType,
    this.mimeType,
    this.fileUrl,
    this.storagePath,
    this.fileSize,
    this.pageCount,
    this.uploadedAt,
  });

  Module copyWith({
    String? id,
    String? title,
    String? content,
    List< Question >? questions,
    bool? isValid,
    bool? isPublished,
    String? category,
    String? classCode,
    String? teacherId,
    String? fileName,
    String? fileType,
    String? mimeType,
    String? fileUrl,
    String? storagePath,
    int? fileSize,
    int? pageCount,
    DateTime? uploadedAt,
  }) {
    return Module(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      questions: questions ?? this.questions,
      isValid: isValid ?? this.isValid,
      isPublished: isPublished ?? this.isPublished,
      category: category ?? this.category,
      classCode: classCode ?? this.classCode,
      teacherId: teacherId ?? this.teacherId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      mimeType: mimeType ?? this.mimeType,
      fileUrl: fileUrl ?? this.fileUrl,
      storagePath: storagePath ?? this.storagePath,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map< String, dynamic > toMap() {
    return < String, dynamic >{
      'title': title,
      'content': content,
      'questions': questions.map((q) => q.toMap()).toList(),
      'isValid': isValid,
      'isPublished': isPublished,
      'category': category,
      'classCode': classCode?.trim().toUpperCase(),
      'teacherId': teacherId,
      'fileName': fileName,
      'fileType': fileType,
      'mimeType': mimeType,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'fileSize': fileSize,
      'pageCount': pageCount,
      'uploadedAt': uploadedAt == null
          ? null
          : uploadedAt!.toUtc().toIso8601String(),
    };
  }

  factory Module.fromMap(Map< String, dynamic > map, {String? id}) {
    final rawClassCode =
        (map['classCode'] ?? '').toString().trim().toUpperCase();
    final rawTeacherId = (map['teacherId'] ?? '').toString().trim();
    return Module(
      id: id,
      title: map['title'] as String? ?? 'Untitled Module',
      content: map['content'] as String? ?? '',
      questions: (map['questions'] as List< dynamic >? ?? [])
          .whereType< Map >()
          .map((q) => Question.fromMap(Map< String, dynamic >.from(q)))
          .toList(),
      isValid: map['isValid'] as bool? ?? true,
      isPublished: map['isPublished'] != false,
      category: (map['category'] as String?)?.trim().isNotEmpty == true
          ? (map['category'] as String).trim()
          : 'module',
      classCode: rawClassCode.isEmpty ? null : rawClassCode,
      teacherId: rawTeacherId.isEmpty ? null : rawTeacherId,
      fileName: map['fileName']?.toString(),
      fileType: map['fileType']?.toString(),
      mimeType: map['mimeType']?.toString(),
      fileUrl: map['fileUrl']?.toString(),
      storagePath: map['storagePath']?.toString(),
      fileSize:
          (map['fileSize'] is num) ? (map['fileSize'] as num).toInt() : null,
      pageCount:
          (map['pageCount'] is num) ? (map['pageCount'] as num).toInt() : null,
      uploadedAt: map['uploadedAt'] is String
          ? DateTime.tryParse(map['uploadedAt'] as String)
          : DateTime.now(),
    );
  }
}

class Question {
  final String question;
  final List<String> choices;
  final int correctIndex;

  Question({
    required this.question,
    required this.choices,
    required this.correctIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'choices': choices,
      'correctIndex': correctIndex,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      question: map['question'] as String? ?? '',
      choices: (map['choices'] as List<dynamic>? ?? [])
          .map((choice) => choice.toString())
          .toList(),
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClassRoom {
  final String id;
  final String name;
  final String? teacherId;

  ClassRoom({
    required this.id,
    required this.name,
    this.teacherId,
  });
}
