import 'package:flutter_test/flutter_test.dart';
import 'package:atividade_2_main/models/movie_model.dart';

void main() {
  test('Movie.fromJson converte os campos da resposta TMDB', () {
    final movie = Movie.fromJson({
      'id': 123,
      'title': 'Filme de teste',
      'overview': 'Uma sinopse.',
      'poster_path': '/poster.jpg',
      'release_date': '2026-12-25',
      'vote_average': 7.5,
    });
    expect(movie.id, 123);
    expect(movie.title, 'Filme de teste');
    expect(movie.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(movie.releaseDate, DateTime(2026, 12, 25));
    expect(movie.voteAverage, 7.5);
    expect(movie.userRating, isNull);
  });

  test('Movie separa a avaliação pessoal da média geral do TMDB', () {
    final movie = Movie.fromJson({
      'id': 456,
      'title': 'Filme avaliado',
      'vote_average': 7.2,
      'rating': 9.5,
    });
    expect(movie.voteAverage, 7.2);
    expect(movie.userRating, 9.5);
  });

  test('Movie aceita dados opcionais ausentes', () {
    final movie = Movie.fromJson({'id': 1, 'title': 'Sem detalhes'});
    expect(movie.overview, '');
    expect(movie.posterUrl, isNull);
    expect(movie.releaseDate, isNull);
    expect(movie.voteAverage, 0);
  });
}
