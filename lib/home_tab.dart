import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'core.dart';
import 'stats.dart';
import 'widgets.dart';
import 'player_ui.dart';

List<SongModel> _songsFor(Iterable<int> ids) {
  final byId = {for (final s in allSongs) s.id: s};
  return [for (final id in ids) if (byId[id] != null) byId[id]!];
}

String fmtHm(int sec) {
  if (sec <= 0) return '0د';
  if (sec < 60) return 'أقل من دقيقة';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  return h > 0 ? '$hس $mد' : '$mد';
}

class _Cover extends StatelessWidget {
  final int id;
  final double size;
  final double radius;
  const _Cover({required this.id, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final a = context.accent;
    return QueryArtworkWidget(
      id: id,
      type: ArtworkType.AUDIO,
      size: 300,
      quality: 80,
      artworkWidth: size,
      artworkHeight: size,
      artworkBorder: r,
      nullArtworkWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            colors: [a, Color.lerp(a, Colors.black, 0.5)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: size * 0.45),
      ),
    );
  }
}

// ---------- تبويب الرئيسية ----------
class SmartHome extends StatelessWidget {
  const SmartHome({super.key});

  String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'نهارك سعيد';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([stats, userLib, settings]),
      builder: (context, _) {
        if (allSongs.isEmpty) return const Center(child: Text('ما لقينا أغاني'));
        final recent = _songsFor(stats.recentIds(12));
        final top = _songsFor(stats.topIds(12));
        final added = (List<SongModel>.of(allSongs)
              ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0)))
            .take(12)
            .toList();
        final now = DateTime.now();
        final rnd = math.Random(now.day + now.month * 31);
        final fresh = allSongs.where((s) => !stats.plays.containsKey(s.id)).toList()
          ..shuffle(rnd);
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(_greet(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const _ContinueCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.shuffle, size: 18),
                    label: const Text('شغّل عشوائي'),
                    onPressed: () => playQueue(
                        allSongs, math.Random().nextInt(allSongs.length),
                        shuffle: true),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.insights, size: 18),
                    label: const Text('إحصائياتك'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const StatsPage())),
                  ),
                ],
              ),
            ),
            if (recent.isNotEmpty) _HList(title: 'شغّلتها مؤخرًا', songs: recent),
            if (top.isNotEmpty)
              _HList(
                title: 'الأكثر استماعًا',
                songs: top,
                sub: (s) => '${stats.plays[s.id] ?? 0} مرة',
              ),
            _HList(title: 'أضفتها حديثًا', songs: added),
            if (fresh.isNotEmpty)
              _HList(title: 'اكتشف من مكتبتك', songs: fresh.take(12).toList()),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'ابدأ الاستماع، وراح تظهر هنا أغانيك الأكثر استماعًا وإحصائياتك',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: player.currentIndexStream,
      builder: (context, snap) {
        final i = snap.data;
        if (i == null || i >= queue.length) return const SizedBox.shrink();
        final song = queue[i];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: context.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openPlayer(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _Cover(id: song.id, size: 72, radius: 14),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تابع الاستماع',
                              style: TextStyle(color: context.accent, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(artistOf(song),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                    const PlayPauseButton(size: 44),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HList extends StatelessWidget {
  final String title;
  final List<SongModel> songs;
  final String Function(SongModel)? sub;
  const _HList({required this.title, required this.songs, this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final s = songs[i];
              return GestureDetector(
                onTap: () => playQueue(songs, i),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Cover(id: s.id, size: 120, radius: 16),
                      const SizedBox(height: 8),
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(sub != null ? sub!(s) : artistOf(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------- صفحة الإحصائيات ----------
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  static const _dayNames = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('تصفير الإحصائيات؟'),
        content: const Text('راح تنمسح كل أرقام الاستماع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تصفير')),
        ],
      ),
    );
    if (ok == true) stats.reset();
  }

  Widget _stat(BuildContext c, IconData icon, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Icon(icon, color: c.accent),
              const SizedBox(height: 6),
              Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائياتك'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'تصفير الإحصائيات',
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: stats,
        builder: (context, _) {
          if (stats.totalSeconds == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ما في إحصائيات بعد.\nاسمع كم أغنية وراح تظهر هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          final byId = {for (final s in allSongs) s.id: s};
          final totalPlays = stats.plays.values.fold<int>(0, (a, b) => a + b);
          final week = stats.lastDays(7);
          final maxDay = week.fold<int>(0, (a, b) => math.max(a, b));
          final now = DateTime.now();
          final labels = [
            for (var i = 6; i >= 0; i--)
              _dayNames[now.subtract(Duration(days: i)).weekday - 1]
          ];
          final topSongs = _songsFor((stats.plays.keys.where((id) => byId.containsKey(id)).toList()
                ..sort((a, b) => (stats.plays[b] ?? 0).compareTo(stats.plays[a] ?? 0)))
              .take(5));
          final artistSecs = <String, int>{};
          stats.seconds.forEach((id, sec) {
            final s = byId[id];
            if (s != null) {
              final a = artistOf(s);
              if (a != unknownArtist) artistSecs[a] = (artistSecs[a] ?? 0) + sec;
            }
          });
          final artists = artistSecs.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topArtists = artists.take(5).toList();
          final maxArtist = topArtists.isEmpty ? 1 : topArtists.first.value;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _stat(context, Icons.timer_outlined, fmtHm(stats.totalSeconds), 'وقت الاستماع'),
                    _stat(context, Icons.play_circle_outline, '$totalPlays', 'مرة تشغيل'),
                    _stat(context, Icons.library_music_outlined, '${stats.seconds.length}',
                        'أغنية مختلفة'),
                  ],
                ),
              ),
              _title('آخر 7 أيام (بالدقائق)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(week[i] > 0 ? '${(week[i] / 60).round()}' : '',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: maxDay == 0 ? 4.0 : math.max(4.0, 100.0 * week[i] / maxDay),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: i == 6 ? context.accent : context.accent.withAlpha(110),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(labels[i],
                                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (topSongs.isNotEmpty) _title('أكثر أغانيك استماعًا'),
              for (var i = 0; i < topSongs.length; i++)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: SizedBox(
                    width: 84,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: context.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        _Cover(id: topSongs[i].id, size: 52, radius: 12),
                      ],
                    ),
                  ),
                  title: Text(topSongs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${stats.plays[topSongs[i].id] ?? 0} مرة • ${fmtHm(stats.seconds[topSongs[i].id] ?? 0)}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () => playQueue(topSongs, i),
                ),
              if (topArtists.isNotEmpty) _title('أكثر فنانيك استماعًا'),
              for (final e in topArtists)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text(fmtHm(e.value), style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: e.value / maxArtist,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          color: context.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
// ===== END home_tab =====