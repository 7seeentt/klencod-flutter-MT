import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_config.dart';
import 'core.dart';

int _fnv(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

int syntheticId(String key) => -((_fnv(key) % 2000000000) + 1);

/// مفتاح ثابت للأغنية (يتشابه بين الأجهزة): اسم الملف + المدة
String songKey(SongModel s) {
  String n;
  try {
    n = s.displayNameWOExt;
  } catch (_) {
    n = s.title;
  }
  n = n.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return '$n|${((s.duration ?? 0) / 1000).round()}';
}

String fmtBytes(int b) {
  if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} GB';
  if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
  return '${(b / 1024).round()} KB';
}

String _contentType(String ext) {
  switch (ext) {
    case 'm4a':
    case 'mp4':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'wav':
      return 'audio/wav';
    default:
      return 'audio/mpeg';
  }
}

String _msg(Object e) {
  try {
    return (e as dynamic).message.toString();
  } catch (_) {
    return e.toString();
  }
}

String _authMsg(Object e) {
  final m = _msg(e).toLowerCase();
  if (m.contains('invalid login')) return 'الإيميل أو كلمة السر غلط';
  if (m.contains('already registered') || m.contains('already been registered')) {
    return 'هذا الإيميل مسجّل من قبل، سجّل دخول';
  }
  if (m.contains('at least')) return 'كلمة السر لازم 6 أحرف على الأقل';
  if (m.contains('not confirmed')) return 'لازم تأكّد إيميلك أول (افتح رسالة التأكيد)';
  if (m.contains('rate limit')) return 'محاولات كثيرة، انتظر شوي وجرّب';
  if (m.contains('socket') || m.contains('network') || m.contains('failed host')) {
    return 'ما في اتصال بالإنترنت';
  }
  return _msg(e);
}

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

class CloudSong {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int sizeBytes;
  final String path;
  final String key;
  final String fileName;
  final int createdSec;

  CloudSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.path,
    required this.key,
    required this.fileName,
    required this.createdSec,
  });

  factory CloudSong.fromRow(Map<String, dynamic> r) {
    final created = DateTime.tryParse((r['created_at'] ?? '') as String);
    return CloudSong(
      id: r['id'] as String,
      title: (r['title'] ?? '') as String,
      artist: r['artist'] as String?,
      album: r['album'] as String?,
      durationMs: (r['duration_ms'] as num?)?.toInt() ?? 0,
      sizeBytes: (r['size_bytes'] as num?)?.toInt() ?? 0,
      path: r['path'] as String,
      key: (r['song_key'] ?? '') as String,
      fileName: (r['file_name'] ?? '') as String,
      createdSec: (created?.millisecondsSinceEpoch ?? 0) ~/ 1000,
    );
  }

  int get synthId => syntheticId(key.isEmpty ? path : key);
  String get localName => path.split('/').last;
  String get ext {
    final i = path.lastIndexOf('.');
    return i < 0 ? 'mp3' : path.substring(i + 1);
  }
}

class CloudService extends ChangeNotifier {
  bool configured = false;
  String? initError;
  List<CloudSong> songs = [];
  final Map<String, String> _urls = {};
  Set<String> _downloaded = {};
  String _dirPath = '';
  Map<int, String> _keyBySynth = {};
  final ValueNotifier<int> library = ValueNotifier<int>(0);

  bool busy = false;
  bool cancelRequested = false;
  int done = 0;
  int total = 0;
  int failed = 0;
  int _extraUsed = 0;
  String current = '';
  String mode = '';
  String? lastError;
  DateTime? lastSync;

  bool _mergeDone = false;
  bool _syncing = false;
  bool _wired = false;
  Map<String, dynamic> _remote = {};
  Timer? _debounce;

  SupabaseClient get _sb => Supabase.instance.client;
  User? get user => configured ? _sb.auth.currentUser : null;
  bool get signedIn => user != null;
  int get usedBytes => songs.fold<int>(0, (a, c) => a + c.sizeBytes);
  int get quotaBytes => cloudQuotaMb * 1024 * 1024;

