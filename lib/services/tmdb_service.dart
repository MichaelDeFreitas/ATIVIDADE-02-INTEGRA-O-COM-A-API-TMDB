import 'package:dio/dio.dart';
import '../models/movie_model.dart';

class TmdbService {
  // Use o Read Access Token (API v4) via --dart-define. Não coloque a credencial no Git.
  static const String _accessToken = String.fromEnvironment('TMDB_ACCESS_TOKEN');
  late final Dio _dio;

  TmdbService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'accept': 'application/json',
        if (_accessToken.isNotEmpty) 'Authorization': 'Bearer $_accessToken',
      },
    ));
  }

  bool get hasToken => _accessToken.isNotEmpty;

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['status_message'] is String) return data['status_message'];
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
      return 'Tempo limite de conexão excedido.';
    }
    if (error.response?.statusCode == 401) return 'Credencial ou sessão inválida.';
    return error.message ?? 'Erro de comunicação com o TMDB.';
  }

  Never _fail(String operation, DioException error) => throw Exception('$operation: ${_errorMessage(error)}');

  Future<String> createRequestToken() async {
    try {
      final response = await _dio.get('/authentication/token/new');
      return response.data['request_token'] as String;
    } on DioException catch (e) { _fail('Falha ao iniciar autenticação', e); }
  }

  Future<String> createSessionId(String requestToken) async {
    try {
      final response = await _dio.post('/authentication/session/new', data: {'request_token': requestToken});
      return response.data['session_id'] as String;
    } on DioException catch (e) { _fail('Falha ao criar sessão', e); }
  }

  Future<int> getAccountId(String sessionId) async {
    try {
      final response = await _dio.get('/account', queryParameters: {'session_id': sessionId});
      return (response.data['id'] as num).toInt();
    } on DioException catch (e) { _fail('Falha ao obter conta', e); }
  }

  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    try {
      final response = await _dio.get('/movie/upcoming', queryParameters: {'language': 'pt-BR', 'page': page});
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((item) => Movie.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) { _fail('Erro ao buscar lançamentos', e); }
  }

  Future<List<Movie>> getFavoriteMovies({required int accountId, required String sessionId, int page = 1}) async {
    try {
      final first = await _dio.get('/account/$accountId/favorite/movies',
        queryParameters: {'session_id': sessionId, 'language': 'pt-BR', 'page': page, 'sort_by': 'created_at.desc'});
      final movies = <Movie>[];
      final firstResults = first.data['results'] as List<dynamic>? ?? [];
      movies.addAll(firstResults.map((item) => Movie.fromJson(item as Map<String, dynamic>)));
      final totalPages = (first.data['total_pages'] as num?)?.toInt() ?? page;
      for (var currentPage = page + 1; currentPage <= totalPages; currentPage++) {
        final response = await _dio.get('/account/$accountId/favorite/movies',
          queryParameters: {'session_id': sessionId, 'language': 'pt-BR', 'page': currentPage, 'sort_by': 'created_at.desc'});
        final results = response.data['results'] as List<dynamic>? ?? [];
        movies.addAll(results.map((item) => Movie.fromJson(item as Map<String, dynamic>)));
      }
      return movies;
    } on DioException catch (e) { _fail('Erro ao carregar lista de favoritos', e); }
  }

  Future<List<Movie>> getRatedMovies({required int accountId, required String sessionId, int page = 1}) async {
    try {
      final first = await _dio.get('/account/$accountId/rated/movies',
        queryParameters: {'session_id': sessionId, 'language': 'pt-BR', 'page': page, 'sort_by': 'created_at.desc'});
      final movies = <Movie>[];
      final firstResults = first.data['results'] as List<dynamic>? ?? [];
      movies.addAll(firstResults.map((item) => Movie.fromJson(item as Map<String, dynamic>)));
      final totalPages = (first.data['total_pages'] as num?)?.toInt() ?? page;
      for (var currentPage = page + 1; currentPage <= totalPages; currentPage++) {
        final response = await _dio.get('/account/$accountId/rated/movies',
          queryParameters: {'session_id': sessionId, 'language': 'pt-BR', 'page': currentPage, 'sort_by': 'created_at.desc'});
        final results = response.data['results'] as List<dynamic>? ?? [];
        movies.addAll(results.map((item) => Movie.fromJson(item as Map<String, dynamic>)));
      }
      return movies;
    } on DioException catch (e) { _fail('Erro ao carregar suas avaliações', e); }
  }

  Future<Set<int>> getFavoriteMovieIds({required int accountId, required String sessionId}) async {
    try {
      final response = await _dio.get('/account/$accountId/favorite/movies',
        queryParameters: {'session_id': sessionId, 'language': 'pt-BR'});
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((item) => (item['id'] as num).toInt()).toSet();
    } on DioException catch (e) { _fail('Erro ao carregar favoritos', e); }
  }

  Future<bool> markAsFavorite({required int accountId, required String sessionId,
      required int movieId, required bool favorite}) async {
    try {
      final response = await _dio.post('/account/$accountId/favorite',
        queryParameters: {'session_id': sessionId},
        data: {'media_type': 'movie', 'media_id': movieId, 'favorite': favorite});
      return response.data['success'] == true;
    } on DioException catch (e) { _fail('Erro ao atualizar favorito', e); }
  }

  Future<bool> rateMovie({required int movieId, required String sessionId, required double rating}) async {
    if (rating < 0.5 || rating > 10 || (rating * 2) % 1 != 0) {
      throw ArgumentError('A nota deve ser de 0,5 a 10,0, em intervalos de 0,5.');
    }
    try {
      final response = await _dio.post('/movie/$movieId/rating',
        queryParameters: {'session_id': sessionId}, data: {'value': rating});
      return response.data['success'] == true;
    } on DioException catch (e) { _fail('Erro ao avaliar filme', e); }
  }

  Future<bool> deleteRating({required int movieId, required String sessionId}) async {
    try {
      final response = await _dio.delete('/movie/$movieId/rating', queryParameters: {'session_id': sessionId});
      return response.data['success'] == true;
    } on DioException catch (e) { _fail('Erro ao remover avaliação', e); }
  }
}
