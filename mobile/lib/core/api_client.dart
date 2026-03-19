import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "constants.dart";
import "../features/auth/data/auth_token_store.dart";

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.extra["request_started_at_ms"] = DateTime.now().millisecondsSinceEpoch;
        final token = ref.read(authTokenStoreProvider).token;
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final startMs = response.requestOptions.extra["request_started_at_ms"] as int?;
        final endMs = DateTime.now().millisecondsSinceEpoch;
        final tookMs = startMs == null ? null : (endMs - startMs);
        debugPrint(
          "[HTTP] ${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode} (${tookMs ?? "?"}ms)",
        );
        return handler.next(response);
      },
      onError: (e, handler) {
        final startMs = e.requestOptions.extra["request_started_at_ms"] as int?;
        final endMs = DateTime.now().millisecondsSinceEpoch;
        final tookMs = startMs == null ? null : (endMs - startMs);
        final status = e.response?.statusCode;
        debugPrint(
          "[HTTP] ${e.requestOptions.method} ${e.requestOptions.path} -> ${status ?? "ERR"} (${tookMs ?? "?"}ms) ${e.type}",
        );
        return handler.next(e);
      },
    ),
  );
  return dio;
});