  // ---------- التهيئة ----------
  Future<void> init() async {
    if (supabaseUrl.contains('YOUR-PROJECT') || supabaseKey.contains('YOUR-PUBLISHABLE')) {
      return;
    }
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      configured = true;
      _sb.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          startupSync();
        } else if (data.event == AuthChangeEvent.signedOut) {
          _afterLogout();
        }
        notifyListeners();
      });
      if (!_wired) {
        _wired = true;
        userLib.addListener(_schedulePush);
        settings.addListener(_schedulePush);
      }
      await _loadDownloaded();
    } catch (e) {
      initError = _msg(e);
    }
    notifyListeners();
  }

  // ---------- الحساب ----------
  Future<String?> signIn(String email, String pw) async {
    try {
      await _sb.auth.signInWithPassword(email: email.trim(), password: pw);
      return null;
    } catch (e) {
      return _authMsg(e);
    }
  }

  /// يرجع null عند النجاح، أو 'confirm' إذا لازم تأكيد الإيميل
  Future<String?> signUp(String email, String pw) async {
    try {
      final r = await _sb.auth.signUp(email: email.trim(), password: pw);
      if (r.session == null) return 'confirm';
      return null;
    } catch (e) {
      return _authMsg(e);
    }
  }

  Future<void> signOut() async {
    await _sb.auth.signOut();
  }

  void _afterLogout() {
    songs = [];
    _urls.clear();
    _keyBySynth = {};
    _remote = {};
    _mergeDone = false;
    lastSync = null;
    library.value++;
    notifyListeners();
  }

  // ---------- قائمة السحابة ----------
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/cloud');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> _loadDownloaded() async {
    try {
      final d = await _dir();
      _dirPath = d.path;
      _downloaded = {
        for (final f in d.listSync())
          if (f is File) f.path.split('/').last
      };
    } catch (_) {}
  }

  Future<void> _signUrls() async {
    _urls.clear();
    final need = [
      for (final c in songs)
        if (!_downloaded.contains(c.localName)) c.path
    ];
    for (var i = 0; i < need.length; i += 80) {
      final chunk = need.sublist(i, math.min(i + 80, need.length));
      try {
        final res = await _sb.storage.from('songs').createSignedUrls(chunk, 604800);
        for (final r in res) {
          _urls[r.path ?? ''] = r.signedUrl ?? '';
        }
      } catch (_) {}
    }
  }

  Future<void> refresh() async {
    if (!signedIn) return;
    try {
      final rows = await _sb.from('cloud_songs').select().order('created_at');
      songs = [for (final r in rows) CloudSong.fromRow(Map<String, dynamic>.from(r))];
      _keyBySynth = {for (final c in songs) c.synthId: c.key};
      await _loadDownloaded();
      await _signUrls();
      lastError = null;
    } catch (e) {
      lastError = _msg(e);
    }
    library.value++;
    notifyListeners();
  }

  bool isDownloaded(CloudSong c) => _downloaded.contains(c.localName);

  String? playUri(CloudSong c) {
    if (_downloaded.contains(c.localName)) {
      return Uri.file('$_dirPath/${c.localName}').toString();
    }
    final u = _urls[c.path];
    return (u == null || u.isEmpty) ? null : u;
  }

  SongModel _model(CloudSong c, String uri) {
    final a = (c.artist == null || c.artist!.isEmpty) ? '<unknown>' : c.artist;
    final base = c.fileName.isEmpty ? c.title : c.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return SongModel({
      '_id': c.synthId,
      '_uri': uri,
      '_data': uri,
      '_display_name': c.fileName.isEmpty ? c.title : c.fileName,
      '_display_name_wo_ext': base,
      '_size': c.sizeBytes,
      'title': c.title,
      'artist': a,
      'album': c.album,
      'album_id': null,
      'artist_id': null,
      'genre': null,
      'genre_id': null,
      'bookmark': null,
      'composer': null,
      'date_added': c.createdSec,
      'date_modified': c.createdSec,
      'duration': c.durationMs,
      'track': null,
      'file_extension': c.ext,
      'is_alarm': false,
      'is_audiobook': false,
      'is_music': true,
      'is_notification': false,
      'is_podcast': false,
      'is_ringtone': false,
    });
  }

  /// أغاني السحابة اللي مو موجودة محليًا (تنضاف للمكتبة)
  List<SongModel> extraSongs(Set<String> localKeys) {
    final out = <SongModel>[];
    for (final c in songs) {
      if (localKeys.contains(c.key)) continue;
      final u = playUri(c);
      if (u != null) out.add(_model(c, u));
    }
    return out;
  }

  /// كل أغاني السحابة القابلة للتشغيل
  List<SongModel> cloudModels() {
    final out = <SongModel>[];
    for (final c in songs) {
      final u = playUri(c);
      if (u != null) out.add(_model(c, u));
    }
    return out;
  }

  String keyOfSong(SongModel s) =>
      s.id < 0 ? (_keyBySynth[s.id] ?? songKey(s)) : songKey(s);

  // ---------- الرفع ----------
  Future<void> uploadSongs(List<SongModel> list) async {
    final uid = user?.id;
    if (uid == null || busy) return;
    busy = true;
    cancelRequested = false;
    mode = 'upload';
    done = 0;
    total = list.length;
    failed = 0;
    _extraUsed = 0;
    lastError = null;
    notifyListeners();
    for (final s in list) {
      if (cancelRequested) break;
      current = s.title;
      notifyListeners();
      try {
        final file = File(s.data);
        if (!await file.exists()) throw Exception('الملف غير موجود على الجهاز');
        final size = await file.length();
        if (size > 50 * 1024 * 1024) throw Exception('الملف أكبر من 50MB');
        if (usedBytes + _extraUsed + size > quotaBytes) throw Exception('المساحة ما تكفي');
        final key = keyOfSong(s);
        var ext = s.data.contains('.') ? s.data.split('.').last.toLowerCase() : 'mp3';
        if (ext.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) ext = 'mp3';
        final path = '$uid/${_fnv(key).toRadixString(16)}_${_fnv('$key#').toRadixString(16)}.$ext';
        await _sb.storage.from('songs').upload(
              path,
              file,
              fileOptions: FileOptions(contentType: _contentType(ext), upsert: true),
            );
        final a = artistOf(s);
        await _sb.from('cloud_songs').upsert({
          'user_id': uid,
          'title': s.title,
          'artist': a == unknownArtist ? null : a,
          'album': s.album,
          'duration_ms': s.duration ?? 0,
          'size_bytes': size,
          'path': path,
          'song_key': key,
          'file_name': s.displayName,
        }, onConflict: 'user_id,path');
        _extraUsed += size;
      } catch (e) {
        failed++;
        lastError = '${s.title}: ${_msg(e)}';
      }
      done++;
      notifyListeners();
    }
    busy = false;
    await refresh();
    _extraUsed = 0;
    notifyListeners();
  }

  void cancelJob() {
    cancelRequested = true;
    notifyListeners();
  }

  // ---------- التنزيل والحذف ----------
  Future<void> download(List<CloudSong> list) async {
    if (busy) return;
    busy = true;
    cancelRequested = false;
    mode = 'download';
    done = 0;
    total = list.length;
    failed = 0;
    lastError = null;
    notifyListeners();
    final d = await _dir();
    for (final c in list) {
      if (cancelRequested) break;
      current = c.title;
      notifyListeners();
      try {
        if (!_downloaded.contains(c.localName)) {
          final bytes = await _sb.storage.from('songs').download(c.path);
          await File('${d.path}/${c.localName}').writeAsBytes(bytes, flush: true);
          _downloaded.add(c.localName);
        }
      } catch (e) {
        failed++;
        lastError = '${c.title}: ${_msg(e)}';
      }
      done++;
      notifyListeners();
    }
    busy = false;
    await _signUrls();
    library.value++;
    notifyListeners();
  }

  Future<void> removeLocalCopy(CloudSong c) async {
    try {
      final f = File('$_dirPath/${c.localName}');
      if (await f.exists()) await f.delete();
      _downloaded.remove(c.localName);
      await _signUrls();
    } catch (_) {}
    library.value++;
    notifyListeners();
  }

  Future<void> deleteFromCloud(CloudSong c) async {
    try {
      await _sb.storage.from('songs').remove([c.path]);
      await _sb.from('cloud_songs').delete().eq('id', c.id);
      await removeLocalCopy(c);
      songs.removeWhere((x) => x.id == c.id);
      lastError = null;
    } catch (e) {
      lastError = _msg(e);
    }
    library.value++;
    notifyListeners();
  }

  // ---------- مزامنة البيانات ----------
  Map<String, int> _idByKey() {
    final m = <String, int>{};
    for (final c in songs) {
      m[c.key] = c.synthId;
    }
    for (final s in allSongs) {
      if (s.id > 0) m[songKey(s)] = s.id;
    }
    return m;
  }

  Map<String, dynamic> buildPayload() {
    final known = _idByKey().keys.toSet();
    final byId = {for (final s in allSongs) s.id: s};
    String? keyOf(int id) {
      final s = byId[id];
      return s == null ? null : keyOfSong(s);
    }

    final fav = <String>{};
    for (final id in userLib.favorites) {
      final k = keyOf(id);
      if (k != null) fav.add(k);
    }
    for (final k in _strList(_remote['fav'])) {
      if (!known.contains(k)) fav.add(k);
    }

    final pls = <String, List<String>>{};
    for (final e in userLib.playlists.entries) {
      final l = <String>[];
      for (final id in e.value) {
        final k = keyOf(id);
        if (k != null) l.add(k);
      }
      pls[e.key] = l;
    }
    final rp = _remote['playlists'];
    if (rp is Map) {
      for (final e in rp.entries) {
        final extra = [
          for (final k in _strList(e.value))
            if (!known.contains(k)) k
        ];
        if (extra.isEmpty) continue;
        final l = pls.putIfAbsent(e.key.toString(), () => <String>[]);
        for (final k in extra) {
          if (!l.contains(k)) l.add(k);
        }
      }
    }

    final ov = <String, Map<String, String>>{};
    for (final s in allSongs) {
      if (s.id > 0 && hasOverride(s.id)) {
        final a = artistOf(s);
        ov[songKey(s)] = {'t': s.title, 'a': a == unknownArtist ? '' : a};
      }
    }
    final ro = _remote['overrides'];
    if (ro is Map) {
      for (final e in ro.entries) {
        final k = e.key.toString();
        if (!known.contains(k) && e.value is Map) {
          final v = e.value as Map;
          ov[k] = {'t': (v['t'] ?? '').toString(), 'a': (v['a'] ?? '').toString()};
        }
      }
    }
    return {
      'v': 1,
      'fav': fav.toList(),
      'playlists': pls,
      'overrides': ov,
      'settings': settings.toMap(),
    };
  }

  Future<void> _applyRemote(Map<String, dynamic> d) async {
    final idx = _idByKey();
    final fresh = userLib.favorites.isEmpty &&
        userLib.playlists.isEmpty &&
        !allSongs.any((s) => s.id > 0 && hasOverride(s.id));
    final fav = <int>{...userLib.favorites};
    for (final k in _strList(d['fav'])) {
      final id = idx[k];
      if (id != null) fav.add(id);
    }
    final pls = <String, List<int>>{
      for (final e in userLib.playlists.entries) e.key: List<int>.of(e.value)
    };
    final rp = d['playlists'];
    if (rp is Map) {
      for (final e in rp.entries) {
        final l = pls.putIfAbsent(e.key.toString(), () => <int>[]);
        for (final k in _strList(e.value)) {
          final id = idx[k];
          if (id != null && !l.contains(id)) l.add(id);
        }
      }
    }
    userLib.fromMap({'fav': fav.toList(), 'playlists': pls});
    final ro = d['overrides'];
    if (ro is Map) {
      for (final e in ro.entries) {
        final id = idx[e.key.toString()];
        if (id != null && id > 0 && !hasOverride(id) && e.value is Map) {
          final v = e.value as Map;
          await setOverride(id, (v['t'] ?? '').toString(), (v['a'] ?? '').toString());
        }
      }
    }
    if (fresh && d['settings'] is Map) {
      settings.fromMap(Map<String, dynamic>.from(d['settings'] as Map));
    }
  }

  Future<void> pushNow() async {
    final uid = user?.id;
    if (uid == null || !_mergeDone) return;
    try {
      await _sb.from('user_data').upsert({
        'user_id': uid,
        'data': buildPayload(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      lastSync = DateTime.now();
      lastError = null;
    } catch (e) {
      lastError = _msg(e);
    }
    notifyListeners();
  }

  void _schedulePush() {
    if (!signedIn || !_mergeDone) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 6), pushNow);
  }

  /// تحديث السحابة ثم دمج بيانات الحساب مع بيانات الجهاز ثم رفع النتيجة
  Future<void> startupSync() async {
    final uid = user?.id;
    if (uid == null || _syncing) return;
    _syncing = true;
    try {
      await refresh();
      final row = await _sb.from('user_data').select().eq('user_id', uid).maybeSingle();
      if (row != null && row['data'] is Map) {
        _remote = Map<String, dynamic>.from(row['data'] as Map);
        await _applyRemote(_remote);
      }
      _mergeDone = true;
      await pushNow();
    } catch (e) {
      lastError = _msg(e);
      notifyListeners();
    }
    _syncing = false;
  }
}

final cloud = CloudService();
// ===== END cloud =====