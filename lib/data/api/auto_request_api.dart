import 'dart:async';

/// Заглушка для API заявок. Позже подключим сервер.
class AutoRequestApi {
  Future<List<Map<String, dynamic>>> fetchRequests() async {
    // TODO: заменить на HTTP GET/POST
    return const [];
  }

  Future<Map<String, dynamic>> createRequest(
    Map<String, dynamic> payload,
  ) async {
    // TODO: заменить на HTTP POST
    return payload;
  }

  Future<Map<String, dynamic>> updateRequest(
    String id,
    Map<String, dynamic> patch,
  ) async {
    // TODO: заменить на HTTP PATCH/PUT
    return {'id': id, ...patch};
  }
}
