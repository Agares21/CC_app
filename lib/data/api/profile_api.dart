import 'package:dio/dio.dart';

import 'api_client.dart';

/// Operaciones sobre el perfil del usuario autenticado.
class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastName,
  }) async {
    final response = await _dio.put(
      '/profile',
      data: {'name': name, 'last_name': lastName},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _dio.put(
      '/profile/password',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required String path,
    required String filename,
  }) async {
    final response = await _dio.post(
      '/profile/avatar',
      data: FormData.fromMap({
        'avatar': await MultipartFile.fromFile(path, filename: filename),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    final response = await _dio.delete('/profile/avatar');
    return response.data as Map<String, dynamic>;
  }
}
