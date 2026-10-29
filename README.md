<p align="center">
  <img alt="FlixQuest" src="assets/images/FlixQuest.png" width="180">
</p>

<h1 align="center">FlixQuest</h1>

<p align="center">
  <strong>A modern, open-source streaming application for Movies, TV Shows, and Live TV built with Flutter.</strong><br>
  Optimized for <strong>Android Mobile, Tablets</strong>, and <strong>Android TV (10-Foot UI)</strong>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Android%20TV-3DDC84?logo=android&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Version-4.0.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green" alt="License">
</p>

---

## ✨ Features

### 🎬 Extensive Movie & TV Show Catalog

- **Discovery Feeds**: Categorized home feeds with shimmer loading effects — Trending, Top 10 This Week, New Releases, Upcoming, and Popular.
- **Detailed Media Pages**: Media details featuring trailers, cast & crew filmographies, user reviews, and intelligent "More Like This" recommendations powered by TMDB.
- **Explore & Filter**: Filter content by genre (including Anime), release year, streaming provider, country, or sort order, alongside a random discovery tool.
- **TV Seasons & Episodes**: Interactive episode browser with episode thumbnails, descriptions, air dates, and quick episode switcher sheets.

### 📺 Android TV (10-Foot UI Experience)

- **D-Pad Focus Navigation**: Native TV remote control navigation with directional keymaps and focus memory.
- **TV Home Shell & Rail**: TV navigation rail, catalog screens, and hero banners designed specifically for large screens.
- **TV Search & History**: Remote-friendly search interface with recent search query history.
- **Automatic Presentation Detection**: Automatically detects TV devices and adapts the interface between mobile touch and TV 10-foot layout.

### 📡 Free Live TV & Sports Streaming

- **Live TV Integration**: Integrated DaddyLive service providing 24/7 TV channels and scheduled live sports events.
- **Category Browsing & Search**: Search channels by name, filter by category, and view local time-formatted schedules.
- **Stream Recovery & Buffering**: Smart playback recovery (90-second window), auto-reconnect, and optimized live buffering.
- **Local Caching**: Fast SQLite caching for live channels and event schedules.

### 🚀 Multi-Source Video Providers & Scraper API v2

- **Dynamic Provider System**: Integrated with **FlixQuest Scraper API v2** for scraping high-quality streams.
- **Live Provider Health Status**: Real-time provider uptime monitoring (`/providers/status`) with in-app status indicators.
- **Direct Fallback Provider**: Built-in direct VixSrc provider fallback.
- **Custom Provider Prioritization**: Reorder and prioritize your preferred streaming providers in Settings.
- **Stream Formats**: Full support for HLS (.m3u8), DASH (.mpd), and direct MP4 streams with custom header support.

### 💬 Comprehensive Subtitle Management

- **Automatic External Subtitles**: Multi-language subtitle search and retrieval powered by Wyzie Subtitles API.
- **Audio tracks**: Choose available HLS/DASH manifest audio tracks in the player. Availability and exact matching depend on the stream and player; ambiguous same-language DASH tracks may still use the player's native order.
- **Local Subtitle Upload**: Pick and load local `.srt` or `.vtt` subtitle files directly from your device storage.
- **Subtitle Customization**: Adjust font size, text color, background color, and visual styling presets.
- **Encoding & HI Support**: Smart character encoding handling (UTF-8, Latin1, ASCII) and Hearing-Impaired (HI) tags.

### 📥 Offline Downloads

