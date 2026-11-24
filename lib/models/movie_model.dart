class Movie {
  const Movie({required this.id, required this.title, required this.overview,
    required this.posterPath, required this.releaseDate, this.voteAverage = 0,
    this.userRating});
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final DateTime? releaseDate;
  final double voteAverage;
  // Nota atribuída pelo usuário autenticado; não é a média pública do TMDB.
  final double? userRating;

  String? get posterUrl => posterPath == null || posterPath!.isEmpty
      ? null : 'https://image.tmdb.org/t/p/w500$posterPath';

  factory Movie.fromJson(Map<String, dynamic> json) {
    final rawDate = json['release_date'] as String?;
    return Movie(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Título não disponível',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      releaseDate: rawDate == null || rawDate.isEmpty ? null : DateTime.tryParse(rawDate),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      userRating: (json['rating'] as num?)?.toDouble(),
    );
  }
}
