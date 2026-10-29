import 'package:flixquest/catalog/anime_genre.dart';
import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem item(
  MediaKind kind,
  int id, {
  String language = 'ja',
  List<int> genres = const [16],
}) => kind == MediaKind.movie
    ? MediaItem.fromMovie(
        Movie(
          id: id,
          title: 'Movie $id',
          originalLanguage: language,
          genreIds: genres,
        ),
      )
    : MediaItem.fromSeries(
        TV(
          id: id,
          name: 'Series $id',
          originalLanguage: language,
          genreIds: genres,
        ),
      );

class FakeCatalog extends CatalogController {
  FakeCatalog(this.pages);
  final Map<int, List<MediaItem>> pages;
  final List<Uri> requests = [];

  @override
  Future<List<MediaItem>> loadRow({
    required MediaKind kind,
    required String url,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool strict = false,
  }) async {
    final uri = Uri.parse(url);
    requests.add(uri);
    return pages[int.parse(uri.queryParameters['page']!)] ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => dotenv.testLoad(
      fileInput: 'TMDB_API_KEY=test\nFLIXQUEST_API_URL=https://example.test',
    ),
  );

  for (final kind in MediaKind.values) {
    test(
      '$kind: ranks Japanese animation from weekly trending pages without popular filler',
      () async {
        final catalog = FakeCatalog({
          1: [
            item(kind, 1),
            item(kind, 2, language: 'en'),
            item(kind, 3, genres: [28]),
            item(kind, 4),
          ],
          2: [item(kind, 4), item(kind, 5)],
          3: [item(kind, 6)],
        });
        final settings = SettingsProvider();
        final dependencies = AppDependencyProvider();
        addTearDown(settings.dispose);
        addTearDown(dependencies.dispose);
        final source = CatalogHomeFeedSource(
          settings: settings,
          dependencies: dependencies,
          catalog: catalog,
        );
        final items = await source.list(kind, HomeList.animeTrending);
        expect(items.map((i) => i.id), [1, 4, 5, 6]);
        expect(catalog.requests, hasLength(5));
        expect(
          catalog.requests.every((uri) => uri.path.contains('/trending/')),
          isTrue,
        );
        expect(
          catalog.requests.map((uri) => uri.queryParameters['page']).toSet(),
          {'1', '2', '3', '4', '5'},
        );
        // The whole collection is built from the same trending endpoint.
        final browse = Uri.parse(source.urlFor(kind, HomeList.animeTrending)!);
        expect(
          browse.path,
          contains(kind == MediaKind.movie
              ? '/trending/movie/week'
              : '/trending/tv/week'),
        );
      },
    );
  }

  test('See all skips empty filtered pages, deduplicates and retries', () async {
    final requests = <int>[];
    var failOnce = true;
    final pages = {
      1: [item(MediaKind.movie, 1, language: 'en')],
      2: [item(MediaKind.movie, 2)],
      3: [item(MediaKind.movie, 2)],
      4: [item(MediaKind.movie, 3)],
    };
    final pager = AnimeTrendingPager((page) async {
      requests.add(page);
      if (page == 2 && failOnce) {
        failOnce = false;
        throw StateError('temporary connection failure');
      }
      return pages[page] ?? [];
    });
    await expectLater(pager.loadPage(1), throwsStateError);
    expect((await pager.loadPage(1)).map((i) => i.id), [2]);
    // Cached logical page, with no extra network call.
    expect((await pager.loadPage(1)).map((i) => i.id), [2]);
    expect((await pager.loadPage(2)).map((i) => i.id), [3]);
    expect(await pager.loadPage(3), isEmpty);
    expect(requests, [1, 2, 2, 3, 4, 5]);
  });

  test('ranking deduplicates, preserves order and caps at ten', () {
    final values = [for (var i = 0; i < 12; i++) item(MediaKind.movie, i)];
    expect(
      topTrendingAnime([values.first, ...values]).map((i) => i.id),
      List.generate(10, (i) => i),
    );
  });
}