- **Background Downloads**: Download movies and TV episodes from HLS/DASH sources with background management, progress notifications and estimated time remaining. New direct-file downloads are not currently supported.
- **Advanced download settings**: Choose adaptive-stream segment workers, simultaneous downloads, retries and an unmetered-network requirement. HLS/DASH segments can download in parallel; actual speed depends on the source and connection.
- **Download location**: New downloads keep an app-private Media3 cache for offline playback and try to create a separate playable MP4 in `Downloads/FastFlix/Movies` or `Downloads/FastFlix/Series/<series name>`. In Downloads → settings, choose another folder (including an SD card) or restore the default. The selection applies to new jobs; retry a failed copy to use the current folder. The private cache and public copy consume additional space. Some streams cannot be remuxed; a failed copy is reported without deleting the offline download. Deleting an offline download does not delete its public copy.
- **Size estimates**: Qualities show approximate sizes when the provider or stream manifest exposes enough information. If not, the size is unknown; actual video/audio and exported sizes can differ. In-progress totals no longer extrapolate from segment-count percentages.
- **Player preferences**: Optionally fill the mobile screen (edges can be cropped) and prioritize sources explicitly labeled Hindi. Other sources remain available and metadata may be incomplete.
- **Trending anime**: Home ranks Japanese-language animation found in the first five pages of weekly TMDB trends. Fewer than ten may be shown; See all pages through the matching weekly-trending movie or series feed, skipping pages without anime.
- **Aspect Ratio Normalization**: Built-in video exporter with square-pixel aspect ratio normalization.
- **Subtitle Bundling**: Automatically export and bundle subtitles with downloaded videos for offline viewing.
- **Offline Player**: Dedicated offline library and media player for downloaded files.

### 🎨 Modern UI, Ambient Glow & Seasonal Themes

