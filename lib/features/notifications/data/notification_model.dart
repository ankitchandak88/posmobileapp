class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

