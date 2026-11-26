import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';
import 'lyrics.dart';
import 'widgets.dart';
import 'cloud.dart';
import 'cloud_pages.dart';
import 'brand.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _section(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
        child: Text(t, style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: Colors.transparent),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            _section(context, 'الحساب'),
            ListenableBuilder(
              listenable: cloud,
              builder: (context, _) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.accent.withAlpha(50),
                  child: Icon(cloud.signedIn ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                      color: context.accent),
                ),
                title: Text(cloud.signedIn ? (cloud.user?.email ?? 'حسابي') : 'تسجيل الدخول'),
                subtitle: Text(cloud.signedIn ? 'المزامنة والسحابة' : 'احفظ مكتبتك بحسابك'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CloudPage())),
              ),
            ),
            _section(context, 'المظهر'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لون التطبيق'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < accents.length; i++)
                        GestureDetector(
                          onTap: () => settings.update(() => settings.accentIndex = i),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: accents[i],
                            child: i == settings.accentIndex
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('خلفية سوداء (AMOLED)'),
              subtitle: const Text('توفّر البطارية على شاشات AMOLED'),
              value: settings.amoled,
              onChanged: (v) => settings.update(() => settings.amoled = v),
            ),
            SwitchListTile(
              title: const Text('ألوان من غلاف الأغنية'),
              subtitle: const Text('تتغير ألوان شاشة التشغيل حسب الغلاف'),
              value: settings.dynamicColors,
              onChanged: (v) => settings.update(() => settings.dynamicColors = v),
            ),
            SwitchListTile(
              title: const Text('خلفية ضبابية'),
              subtitle: const Text('صورة الغلاف كخلفية ضبابية بشاشة التشغيل'),
              value: settings.blurBg,
              onChanged: (v) => settings.update(() => settings.blurBg = v),
            ),
            _section(context, 'المكتبة'),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('إصلاح أسماء الأغاني'),
              subtitle: const Text('عدّل الأسماء غير الواضحة'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FixNamesPage())),
            ),
            ListTile(
              title: const Text('ترتيب الأغاني'),
              trailing: DropdownButton<int>(
                value: settings.sortIndex,
                dropdownColor: context.card,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('الاسم')),
                  DropdownMenuItem(value: 1, child: Text('الفنان')),
                  DropdownMenuItem(value: 2, child: Text('الأحدث إضافة')),
                  DropdownMenuItem(value: 3, child: Text('المدة')),
                ],
                onChanged: (v) {
                  if (v != null) settings.update(() => settings.sortIndex = v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(settings.minSeconds == 0
                  ? 'إظهار كل المقاطع'
                  : 'إخفاء المقاطع الأقصر من ${settings.minSeconds} ثانية'),
            ),
            Slider(
              value: settings.minSeconds.toDouble(),
              min: 0,
              max: 120,
              divisions: 12,
              label: '${settings.minSeconds}',
              onChanged: (v) => settings.update(() => settings.minSeconds = v.round()),
            ),
            _section(context, 'الكلمات والبيانات'),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('مسح كاش الكلمات'),
              subtitle: const Text('امسحها إذا كانت كلمات غلط انحفظت قبل'),
              onTap: () async {
                await clearLyricsCache();
                if (context.mounted) toast(context, 'تم مسح الكلمات المحفوظة');
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('نسخ احتياطي'),
              subtitle: const Text('ينسخ المفضلة والقوائم والإعدادات للحافظة'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: backupJson()));
                if (context.mounted) toast(context, 'تم النسخ، الصقه بأي مكان تحفظه فيه');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('استعادة من الحافظة'),
              subtitle: const Text('انسخ النسخة الاحتياطية أول ثم اضغط هنا'),
              onTap: () async {
                final d = await Clipboard.getData(Clipboard.kTextPlain);
                final ok = restoreBackup(d?.text ?? '');
                if (context.mounted) {
                  toast(context, ok ? 'تمت الاستعادة' : 'الحافظة ما فيها نسخة صحيحة');
                }
              },
            ),
            _section(context, 'حول'),
            const ListTile(
              leading: BrandMark(size: 40),
              title: Text('MT — Music Time'),
              subtitle: Text('الإصدار 4.0'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- صفحة إصلاح الأسماء ----------
class FixNamesPage extends StatefulWidget {
  const FixNamesPage({super.key});
  @override
  State<FixNamesPage> createState() => _FixNamesPageState();
}

class _FixNamesPageState extends State<FixNamesPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _q.text.trim().toLowerCase();
    final list = allSongs
        .where((s) =>
            t.isEmpty ||
            s.title.toLowerCase().contains(t) ||
            artistOf(s).toLowerCase().contains(t))
        .toList();
    list.sort((a, b) {
      final ga = looksGarbled(a.title) ? 0 : 1;
      final gb = looksGarbled(b.title) ? 0 : 1;
      return ga != gb ? ga.compareTo(gb) : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    final bad = allSongs.where((s) => looksGarbled(s.title)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('إصلاح أسماء الأغاني'), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bad == 0
                    ? 'كل الأسماء تبدو واضحة'
                    : '$bad أغنية بأسماء غير واضحة (تظهر أول القائمة)',
                style: TextStyle(color: bad == 0 ? Colors.white54 : Colors.amber),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemExtent: 72,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                final isBad = looksGarbled(s.title);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Art(id: s.id, size: 48, radius: 10),
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${artistOf(s)}${hasOverride(s.id) ? ' • معدّلة' : ''}',
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Icon(
                    isBad ? Icons.warning_amber_rounded : Icons.edit_outlined,
                    color: isBad ? Colors.amber : Colors.white38,
                  ),
                  onTap: () async {
                    await editSongInfo(context, s);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// ===== END settings =====