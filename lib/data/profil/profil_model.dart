class ProfilModel {
  final int id;
  final String username;
  final String email;
  final String phone;
  final String profilePicture;

  const ProfilModel({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.profilePicture,
  });

  String get nama => username;

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username:
          (json['username'] as String?) ??
          (json['nama'] as String?) ??
          'Pengguna PATH',
      email: json['email'] as String? ?? '',
      phone: json['phone']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nama': username,
    'email': email,
    'phone': phone,
    'profile_picture': profilePicture,
  };

  ProfilModel copyWith({
    int? id,
    String? username,
    String? email,
    String? phone,
    String? profilePicture,
  }) {
    return ProfilModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }
}

class UpdatePenggunaResponse {
  final String message;
  final ProfilModel data;

  const UpdatePenggunaResponse({
    required this.message,
    required this.data,
  });

  factory UpdatePenggunaResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return UpdatePenggunaResponse(
      message: json['message'] as String? ?? '',
      data: rawData is Map<String, dynamic>
          ? ProfilModel.fromJson(rawData)
          : const ProfilModel(
              id: 0,
              username: '',
              email: '',
              phone: '',
              profilePicture: '',
            ),
    );
  }
}

class UpdateEmailRequest {
  final String email;

  const UpdateEmailRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class UpdatePhoneRequest {
  final String phone;

  const UpdatePhoneRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

class ResetPasswordRequest {
  final String oldPassword;
  final String newPassword;

  const ResetPasswordRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'old_password': oldPassword,
    'new_password': newPassword,
  };
}
