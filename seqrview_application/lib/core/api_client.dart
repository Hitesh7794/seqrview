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
        onError: (err, handler) async {
          // If unauthorized, try refresh once then retry original request
          // Prevent infinite retry loops by checking if we already attempted refresh
          if (err.response?.statusCode == 401) {
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
}
