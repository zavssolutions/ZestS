import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";
import "banner_model.dart";

class BannersRepository {
  BannersRepository(this._dio);

  final Dio _dio;

  Future<List<BannerModel>> fetchBanners() async {
    final response = await _dio.get<List<dynamic>>("/banners");
    final data = response.data ?? [];
    return compute(_parseBanners, data);
  }

  static List<BannerModel> _parseBanners(List<dynamic> data) {
    return data
        .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final bannersRepositoryProvider = Provider<BannersRepository>((ref) {
  return BannersRepository(ref.watch(dioProvider));
});

final bannersProvider = FutureProvider<List<BannerModel>>((ref) async {
  return ref.watch(bannersRepositoryProvider).fetchBanners();
});
