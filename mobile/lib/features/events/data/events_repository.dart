import "package:dio/dio.dart";
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
    return data
        .map((e) => RegistrationModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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
