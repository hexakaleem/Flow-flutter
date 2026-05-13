class Task {
  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final bool isCompleted;

  const Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    this.isCompleted = false,
  });

  Task copyWith({
    String? title,
    String? notes,
    bool? isCompleted,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}
