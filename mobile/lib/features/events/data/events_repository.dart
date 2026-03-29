import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";
import "../../auth/data/auth_token_store.dart";
import "event_model.dart";

class EventsRepository {
  EventsRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  Future<List<EventModel>> fetchUpcomingEvents() async {
    final token = _ref.read(authTokenStoreProvider).token;
    final endpoint = token == null ? "/events/upcoming/anonymous" : "/events/upcoming";
    final response = await _dio.get<List<dynamic>>(endpoint);
    final data = response.data ?? [];
    return compute(_parseEvents, data);
  }

  static List<EventModel> _parseEvents(List<dynamic> data) {
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String> createShareLink(String eventId) async {
    final response = await _dio.post<Map<String, dynamic>>("/events/$eventId/share-link");
    final data = response.data ?? {};
    return (data["share_link"] as String?) ?? "";
  }

  Future<List<RegistrationModel>> fetchMyRegistrations() async {
    final response = await _dio.get<List<dynamic>>("/events/registrations/me");
    final data = response.data ?? [];
    return compute(_parseRegistrations, data);
  }

  static List<RegistrationModel> _parseRegistrations(List<dynamic> data) {
    return data
        .map((e) => RegistrationModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<EventCategoryModel>> fetchEventCategories(String eventId) async {
    final response = await _dio.get<List<dynamic>>("/events/$eventId/categories");
    final data = response.data ?? [];
    return compute(_parseCategories, data);
  }

  static List<EventCategoryModel> _parseCategories(List<dynamic> data) {
    return data
        .map((e) => EventCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> registerForEvent({
    required String eventId,
    required String categoryId,
    String? userId,
  }) async {
    await _dio.post(
      "/events/registrations",
      data: {
        "event_id": eventId,
        "category_id": categoryId,
        "user_id": userId,
      },
    );
  }

  Future<void> registerForMultipleCategories({
    required String eventId,
    required List<String> categoryIds,
    String? userId,
  }) async {
    await _dio.post(
      "/events/registrations/bulk",
      data: {
        "event_id": eventId,
        "category_ids": categoryIds,
        "user_id": userId,
      },
    );
  }

  Future<List<EventModel>> searchEvents(String query) async {
    final response = await _dio.get<List<dynamic>>(
      "/search/events",
      queryParameters: {"q": query},
    );
    final data = response.data ?? [];
    return compute(_parseEvents, data);
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(dioProvider), ref);
});

final upcomingEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  return ref.watch(eventsRepositoryProvider).fetchUpcomingEvents();
});

final registrationsProvider = FutureProvider<List<RegistrationModel>>((ref) async {
  return ref.watch(eventsRepositoryProvider).fetchMyRegistrations();
});

final searchQueryProvider = StateProvider<String>((ref) => "");

final searchResultsProvider = FutureProvider<List<EventModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return [];
  }
  return ref.watch(eventsRepositoryProvider).searchEvents(query.trim());
});

final eventCategoriesProvider =
    FutureProvider.family<List<EventCategoryModel>, String>((ref, eventId) async {
  return ref.watch(eventsRepositoryProvider).fetchEventCategories(eventId);
});
