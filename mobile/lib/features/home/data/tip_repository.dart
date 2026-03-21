import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";
import "tip_model.dart";

class TipRepository {
  TipRepository(this._dio);

  final Dio _dio;

  Future<TipOfDayModel> fetchTipOfDay() async {
    final response = await _dio.get<Map<String, dynamic>>("/tip-of-the-day");
    final data = response.data ?? const <String, dynamic>{};
    return TipOfDayModel.fromJson(data);
  }
}

final tipRepositoryProvider = Provider<TipRepository>((ref) {
  return TipRepository(ref.watch(dioProvider));
});

final tipOfDayProvider = FutureProvider<TipOfDayModel>((ref) async {
  return ref.watch(tipRepositoryProvider).fetchTipOfDay();
});

