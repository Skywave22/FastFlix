import '../models/genres.dart';
import 'media_item.dart';

/// Anime is not a TMDB genre. Use a private sentinel in the UI and translate
/// it into TMDB's Japanese-language animation filters when making a request.
const animeGenreId = -10001;
const animeGenreValue = 'anime';
const animationGenreValue = '16';

/// TMDB does not expose an anime genre, so apply the same definition to
/// weekly-trending results as to anime discovery.
bool isAnime(MediaItem item) {
  final language = item.movie?.originalLanguage ?? item.series?.originalLanguage;
  return item.id >= 0 &&
      language?.toLowerCase() == 'ja' &&
      item.genreIds.contains(16);
}

/// Presents a filtered raw feed as logical pages. A raw page containing no
/// anime must not end the catalog: only an empty *unfiltered* page does. Failed
/// requests leave their cursor in place for retry. Results are cached so grids
/// can reopen/re-request pages without changing their meaning.
class AnimeTrendingPager {
  AnimeTrendingPager(this.fetchPage, {this.lastRawPage = 500});

  final Future<List<MediaItem>> Function(int page) fetchPage;
  final int lastRawPage;
  final List<List<MediaItem>> _pages = [];
  final Set<String> _seen = {};
  int _nextRawPage = 1;
  bool _ended = false;
  Future<void> _tail = Future.value();

  Future<List<MediaItem>> loadPage(int page) {
    final result = _tail.then((_) => _loadPage(page));
    // Serialize callers and keep the queue usable after a failed request.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<MediaItem>> _loadPage(int page) async {
    if (page < 1) return const [];
    while (_pages.length < page && !_ended) {
      if (_nextRawPage > lastRawPage) {
        _ended = true;
        break;
      }
      final raw = await fetchPage(_nextRawPage);
      _nextRawPage++;
      if (raw.isEmpty) {
        _ended = true;
        break;
      }
      final matches = raw.where((item) =>
          isAnime(item) && _seen.add(item.stableId)).toList(growable: false);
      if (matches.isNotEmpty) _pages.add(matches);
    }
    return page <= _pages.length ? _pages[page - 1] : const [];
  }
}

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
