import 'package:dio/dio.dart';
import 'config.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage storage;

  ApiClient(this.storage)
      : dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await storage.getAccess();
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
      ),
    );
  }
}
