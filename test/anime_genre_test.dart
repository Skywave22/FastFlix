import 'package:flixquest/api/endpoints.dart';
import 'package:flixquest/catalog/anime_genre.dart';
import 'package:flixquest/catalog/discover_query.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
  });

  test('Anime is a unique, localized option alongside Animation', () {
    final source = [
      Genres(genreID: 16, genreName: 'Animation'),
      Genres(genreID: animeGenreId, genreName: 'old label'),
    ];
    final genres = withAnimeGenre(source, label: 'Anime');
    expect(genres.map((genre) => genre.genreID), [16, animeGenreId]);
    expect(genres.last.genreName, 'Anime');
    expect(source.last.genreName, 'old label');
  });

  for (final kind in MediaKind.values) {
    test('$kind discover combines Anime with other filters', () {
      final query = DiscoverQuery(kind)
        ..genres.addAll(['16', animeGenreValue, '35']);
      final parameters = Uri.parse(query.url('en')).queryParameters;
      expect(parameters['with_genres'], '16,35');
      expect(parameters['with_original_language'], 'ja');
      expect(parameters.values, isNot(contains(animeGenreValue)));
      expect(query.genreOptions.map((item) => item.value),
          contains(animeGenreValue));

      query.genres.remove(animeGenreValue);
      final withoutAnime = Uri.parse(query.url('en')).queryParameters;
      expect(withoutAnime['with_genres'], '16,35');
      expect(withoutAnime.containsKey('with_original_language'), isFalse);
    });
  }

  test('movie and series genre pages map the sentinel before reaching TMDB',
      () {
    for (final url in [
      Endpoints.getMoviesForGenre(animeGenreId, 3, 'es-ES'),
      Endpoints.getTVShowsForGenre(animeGenreId, 3, 'es-ES'),
    ]) {
      final parameters = Uri.parse(url).queryParameters;
      expect(parameters['with_genres'], '16');
      expect(parameters['with_original_language'], 'ja');
      expect(parameters['page'], '3');
      expect(parameters['language'], 'es-ES');
    }
    final ordinary = Uri.parse(Endpoints.getMoviesForGenre(16, 1, 'en'));
    expect(ordinary.queryParameters.containsKey('with_original_language'),
        isFalse);
  });
}
