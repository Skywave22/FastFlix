// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter_dotenv/flutter_dotenv.dart';

const String TMDB_API_BASE_URL = 'https://api.themoviedb.org/3';
String? _remoteTmdbApiKey;
String? _clientTmdbApiKey;

/// The optional user-supplied public client key takes precedence over remote
/// and bundled values. It is intentionally separate from account credentials.
/// Used when the on-device override is cleared, including in connection tests.
String get fallbackTmdbApiKey => _remoteTmdbApiKey ??
    (dotenv.isInitialized ? dotenv.env['TMDB_API_KEY'] : null) ??
    '';

String get TMDB_API_KEY => _clientTmdbApiKey ?? fallbackTmdbApiKey;

set TMDB_API_KEY(String value) {
  final trimmed = value.trim();
  _remoteTmdbApiKey = trimmed.isNotEmpty ? trimmed : null;
}

void setClientTmdbApiKey(String value) {
  final trimmed = value.trim();
  _clientTmdbApiKey = trimmed.isNotEmpty ? trimmed : null;
}
String mixpanelKey = dotenv.env['MIXPANEL_API_KEY']!;
const TMDB_BASE_IMAGE_URL = 'https://image.tmdb.org/t/p/';
const String EMBED_BASE_MOVIE_URL =
    'https://www.2embed.to/embed/tmdb/movie?id=';
const String EMBED_BASE_TV_URL = 'https://www.2embed.to/embed/tmdb/tv?id=';
const String YOUTUBE_THUMBNAIL_URL = 'https://i3.ytimg.com/vi/';
const String YOUTUBE_BASE_URL = 'https://youtube.com/watch?v=';
const String FACEBOOK_BASE_URL = 'https://facebook.com/';
const String INSTAGRAM_BASE_URL = 'https://instagram.com/';
const String TWITTER_BASE_URL = 'https://twitter.com/';
const String IMDB_BASE_URL = 'https://imdb.com/title/';
const String TWOEMBED_BASE_URL = 'https://2embed.biz';
String flixquestApiUrl = dotenv.env['FLIXQUEST_API_URL']!;
