import '../models/genres.dart';

/// Anime is not a TMDB genre. Use a private sentinel in the UI and translate
/// it into TMDB's Japanese-language animation filters when making a request.
const animeGenreId = -10001;
const animeGenreValue = 'anime';
const animationGenreValue = '16';

List<Genres> withAnimeGenre(Iterable<Genres> genres, {required String label}) {
  final result =
      genres.where((genre) => genre.genreID != animeGenreId).toList();
  result.add(Genres(genreID: animeGenreId, genreName: label));
  return result;
}

/// Turns UI genre values into valid TMDB query parameters. Combining Anime
/// with another genre keeps both filters (and avoids adding animation twice).
Map<String, String> genreParameters(Iterable<String> selected) {
  final genres = selected.toSet();
  final anime = genres.remove(animeGenreValue);
  if (anime) genres.add(animationGenreValue);
  return {
    'with_genres': genres.join(','),
    if (anime) 'with_original_language': 'ja',
  };
}
