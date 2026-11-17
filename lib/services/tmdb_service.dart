import 'package:dio/dio.dart';
import '../models/movie_model.dart';

class TmdbService {
  static const String _apiKey = String.fromEnvironment('TMDB_API_KEY');

  late final Dio _dio;

  TmdbService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.themoviedb.org/3',
        queryParameters: {
          'api_key': _apiKey,
        },
        headers: {
          'accept': 'application/json',
        },
      ),
    );
  }

  bool get hasToken => _apiKey.isNotEmpty;

  // --- FLUXO DE AUTENTICAÇÃO TMDB ---

  Future<String> createRequestToken() async {
    try {
      final response = await _dio.get('/authentication/token/new');
      return response.data['request_token'];
    } on DioException catch (e) {
      throw Exception('Falha ao gerar Request Token: ${e.response?.data['status_message'] ?? e.message}');
    }
  }

  Future<String> createSessionId(String approvedRequestToken) async {
    try {
      final response = await _dio.post(
        '/authentication/session/new',
        data: {'request_token': approvedRequestToken},
      );
      return response.data['session_id'];
    } on DioException catch (e) {
      throw Exception('Falha ao criar sessão. Você aprovou o link no navegador? (${e.response?.data['status_message'] ?? e.message})');
    }
  }

  Future<int> getAccountId(String sessionId) async {
    try {
      final response = await _dio.get(
        '/account',
        queryParameters: {'session_id': sessionId},
      );
      return response.data['id'];
    } on DioException catch (e) {
      throw Exception('Falha ao obter ID da conta: ${e.response?.data['status_message'] ?? e.message}');
    }
  }

  Future<List<Movie>> getUpcomingMovies() async {
    try {
      final response = await _dio.get(
        '/movie/upcoming',
        queryParameters: {'language': 'pt-BR'},
      );
      final List results = response.data['results'];
      return results.map((json) => Movie.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception('Erro ao buscar próximos lançamentos: ${e.response?.data['status_message'] ?? e.message}');
    }
  }

  Future<bool> markAsFavorite({
    required int accountId,
    required String sessionId,
    required int mediaId,
    required bool isFavorite,
  }) async {
    try {
      final response = await _dio.post(
        '/account/$accountId/favorite',
        queryParameters: {'session_id': sessionId},
        data: {
          'media_type': 'movie',
          'media_id': mediaId,
          'favorite': isFavorite,
        },
      );
      return response.data['success'] ?? false;
    } on DioException catch (e) {
      throw Exception('Erro ao atualizar favoritos: ${e.response?.data['status_message'] ?? e.message}');
    }
  }

  Future<bool> rateMovie({
    required int movieId,
    required String sessionId,
    required double rating,
  }) async {
    try {
      final response = await _dio.post(
        '/movie/$movieId/rating',
        queryParameters: {'session_id': sessionId},
        data: {'value': rating},
      );
      return response.data['success'] ?? false;
    } on DioException catch (e) {
      throw Exception('Erro ao enviar avaliação: ${e.response?.data['status_message'] ?? e.message}');
    }
  }

  Future<bool> deleteRating({
    required int movieId,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.delete(
        '/movie/$movieId/rating',
        queryParameters: {'session_id': sessionId},
      );
      return response.data['success'] ?? false;
    } on DioException catch (e) {
      throw Exception('Erro ao remover avaliação: ${e.response?.data['status_message'] ?? e.message}');
    }
  }
}