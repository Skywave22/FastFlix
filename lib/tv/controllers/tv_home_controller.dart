import '../../catalog/home_feed_controller.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../models/tv_media_item.dart';

class TvHomeData {
  const TvHomeData({
    required this.popularMovies,
    required this.trendingMovies,
    required this.popularSeries,
    required this.trendingSeries,
    this.topMovies = const <TvMediaItem>[],
    this.topSeries = const <TvMediaItem>[],
    this.topAnimeMovies = const <TvMediaItem>[],
    this.topAnimeSeries = const <TvMediaItem>[],
  });

  final List<TvMediaItem> popularMovies;
  final List<TvMediaItem> trendingMovies;
  final List<TvMediaItem> popularSeries;
  final List<TvMediaItem> trendingSeries;

  /// Today's ten most watched, for the Top 10 rows.
  final List<TvMediaItem> topMovies;
  final List<TvMediaItem> topSeries;
  final List<TvMediaItem> topAnimeMovies;
  final List<TvMediaItem> topAnimeSeries;

  TvMediaItem? get hero {
    if (trendingMovies.isNotEmpty) return trendingMovies.first;
    if (trendingSeries.isNotEmpty) return trendingSeries.first;
    if (popularMovies.isNotEmpty) return popularMovies.first;
    if (popularSeries.isNotEmpty) return popularSeries.first;
    if (topMovies.isNotEmpty) return topMovies.first;
    if (topSeries.isNotEmpty) return topSeries.first;
    if (topAnimeMovies.isNotEmpty) return topAnimeMovies.first;
    if (topAnimeSeries.isNotEmpty) return topAnimeSeries.first;
    return null;
  }

  bool get isEmpty =>
      popularMovies.isEmpty &&
      trendingMovies.isEmpty &&
      popularSeries.isEmpty &&
      trendingSeries.isEmpty &&
      topMovies.isEmpty &&
      topSeries.isEmpty &&
      topAnimeMovies.isEmpty &&
      topAnimeSeries.isEmpty;
}

class TvHomeController {
  const TvHomeController({this.source});

  /// Injectable so independent row failures can be tested without a network.
  final HomeFeedSource? source;

  Future<TvHomeData> load({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    void Function(TvHomeData data)? onPartial,
  }) async {
    final homeSource = source ?? CatalogHomeFeedSource(
      settings: settings,
      dependencies: dependencies,
    );
    final rows = List<List<TvMediaItem>>.generate(
        8, (_) => const <TvMediaItem>[]);
    TvHomeData current() => TvHomeData(
          popularMovies: rows[0],
          trendingMovies: rows[1],
          popularSeries: rows[2],
          trendingSeries: rows[3],
          topMovies: rows[4],
          topSeries: rows[5],
          topAnimeMovies: rows[6],
          topAnimeSeries: rows[7],
        );
    Future<void> row(int index, TvMediaKind kind, HomeList list,
        {int? limit}) async {
      try {
        final items = await homeSource.list(kind, list);
        rows[index] = (limit == null ? items : items.take(limit))
            .toList(growable: false);
        final partial = current();
        if (!partial.isEmpty) onPartial?.call(partial);
      } catch (_) {
        // A single unavailable list must not take the whole TV Home offline.
      }
    }

    await Future.wait<void>([
      row(0, TvMediaKind.movie, HomeList.popular),
      row(1, TvMediaKind.movie, HomeList.trendingWeek),
      row(2, TvMediaKind.series, HomeList.popular),
      row(3, TvMediaKind.series, HomeList.trendingWeek),
      row(4, TvMediaKind.movie, HomeList.trendingToday, limit: 10),
      row(5, TvMediaKind.series, HomeList.trendingToday, limit: 10),
      row(6, TvMediaKind.movie, HomeList.animeTrending, limit: 10),
      row(7, TvMediaKind.series, HomeList.animeTrending, limit: 10),
    ]);
    return current();
  }
}
