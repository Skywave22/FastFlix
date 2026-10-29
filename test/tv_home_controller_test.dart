import 'dart:async';

import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/controllers/tv_home_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem item(MediaKind kind, int id) => MediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: null,
      releaseDate: null,
    );

class _Rows implements HomeFeedSource {
  final anime = Completer<List<MediaItem>>();

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    if (kind == MediaKind.movie && list == HomeList.popular) {
      throw StateError('one row failed');
    }
    if (kind == MediaKind.movie && list == HomeList.animeTrending) {
      return anime.future;
    }
    if (kind == MediaKind.series && list == HomeList.trendingWeek) {
      return [item(kind, 8)];
    }
    return [];
  }

  @override
  Future<List<MediaItem>> discover(MediaKind kind,
          {required int page, required int year, required int genreId}) async =>
      [];
  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async => [];
  @override
  Future<List<Genres>> genres(MediaKind kind) async => [];
  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('TV renders successful rows while another row fails or is delayed',
      () async {
    final source = _Rows();
    final dependencies = AppDependencyProvider();
    final settings = SettingsProvider();
    addTearDown(dependencies.dispose);
    addTearDown(settings.dispose);
    final partials = <TvHomeData>[];
    final result = TvHomeController(source: source).load(
      settings: settings,
      dependencies: dependencies,
      onPartial: partials.add,
    );
    await Future<void>.delayed(Duration.zero);
    expect(partials, isNotEmpty);
    expect(partials.last.trendingSeries.single.id, 8);
    expect(partials.last.popularMovies, isEmpty);
    source.anime.complete([item(MediaKind.movie, 9)]);
    final full = await result;
    expect(full.trendingSeries.single.id, 8);
    expect(full.popularMovies, isEmpty);
    expect(full.topAnimeMovies.single.id, 9);
  });
}
