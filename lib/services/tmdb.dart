part of '../main.dart';

// ════════════════════════════════════════════════════════════════
//  TMDB — The Movie Database API
//  مصدر المعلومات الوصفية فقط (بوستر، تقييم، وصف، ممثلين)
//  ليس له علاقة بالسيرفر أو الاشتراك
// ════════════════════════════════════════════════════════════════
class TMDB {
  static const _defaultKey = '5b166a24c91f59178e8ce30f1f3735c0';
  static const _base       = 'https://api.themoviedb.org/3';
  static const _img        = 'https://image.tmdb.org/t/p';

  static String get _key => RC.tmdbKey.isNotEmpty ? RC.tmdbKey : _defaultKey;

  static final _dio   = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8)));
  static final _cache = HashMap<String, Map<String, String>>();

  static String poster(String path, {String size = 'w500'}) =>
      path.isEmpty ? '' : '$_img/$size$path';
  static String backdrop(String path) =>
      path.isEmpty ? '' : '$_img/w1280$path';
  static String thumb(String path) =>
      path.isEmpty ? '' : '$_img/w342$path';

  static String _clean(String n) => n
      .replaceAll(RegExp(r'\b(4K|FHD|HD|SD|UHD|720p|1080p|2160p|S\d{2}E\d{2})\b',
          caseSensitive: false), '')
      .replaceAll(RegExp(r'[\[\]()|_\-]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  static Future<Map<String, String>> search(String name, {bool isTv = false}) async {
    final cacheKey = '${isTv ? "tv" : "mv"}_$name';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    for (final lang in ['ar', 'en']) {
      try {
        final r = await _dio.get(
          '$_base/search/${isTv ? "tv" : "movie"}',
          queryParameters: {
            'api_key': _key, 'query': _clean(name),
            'language': lang, 'include_adult': false,
          },
        );
        final results = (r.data['results'] as List?)?.cast<Map>();
        if (results == null || results.isEmpty) continue;
        final best = results.firstWhere(
            (x) => (x['poster_path'] ?? '').toString().isNotEmpty,
            orElse: () => results.first);

        String cast = '', director = '';
        try {
          final credits = await _dio.get(
            '$_base/${isTv ? "tv" : "movie"}/${best['id']}/credits',
            queryParameters: {'api_key': _key},
          );
          cast = (credits.data['cast'] as List? ?? [])
              .take(5).map((c) => c['name']?.toString() ?? '').join('، ');
          director = ((credits.data['crew'] as List? ?? [])
              .firstWhere((c) => c['job'] == 'Director', orElse: () => {}))
              ['name']?.toString() ?? '';
        } catch (e) { debugPrint('[tmdb] $e'); }

        final info = <String, String>{
          'poster':    poster(best['poster_path']?.toString() ?? ''),
          'poster_sm': poster(best['poster_path']?.toString() ?? '', size: 'w342'),
          'backdrop':  backdrop(best['backdrop_path']?.toString() ?? ''),
          'overview':  best['overview']?.toString() ?? '',
          'rating':    (best['vote_average'] ?? 0.0).toStringAsFixed(1),
          'year':      (best['release_date'] ?? best['first_air_date'] ?? '')
              .toString().length >= 4
              ? (best['release_date'] ?? best['first_air_date'] ?? '').toString().substring(0, 4)
              : '',
          'title':    (best['title'] ?? best['name'] ?? name).toString(),
          'cast':      cast,
          'director':  director,
          'tmdb_id':   best['id'].toString(),
        };
        if (info['poster']!.isNotEmpty || info['backdrop']!.isNotEmpty) {
          _cache[cacheKey] = info;
          return info;
        }
      } catch (e) { debugPrint('[tmdb] $e'); }
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> getCast(int tmdbId, {bool isTv = false}) async {
    try {
      final r = await _dio.get(
        '$_base/${isTv ? "tv" : "movie"}/$tmdbId/credits',
        queryParameters: {'api_key': _key, 'language': 'ar'},
      );
      return (r.data['cast'] as List? ?? []).take(20).map((c) => <String, dynamic>{
        'id':           c['id'],
        'name':         c['name']?.toString() ?? '',
        'character':    c['character']?.toString() ?? '',
        'profile_path': c['profile_path'] != null ? '$_img/w185${c['profile_path']}' : '',
        'order':        c['order'] ?? 99,
      }).toList();
    } catch (_) { return []; }
  }

  static Future<String?> getTrailerUrl(int tmdbId, {bool isTv = false}) async {
    try {
      for (final lang in ['ar', 'en-US']) {
        final r = await _dio.get(
          '$_base/${isTv ? "tv" : "movie"}/$tmdbId/videos',
          queryParameters: {'api_key': _key, 'language': lang},
        );
        final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
        if (results.isEmpty) continue;
        final trailer = results.firstWhere(
            (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
            orElse: () => results.firstWhere(
                (v) => v['site'] == 'YouTube', orElse: () => {}));
        final key = trailer['key']?.toString() ?? '';
        if (key.isNotEmpty) return 'https://www.youtube.com/watch?v=$key';
      }
    } catch (e) { debugPrint('[tmdb] $e'); }
    return null;
  }

  /// جلب YouTube key فقط للـ trailer (للتشغيل المضمّن)
  static Future<String?> getTrailerKey(int tmdbId, {bool isTv = false}) async {
    try {
      for (final lang in ['ar', 'en-US']) {
        final r = await _dio.get(
          '\$_base/\${isTv ? "tv" : "movie"}/\$tmdbId/videos',
          queryParameters: {'api_key': _key, 'language': lang},
        );
        final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
        if (results.isEmpty) continue;
        final trailer = results.firstWhere(
            (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
            orElse: () => results.firstWhere(
                (v) => v['site'] == 'YouTube', orElse: () => {}));
        final key = trailer['key']?.toString() ?? '';
        if (key.isNotEmpty) return key;
      }
    } catch (e) { debugPrint('[tmdb] $e'); }
    return null;
  }

  /// جلب trailer key من اسم المحتوى مباشرة (للبوسترات التي لا تحمل tmdb_id)
  static Future<String?> getTrailerKeyByName(String name, {bool isTv = false}) async {
    final cacheKey = 'tk_\${isTv ? "tv" : "mv"}_\$name';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!['trailer_key'];
    }
    try {
      final info = await search(name, isTv: isTv);
      final tmdbId = int.tryParse(info['tmdb_id'] ?? '');
      if (tmdbId == null) return null;
      final key = await getTrailerKey(tmdbId, isTv: isTv);
      if (key != null) {
        // cache it
        final cached = Map<String, String>.from(_cache['\${isTv ? "tv" : "mv"}_\$name'] ?? {});
        cached['trailer_key'] = key;
        _cache[cacheKey] = cached;
      }
      return key;
    } catch (e) { debugPrint('[tmdb] $e'); }
    return null;
  }


  static Future<Map<String, dynamic>> getFullDetails(int tmdbId, {bool isTv = false}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final futures = await Future.wait<Response<dynamic>>([
        _dio.get('$_base/$type/$tmdbId', queryParameters: {'api_key': _key, 'language': 'ar'}),
        _dio.get('$_base/$type/$tmdbId/images', queryParameters: {'api_key': _key}),
        _dio.get('$_base/$type/$tmdbId/credits', queryParameters: {'api_key': _key, 'language': 'ar'}),
        _dio.get('$_base/$type/$tmdbId/videos', queryParameters: {'api_key': _key}),
      ]);
      final details = futures[0].data as Map;
      final images  = futures[1].data as Map;
      final credits = futures[2].data as Map;
      final videos  = futures[3].data as Map;

      final posters = ((images['posters'] as List?)?.take(8) ?? [])
          .map((p) => poster(p['file_path']?.toString() ?? '', size: 'w500'))
          .where((p) => p.isNotEmpty).toList();

      final videoList  = (videos['results'] as List?)?.cast<Map>() ?? [];
      final trailerKey = videoList.firstWhere(
          (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
          orElse: () => videoList.firstWhere(
              (v) => v['site'] == 'YouTube', orElse: () => {}))['key']?.toString() ?? '';

      final castList = (credits['cast'] as List?)?.take(10).map((c) => {
        'id':           c['id'],
        'name':         c['name']?.toString() ?? '',
        'character':    c['character']?.toString() ?? '',
        'profile_path': c['profile_path'] != null ? thumb(c['profile_path'].toString()) : '',
      }).toList() ?? [];

      return {
        'id':           tmdbId,
        'title':        details['title'] ?? details['name'] ?? '',
        'overview':     details['overview'] ?? '',
        'poster':       poster(details['poster_path']?.toString() ?? ''),
        'backdrop':     backdrop(details['backdrop_path']?.toString() ?? ''),
        'posters':      posters,
        'rating':       (details['vote_average'] ?? 0.0).toStringAsFixed(1),
        'year':         (details['release_date'] ?? details['first_air_date'] ?? '')
            .toString().length >= 4
            ? (details['release_date'] ?? details['first_air_date'] ?? '')
                .toString().substring(0, 4)
            : '',
        'runtime':      details['runtime']?.toString() ?? '',
        'genres':       ((details['genres'] as List?)
            ?.map((g) => g['name']?.toString() ?? '').toList() ?? []).join('، '),
        'cast':         castList,
        'trailer_url':  trailerKey.isNotEmpty
            ? 'https://www.youtube.com/watch?v=$trailerKey' : '',
        'trailer_key':  trailerKey,
        'language':     details['original_language']?.toString() ?? '',
        'status':       details['status']?.toString() ?? '',
      };
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> getActorDetails(int actorId) async {
    try {
      final r = await _dio.get('$_base/person/$actorId', queryParameters: {
        'api_key': _key, 'language': 'ar',
        'append_to_response': 'movie_credits,tv_credits',
      });
      final data = r.data as Map<String, dynamic>;
      final movies = ((data['movie_credits']?['cast'] as List?) ?? [])
          .where((m) => (m['poster_path'] ?? '').toString().isNotEmpty)
          .take(30).map((m) => <String, dynamic>{
        'id': m['id'], 'title': m['title'] ?? '', 'type': 'movie',
        'poster':    '$_img/w342${m['poster_path']}',
        'backdrop':  m['backdrop_path'] != null ? '$_img/w780${m['backdrop_path']}' : '',
        'rating':    (m['vote_average'] ?? 0.0).toStringAsFixed(1),
        'year':      (m['release_date'] ?? '').toString().length >= 4
            ? m['release_date'].toString().substring(0, 4) : '',
        'overview':  m['overview'] ?? '',
        'character': m['character'] ?? '',
      }).toList();

      final tvShows = ((data['tv_credits']?['cast'] as List?) ?? [])
          .where((t) => (t['poster_path'] ?? '').toString().isNotEmpty)
          .take(20).map((t) => <String, dynamic>{
        'id': t['id'], 'title': t['name'] ?? '', 'type': 'tv',
        'poster':    '$_img/w342${t['poster_path']}',
        'backdrop':  t['backdrop_path'] != null ? '$_img/w780${t['backdrop_path']}' : '',
        'rating':    (t['vote_average'] ?? 0.0).toStringAsFixed(1),
        'year':      (t['first_air_date'] ?? '').toString().length >= 4
            ? t['first_air_date'].toString().substring(0, 4) : '',
        'overview':  t['overview'] ?? '',
        'character': t['character'] ?? '',
      }).toList();

      return {
        'id':                   actorId,
        'name':                 data['name'] ?? '',
        'biography':            data['biography'] ?? '',
        'birthday':             data['birthday'] ?? '',
        'place_of_birth':       data['place_of_birth'] ?? '',
        'profile_path':         data['profile_path'] != null
            ? '$_img/w342${data['profile_path']}' : '',
        'known_for_department': data['known_for_department'] ?? '',
        'movies':               movies,
        'tv_shows':             tvShows,
      };
    } catch (_) { return {}; }
  }

  static Future<List<Map<String, dynamic>>> smartSearch(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final r = await _dio.get('$_base/search/multi', queryParameters: {
        'api_key': _key, 'query': query, 'language': 'ar', 'include_adult': false,
      });
      final results = <Map<String, dynamic>>[];
      for (final item in (r.data['results'] as List? ?? []).take(20)) {
        final type = item['media_type']?.toString() ?? '';
        if (type == 'movie') {
          results.add({
            'tmdb_id': item['id'], 'type': 'movie',
            'title':    item['title'] ?? '', 'overview': item['overview'] ?? '',
            'poster':   item['poster_path'] != null ? '$_img/w342${item['poster_path']}' : '',
            'backdrop': item['backdrop_path'] != null ? '$_img/w780${item['backdrop_path']}' : '',
            'rating':   (item['vote_average'] ?? 0).toStringAsFixed(1),
            'year':     (item['release_date'] ?? '').toString().length >= 4
                ? item['release_date'].toString().substring(0, 4) : '',
          });
        } else if (type == 'tv') {
          results.add({
            'tmdb_id': item['id'], 'type': 'tv',
            'title':    item['name'] ?? '', 'overview': item['overview'] ?? '',
            'poster':   item['poster_path'] != null ? '$_img/w342${item['poster_path']}' : '',
            'backdrop': item['backdrop_path'] != null ? '$_img/w780${item['backdrop_path']}' : '',
            'rating':   (item['vote_average'] ?? 0).toStringAsFixed(1),
            'year':     (item['first_air_date'] ?? '').toString().length >= 4
                ? item['first_air_date'].toString().substring(0, 4) : '',
          });
        } else if (type == 'person') {
          results.add({
            'tmdb_id': item['id'], 'type': 'person',
            'title':    item['name'] ?? '',
            'overview': item['known_for_department'] ?? '',
            'poster':   item['profile_path'] != null ? '$_img/w185${item['profile_path']}' : '',
            'backdrop': '', 'rating': '', 'year': '',
          });
        }
      }
      return results;
    } catch (_) { return []; }
  }
}