- **Phosphor Icons**: Clean, consistent icon set using Phosphor Flutter icons across the entire app.
- **Ambient Mode**: Dynamic color palette extraction from movie/show posters and backdrops for an immersive ambient background glow.
- **Occasional & Seasonal Themes**: Dynamic holiday themes (Christmas, New Year, Halloween, Valentine's Day, Easter, Eid, Diwali, Ethiopian New Year, etc.) with animated vector particle overlays (snow, fireworks, bats, hearts, adey flowers, confetti, stars, sparkles). Configurable via Firebase Remote Config.
- **Themes**: Light, Dark, AMOLED Pure Black, and Material 3 Dynamic Color palettes.

### 🔐 User Profiles & Cloud Synchronization

- **Firebase Authentication**: User accounts with email/password authentication, profile management, and account deletion.
- **Cross-Device Bookmark Sync**: Dual-layer bookmark synchronization between local SQLite and Cloud Firestore.
- **Recently Watched & Resume**: Track watch progress across movies and episodes with quick resume playback.

### 🌍 Multi-Language Localization

- Complete internationalization powered by `easy_localization` supporting multiple languages including English, Spanish, Arabic, Hindi, and more.

---

## 📱 Screenshots

<table style="border: none;">
  <tr>
    <td align="center"><b>Home & Discovery</b><br><img src="docs/screenshots/movies-home.jpg" alt="Home Screen" width="220"/></td>
    <td align="center"><b>Movie Details</b><br><img src="docs/screenshots/movie-detail.jpg" alt="Movie Details" width="220"/></td>
    <td align="center"><b>Series Details</b><br><img src="docs/screenshots/series-detail.jpg" alt="Series Details" width="220"/></td>
    <td align="center"><b>Seasons & Episodes</b><br><img src="docs/screenshots/season-detail.jpg" alt="Seasons & Episodes" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Episode Browser</b><br><img src="docs/screenshots/episodes.jpg" alt="Episode Browser" width="220"/></td>
    <td align="center"><b>Watch & Download</b><br><img src="docs/screenshots/episode-detail.jpg" alt="Episode Detail" width="220"/></td>
    <td align="center"><b>Offline Downloads</b><br><img src="docs/screenshots/downloads.jpg" alt="Offline Downloads" width="220"/></td>
    <td align="center"><b>Live TV & Sports</b><br><img src="docs/screenshots/live-tv.jpg" alt="Live TV" width="220"/></td>
  </tr>
  <tr>
    <td colspan="4" align="center"><b>Immersive Video Player</b><br><img src="docs/screenshots/player.jpg" alt="Video Player" width="800"/></td>
  </tr>
</table>

---

## ⚙️ Environment Variables & API Keys

FlixQuest uses `flutter_dotenv` to load environment variables. Create a `.env` file in the root directory of the project:

```env
# Required: TMDB API Key for movie and TV show metadata
TMDB_API_KEY="your_tmdb_api_key"

# Required: FlixQuest Scraper API v2 instance URL
FLIXQUEST_API_URL="https://your-flixquest-api-instance.com"

# Required: Laravel backend base URL (use a device-reachable URL in releases)
LARAVEL_API_URL="https://your-laravel-api-instance.com"

# Include this entry; the Mixpanel project token itself may be empty
MIXPANEL_API_KEY=
```

### Obtaining API Keys

- **TMDB API Key**: Register at [The Movie Database (TMDB)](https://developer.themoviedb.org/v3/reference/intro/authentication#api-key-quick-start) to get your free API key.
- **FlixQuest Scraper API**: The scraper service is closed-source. For API access, self-hosting inquiries, or support, please reach out to [flixquestapp@gmail.com](mailto:flixquestapp@gmail.com).
- **Mixpanel Token** _(Optional)_: Create a free account at [Mixpanel](https://mixpanel.com).

---

## 🕷️ FlixQuest Scraper API v2

FlixQuest communicates with **FlixQuest Scraper API v2** for resolving streaming sources. The backend service is closed-source; please contact [flixquestapp@gmail.com](mailto:flixquestapp@gmail.com) for support or API instance access.

The client-side API contract and payload schemas are documented in [`openapi.json`](openapi.json).

Key endpoints consumed by the app:

- `GET /providers`: Discovers available and enabled video providers.
- `GET /providers/status`: Fetches live provider health status, latency, and uptime.
- `GET /stream-movie`: Scrapes streaming links for movies using TMDB ID.
- `GET /stream-tv`: Scrapes streaming links for TV episodes using TMDB ID, season, and episode number.
- `GET /subtitles/search`: Searches every subtitle provider for a movie or episode and returns one combined catalog.
- `GET /subtitles/{provider}/{id}`: Downloads a subtitle file. The API converts and re-encodes it, so the app never contacts a subtitle host directly.
- `POST /stream-size`: Estimates the byte size behind a stream token so the quality picker can show sizes.
- `GET /api/v2/intro`: Retrieves branded intro video configuration.

---

## 🔥 Firebase Configuration

FlixQuest uses Firebase for several services:

| Service                       | Purpose                                                                                                                                                                                                                             |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Firebase Authentication**   | User authentication, profile management, and session handling.                                                                                                                                                                      |
| **Cloud Firestore**           | Cloud bookmark synchronization across multiple devices.                                                                                                                                                                             |
| **Firebase Remote Config**    | Dynamic configuration for feature toggles (Watch now, Download, Live TV), app logos, seasonal themes, and vector animation effects. See [`docs/firebase_remote_config.md`](docs/firebase_remote_config.md) for full schema details. |
| **Firebase Cloud Messaging**  | Background notifications and alerts.                                                                                                                                                                                                |
| **Firebase In-App Messaging** | Dynamic in-app banners and update notices.                                                                                                                                                                                          |
| **Firebase Analytics**        | Usage and performance analytics.                                                                                                                                                                                                    |

> **Note**: To connect to your own Firebase project, place your `google-services.json` inside `android/app/`.

---

## ▶️ Custom `better_player` Package

This repository uses a customized version of `better_player` (`better_player_plus`) located at [github.com/BeamlakAschalew/flixquest-betterplayer](https://github.com/BeamlakAschalew/flixquest-betterplayer).

You can configure it in `pubspec.yaml` using a local path or git URL:

```yaml
better_player_plus:
  git:
    url: https://github.com/BeamlakAschalew/flixquest-betterplayer.git
```

Or reference a local sibling directory:

```yaml
better_player_plus:
  path: ../flixquest-betterplayer
```

---

## 🛠️ Getting Started & Build Instructions

### Prerequisites

- **Flutter / Dart**: Flutter 3.35.7 (`.fvmrc`), Dart 3.9+
- **Android SDK / NDK**: SDK platform 36, build tools 36.0.0, NDK 28.2.13676358, Java 17

### Installation Steps

1. **Clone the repository**:

   ```bash
   git clone https://github.com/BeamlakAschalew/flixquest.git
   cd flixquest
   ```

2. **Clone the custom better_player repository** (if using local path):

   ```bash
   cd ..
   git clone https://github.com/BeamlakAschalew/flixquest-betterplayer.git
   git -C flixquest-betterplayer checkout --detach 9a4753b317c7153dbfc10738a6787fb3e5be8610
   cd flixquest
   ```

3. **Configure Environment Variables**:
   Create a `.env` file in the project root:

   ```bash
   cp .env.example .env # or create a new .env file with your keys
   ```

4. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

5. **Run the Application**:
   - For Android Mobile / Tablet:

     ```bash
     flutter run
     ```

   - For Android TV (Emulator or connected TV device):

     ```bash
     flutter run -d <tv-device-id>
     ```

   The app detects TV or mobile mode automatically by default. If a custom ROM
   reports the wrong device type, choose **Settings → Appearance → App mode →
   TV** or **Mobile**. The interface switches immediately and the choice is saved
   across launches. Choose **Automatic** to return to device detection.

   Android has `prod` (the default) and `dev` flavors. Run `flutter run --flavor dev`
   for the dev launcher label. Both flavors share the package and Firebase
   registration, so they use the same install slot.

6. **Build Release APK**:

   ```bash
   flutter build apk --release
   ```

   This uses the default `prod` flavor and outputs
   `build/app/outputs/flutter-apk/app-prod-release.apk`. You can also specify
   `--flavor prod` explicitly. A development release APK is built with
   `flutter build apk --flavor dev --release`.

   For smaller per-device downloads, also build split APKs:

   ```bash
   flutter build apk --release --split-per-abi
   ```

   The update screen downloads the APK matching the device's CPU. Publish each
   split APK's link in Remote Config under `app_download_url_arm64_v8a`,
   `app_download_url_armeabi_v7a` and `app_download_url_x86_64`, and keep the
   universal APK in `app_download_url`. A device whose ABI can't be read, or
   whose key is empty, downloads the universal APK.

### Build and publish APKs with GitHub Actions

The **Android APK** workflow uses the Flutter version in `.fvmrc`, Java 17, and
a pinned checkout of the sibling Better Player project. Pushes to
`arena/f6eedbd9-fastflix` run an artifact-only build; they do not publish a
release. With the secrets below configured, it builds the signed `prod` release,
runs the focused Flutter and Android download-settings tests, and uploads a
universal APK, three ABI-specific APKs, and `SHA256SUMS.txt`.

For an artifact-only build without all the secrets, it instead uploads a
**debug preview APK** with `.env.example` and a temporary debug signing key.
The example has an emulator-only backend URL and no TMDB key, so online features
may not work. The preview also contains deliberately invalid, debug-only Firebase
options: it is not registered with Firebase and Firebase services will not work.
The APK cannot update an installation signed by a different key and must not be
distributed as a production release. Tag and manual release builds never use
this fallback.

To build and publish production APKs, configure these repository secrets under
**Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore file. For example, run `base64 < path/to/release.jks \| tr -d '\n'` locally and copy the output into the secret. |
| `ANDROID_STORE_PASSWORD` | The keystore password. |
| `ANDROID_KEY_ALIAS` | The signing key's alias. |
| `ANDROID_KEY_PASSWORD` | The signing key's password. |
| `FLIXQUEST_ENV` | Complete multi-line release `.env` contents, based on `.env.example`. |
| `FIREBASE_ANDROID_CONFIG` | Complete `google-services.json` downloaded after registering `io.github.skywave22.fastflix` as an Android app in the correct Firebase project. |

`FLIXQUEST_ENV` must contain non-empty `TMDB_API_KEY`, `FLIXQUEST_API_URL`, and
`LARAVEL_API_URL` values, plus a `MIXPANEL_API_KEY` entry (which may be empty).
Use literal values instead of `.env` variable interpolation for the required
entries. Use real, device-reachable HTTP(S) base URLs: the emulator-only `10.0.2.2`
example is rejected. Add the other public client settings from `.env.example` as
needed. **Everything in `.env` is bundled into the APK and can be extracted**;
never put server-side credentials or other private secrets there. The tracked
`android/app/google-services.json` registers the old package only and cannot be
used for this application ID. The workflow validates `FIREBASE_ANDROID_CONFIG`
and writes it to a release-only source set; editing the old package name in JSON
is not a Firebase registration. The new application ID installs separately from
the old app even if signed with the same key. The release keystore and its
passwords remain private and must be retained for future FastFlix updates.
Google Sign-In, push notifications, Remote Config, app links and billing may
also need the new package and signing fingerprint registered in their respective
services before they work in production.

For a local debug-only preview, run `python3 .github/scripts/prepare_firebase_android.py preview`
after copying `.env.example` to `.env`. This creates invalid Firebase options in
the ignored `prod/debug` source set only. A local production build must instead
use a real Firebase configuration for the new package and proper release signing.

To publish, push a tag beginning with `v` that points to the commit to release.
The workflow creates a published GitHub release with generated notes if one
for the tag doesn't exist, or replaces matching APK assets on the existing
release while preserving its notes and draft/prerelease status. New semantic
prerelease tags such as `v1.2.3-rc.1` are marked as prereleases. Set the app
version in `pubspec.yaml` before tagging. The repository's Actions token must
have permission to write contents/releases.

You can also run **Android APK** manually: leave `release_tag` blank for an
artifact-only build of the selected ref (signed release if configured, otherwise
preview), or supply an existing tag to build that tag and attach signed APKs to
its release. The tag must include the
workflow's preparation scripts and feature tests. GitHub only exposes manual
workflow dispatch after the workflow file exists on the repository's default
branch; a tag push can run the workflow from the tagged commit without merging
this work. Artifacts are retained for 30 days. No release is published merely
by adding this workflow.

---

## 🤝 Contributing

Contributions, feature suggestions, design ideas, and translations are always welcome!

- **Pull Requests**: Please ensure your code passes static analysis and is properly formatted:

  ```bash
  dart format .
  flutter test
  ```

- **Issue Reports**: Please follow the provided issue templates when opening bugs or feature requests.

---

## ⚠️ Disclaimer

- The developers of this application have no affiliation with content providers like TMDB, DaddyLive, or any third-party streaming websites.
- FlixQuest **does not host or upload any video content**. All media is retrieved via public scrapers and third-party APIs.
- In case of copyright infringement, please contact the responsible hosting services or source providers directly.

---

<div align="center">
  <h3>Support the Project</h3>
  <a href="https://www.buymeacoffee.com/cinemaxapp">
    <img src="https://i.ibb.co/Tr4sC5X/bmc-button.png" height="60" alt="Buy Me A Coffee">
  </a>
</div>

---

### 🙏 Credits & Integrations

- **TMDB API**: Media metadata, cast, crew, and artwork.
- **Phosphor Icons**: Beautiful, consistent icon pack (`phosphor_flutter`).
- **Matinee Flutter**: Initial UI inspiration and base architecture (`bimsina/Matinee-Flutter`).

---

<p align="center">
  <i>GNU, but for Entertainment</i><br><br>
  <strong>© 2022–2026 FlixQuest</strong>
</p>
