import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core.dart';

class PlayStats extends ChangeNotifier {
  Map<int, int> plays = {};
  Map<int, int> seconds = {};
  Map<int, int> lastPlayed = {};
  Map<String, int> days = {};
  int totalSeconds = 0;

  bool _started = false;
  int? _sessionId;
  int _sessionSecs = 0;
  bool _counted = false;
  int _ticks = 0;
  SharedPreferences? _p;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final p = await SharedPreferences.getInstance();
    _p = p;
    final raw = p.getString('stats');
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    notifyListeners();
    Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    player.playingStream.listen((playing) {
      if (!playing) {
        _save();
        notifyListeners();
      }
    });
  }

  Map<int, int> _intMap(dynamic v) => {
        for (final e in ((v as Map?) ?? {}).entries)
          int.parse(e.key.toString()): (e.value as num).toInt()
      };

  void _fromJson(Map<String, dynamic> m) {
    plays = _intMap(m['plays']);
    seconds = _intMap(m['sec']);
    lastPlayed = _intMap(m['last']);
    days = {
      for (final e in ((m['days'] as Map?) ?? {}).entries)
        e.key.toString(): (e.value as num).toInt()
    };
    totalSeconds = (m['total'] as num?)?.toInt() ?? 0;
  }

  void _save() {
    _p?.setString(
      'stats',
      jsonEncode({
        'plays': plays.map((k, v) => MapEntry(k.toString(), v)),
        'sec': seconds.map((k, v) => MapEntry(k.toString(), v)),
        'last': lastPlayed.map((k, v) => MapEntry(k.toString(), v)),
        'days': days,
        'total': totalSeconds,
      }),
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _tick() {
    if (!player.playing || player.processingState != ProcessingState.ready) return;
    final i = player.currentIndex;
    if (i == null || i >= queue.length) return;
    final id = queue[i].id;
    if (_sessionId != id) {
      _sessionId = id;
      _sessionSecs = 0;
      _counted = false;
    }
    _sessionSecs += 5;
    seconds[id] = (seconds[id] ?? 0) + 5;
    totalSeconds += 5;
    final now = DateTime.now();
    final k = _dayKey(now);
    days[k] = (days[k] ?? 0) + 5;
    lastPlayed[id] = now.millisecondsSinceEpoch;
    var changed = false;
    if (!_counted && _sessionSecs >= 20) {
      plays[id] = (plays[id] ?? 0) + 1;
      _counted = true;
      changed = true;
    }
    _ticks++;
    if (_ticks % 6 == 0 || changed) {
      final cutoff = _dayKey(now.subtract(const Duration(days: 90)));
      days.removeWhere((key, _) => key.compareTo(cutoff) < 0);
      _save();
      notifyListeners();
    }
  }

  List<int> recentIds(int n) {
    final ids = lastPlayed.keys.toList()
      ..sort((a, b) => (lastPlayed[b] ?? 0).compareTo(lastPlayed[a] ?? 0));
    return ids.take(n).toList();
  }

  List<int> topIds(int n) {
    final ids = plays.keys.where((id) => (plays[id] ?? 0) > 0).toList()
      ..sort((a, b) => (plays[b] ?? 0).compareTo(plays[a] ?? 0));
    return ids.take(n).toList();
  }

  /// ثواني الاستماع لآخر n يوم (الأقدم أول، واليوم آخر عنصر)
  List<int> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--) days[_dayKey(now.subtract(Duration(days: i)))] ?? 0
    ];
  }

  void reset() {
    plays = {};
    seconds = {};
    lastPlayed = {};
    days = {};
    totalSeconds = 0;
    _save();
    notifyListeners();
  }
}

final stats = PlayStats();
// ===== END stats =====