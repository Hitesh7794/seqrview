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
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
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
        onError: (err, handler) async {
          // If unauthorized, try refresh once then retry original request
          // Prevent infinite retry loops by checking if we already attempted refresh
          if (err.response?.statusCode == 401) {
            // CRITICAL FIX: If the failing request IS the refresh request, do not loop.
            if (err.requestOptions.path.contains('/token/refresh/')) {
               await storage.clearAll();
               handler.next(err);
               return;
            }

            // Check if this request already attempted refresh (to prevent infinite loop)
            final alreadyRefreshed = err.requestOptions.extra['_refresh_attempted'] == true;
            if (alreadyRefreshed) {
              // Already tried refresh, don't retry again - return error
              handler.next(err);
              return;
            }

            final refresh = await storage.getRefresh();
            if (refresh != null && refresh.isNotEmpty) {
              try {
                final res = await dio.post(
                  '/api/auth/token/refresh/',
                  data: {'refresh': refresh},
                  options: Options(headers: {'Authorization': null}), // no old auth
                );
                final newAccess = res.data?['access']?.toString();
                if (newAccess != null && newAccess.isNotEmpty) {
                  await storage.saveTokens(access: newAccess, refresh: refresh);
                  err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                  // Mark as refresh attempted to prevent infinite loop
                  err.requestOptions.extra['_refresh_attempted'] = true;
                  try {
                    final clone = await dio.fetch(err.requestOptions);
                    return handler.resolve(clone);
                  } catch (retryErr) {
                    // Retry still failed (401 again likely means user doesn't exist)
                    // Don't retry again - return the error
                    // If retryErr is DioException, use it; otherwise use original error
                    if (retryErr is DioException) {
                      handler.next(retryErr);
                    } else {
                      handler.next(err);
                    }
                    return;
                  }
                }
              } catch (refreshErr) {
                // Refresh token invalid or expired - clear tokens and return error
                await storage.clearAll();
                handler.next(err);
                return;
              }
            }
          }
          handler.next(err);
        },
      ),
    );

    // Optional: log headers to confirm Authorization is sent
    dio.interceptors.add(LogInterceptor(requestHeader: true, responseHeader: false));
  }

  Future<List<dynamic>> getMyDuties() async {
    final response = await dio.get('/api/assignments/my-duties/');
    return response.data;
  }
  
  Future<void> confirmAssignment(String assignmentId) async {
    await dio.post('/api/assignments/$assignmentId/confirm/');
  }

  Future<void> checkIn(String assignmentId, double lat, double long, String? imagePath) async {
    try {
      final formData = FormData.fromMap({
        "assignment_id": assignmentId,
        "activity_type": "CHECK_IN",
        "latitude": lat,
        "longitude": long,
      });

      if (imagePath != null) {
        formData.files.add(MapEntry(
          "selfie",
          await MultipartFile.fromFile(imagePath, filename: "selfie.jpg"),
        ));
      }

      await dio.post('/api/attendance/logs/', data: formData);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data?['detail'] ?? "Check-in failed");
      }
      throw Exception("Check-in failed: $e");
    }
  }

  Future<void> checkOut(String assignmentId, double lat, double long) async {
    try {
      await dio.post('/api/attendance/logs/', data: {
        "assignment_id": assignmentId,
        "activity_type": "CHECK_OUT",
        "latitude": lat,
        "longitude": long,
      });
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data?['detail'] ?? "Check-out failed");
      }
      throw Exception("Check-out failed: $e");
    }
  }

  // --- Support / Incidents ---

  Future<List<dynamic>> getIncidentCategories() async {
    final response = await dio.get('/api/support/categories/');
    return response.data;
  }

  Future<void> reportIncident({
    required String assignmentId,
    required String categoryId,
    required String priority,
    required String description,
    List<String> imagePaths = const [],
  }) async {
    try {
      final formData = FormData.fromMap({
        'assignment_id': assignmentId,
        'category_id': categoryId,
        'priority': priority,
        'description': description,
        'status': 'OPEN',
      });

      // Append multiple files
      for (final path in imagePaths) {
        formData.files.add(MapEntry(
          'attachments',
          await MultipartFile.fromFile(path),
        ));
      }

      await dio.post('/api/support/incidents/', data: formData);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data?['detail'] ?? "Report failed: ${e.message}");
      }
      throw Exception("Report failed: $e");
    }
  }
}
