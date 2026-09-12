/// Model user — khớp UserResponseDto của backend.
/// `createdAt` là chuỗi ISO 8601 (vd. 2026-09-12T18:45:55.167Z).
class UserModel {
  final String id;
  final String email;
  final String name;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name = '',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        // GET /auth/me trả { userId, email } — không có field id/name
        id:        (json['id'] ?? json['userId'] ?? '') as String,
        email:     (json['email'] ?? '') as String,
        name:      (json['name'] ?? '') as String,
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'email':     email,
        'name':      name,
        'createdAt': createdAt?.toIso8601String(),
      };

  UserModel copyWith({String? id, String? email, String? name, DateTime? createdAt}) => UserModel(
        id:        id ?? this.id,
        email:     email ?? this.email,
        name:      name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Tên hiển thị trên UI — fallback về phần đầu của email nếu chưa có tên.
  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  @override
  String toString() => 'UserModel($id, $email)';
}
