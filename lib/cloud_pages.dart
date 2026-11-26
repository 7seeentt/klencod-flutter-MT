import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, OtpType, UserAttributes;
import 'core.dart';
import 'cloud.dart';
import 'widgets.dart';
import 'player_ui.dart';
import 'brand.dart';

String _ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'الحين';
  if (m < 60) return 'قبل $m دقيقة';
  final h = m ~/ 60;
  if (h < 24) return 'قبل $h ساعة';
  return 'قبل ${h ~/ 24} يوم';
}

String _errText(Object e) {
  String m;
  try {
    m = (e as dynamic).message.toString();
  } catch (_) {
    m = e.toString();
  }
  final l = m.toLowerCase();
  if (l.contains('invalid') && (l.contains('token') || l.contains('otp'))) {
    return 'الرمز غلط أو انتهت صلاحيته';
  }
  if (l.contains('rate limit') || l.contains('too many')) {
    return 'محاولات كثيرة، انتظر شوي وجرّب';
  }
  if (l.contains('socket') || l.contains('network') || l.contains('failed host')) {
    return 'ما في اتصال بالإنترنت';
  }
  if (l.contains('same password') || l.contains('different from the old')) {
    return 'اختر كلمة سر مختلفة عن القديمة';
  }
  return m;
}

Future<String?> _sendReset(String email) async {
  try {
    await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
    return null;
  } catch (e) {
    return _errText(e);
  }
}

Future<String?> _confirmReset(String email, String code, String newPw) async {
  try {
    final c = Supabase.instance.client;
    await c.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.recovery);
    await c.auth.updateUser(UserAttributes(password: newPw));
    return null;
  } catch (e) {
    return _errText(e);
  }
}

InputDecoration _dec(BuildContext c, String label, IconData icon, {Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: c.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

// ---------- شاشة الدخول / إنشاء الحساب ----------
class AuthScreen extends StatefulWidget {
  final bool gate;
  final VoidCallback? onDone;
  const AuthScreen({super.key, this.gate = false, this.onDone});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;
  String? _err;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.gate) {
      // نعيد المزامنة بعد ما تتحمل المكتبة عشان تنربط المفضلة بالأغاني
      Future.delayed(const Duration(seconds: 6), cloud.startupSync);
      Future.delayed(const Duration(seconds: 15), cloud.startupSync);
      widget.onDone?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final e = _email.text.trim();
    final p = _pw.text;
    if (!e.contains('@') || p.length < 6) {
      setState(() => _err = 'اكتب إيميل صحيح وكلمة سر 6 أحرف على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _info = null;
    });
    final r = _signup ? await cloud.signUp(e, p) : await cloud.signIn(e, p);
    if (!mounted) return;
    if (r == null) {
      _finish();
      return;
    }
    setState(() {
      _busy = false;
      if (r == 'confirm') {
        _info = 'تم إنشاء الحساب. افتح إيميلك واضغط رابط التأكيد، وبعدها سجّل دخول.';
        _signup = false;
      } else {
        _err = r;
      }
    });
  }

  Future<void> _skip() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('guest', true);
    widget.onDone?.call();
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetDialog(email: _email.text.trim()),
    );
    if (ok == true && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [brandColor.withAlpha(60), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (!widget.gate)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandMark(size: 92),
                          const SizedBox(height: 18),
                          const Text('MT',
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6)),
                          const Text('MUSIC TIME',
                              style: TextStyle(
                                  fontSize: 11, letterSpacing: 4, color: Colors.white54)),
                          const SizedBox(height: 30),
                          Text(_signup ? 'إنشاء حساب جديد' : 'أهلًا بيك',
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('مفضلتك وقوائمك وأغانيك تنحفظ بحسابك',
                              style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: _dec(context, 'الإيميل', Icons.email_outlined),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pw,
                            obscureText: _hide,
                            onSubmitted: (_) => _submit(),
                            decoration: _dec(
                              context,
                              'كلمة السر',
                              Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _hide = !_hide),
                              ),
                            ),
                          ),
                          if (_err != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_err!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent)),
                            ),
                          if (_info != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_info!, textAlign: TextAlign.center),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: brandColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white))
                                  : Text(_signup ? 'إنشاء الحساب' : 'دخول',
                                      style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!_signup)
                            TextButton(
                              onPressed: _forgot,
                              child: const Text('نسيت كلمة السر؟',
                                  style: TextStyle(color: Colors.white60)),
                            ),
                          TextButton(
                            onPressed: () => setState(() {
                              _signup = !_signup;
                              _err = null;
                              _info = null;
                            }),
                            child: Text(_signup ? 'عندي حساب، سجّل دخول' : 'ما عندي حساب، أنشئ حساب'),
                          ),
                          if (widget.gate)
                            TextButton(
                              onPressed: _skip,
                              child: const Text('المتابعة بدون حساب',
                                  style: TextStyle(color: Colors.white38)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- نافذة استعادة كلمة السر ----------
class _ResetDialog extends StatefulWidget {
  final String email;
  const _ResetDialog({required this.email});
  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  late final TextEditingController _e = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _pw = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _e.dispose();
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_e.text.contains('@')) {
      setState(() => _err = 'اكتب إيميل صحيح');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await _sendReset(_e.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r == null) {
        _step = 1;
      } else {
        _err = r;
      }
    });
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length < 6 || _pw.text.length < 6) {
      setState(() => _err = 'اكتب الرمز اللي وصلك وكلمة سر جديدة 6 أحرف على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await _confirmReset(_e.text, _code.text, _pw.text);
    if (!mounted) return;
    if (r == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _err = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      title: const Text('استعادة كلمة السر'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_step == 0) ...[
              const Text('اكتب إيميلك وراح نرسل لك رمز.',
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 12),
              TextField(
                controller: _e,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'الإيميل'),
              ),
            ] else ...[
              Text('أرسلنا رمز إلى ${_e.text}',
                  style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الرمز'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة السر الجديدة'),
              ),
            ],
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _busy ? null : (_step == 0 ? _send : _confirm),
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_step == 0 ? 'إرسال الرمز' : 'تأكيد'),
        ),
      ],
    );
  }
}

// ---------- صفحة الحساب والسحابة ----------
class CloudPage extends StatelessWidget {
  const CloudPage({super.key});

  Future<void> _confirm(BuildContext context, String title, String yes, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        ],
      ),
    );
    if (ok == true) onYes();
  }

  Widget _card(BuildContext c, Widget child) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  Widget _notConfigured(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_suggest_outlined, size: 56, color: Colors.white38),
              const SizedBox(height: 12),
              const Text(
                'السحابة ما انضبطت بعد.\nافتح الملف lib/cloud_config.dart وحط Project URL و Publishable key من Supabase، وابنِ التطبيق من جديد.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.7),
              ),
              if (cloud.initError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(cloud.initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
      );

  Widget _signedOut(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 84),
              const SizedBox(height: 20),
              const Text('احفظ مكتبتك بحسابك',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                'سجّل دخول عشان تنحفظ مفضلتك وقوائمك وأسماء أغانيك، وترفع أغانيك للسحابة، وترجع لك كلها لو مسحت التطبيق أو غيّرت الجوال.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.7),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: brandColor, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                icon: const Icon(Icons.login),
                label: const Text('تسجيل الدخول / حساب جديد'),
              ),
            ],
          ),
        ),
      );

  Widget _songTile(BuildContext context, CloudSong c) {
    final down = cloud.isDownloaded(c);
    final artist = (c.artist == null || c.artist!.isEmpty) ? unknownArtist : c.artist!;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 4),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.accent.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(down ? Icons.download_done_rounded : Icons.cloud_queue_rounded,
            color: context.accent),
      ),
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$artist • ${fmtBytes(c.sizeBytes)}${down ? ' • على الجهاز' : ''}',
          maxLines: 1, style: const TextStyle(color: Colors.white54)),
      onTap: () {
        final models = cloud.cloudModels();
        final i = models.indexWhere((m) => m.id == c.synthId);
        if (i < 0) {
          toast(context, 'ما في رابط تشغيل، اضغط مزامنة الآن');
          return;
        }
        playQueue(models, i);
      },
      trailing: PopupMenuButton<String>(
        color: context.card,
        onSelected: (v) {
          if (v == 'dl') cloud.download([c]);
          if (v == 'rm') cloud.removeLocalCopy(c);
          if (v == 'del') {
            _confirm(context, 'حذف "${c.title}" من السحابة؟', 'حذف', () => cloud.deleteFromCloud(c));
          }
        },
        itemBuilder: (_) => [
          if (!down) const PopupMenuItem(value: 'dl', child: Text('تنزيل للجهاز')),
          if (down) const PopupMenuItem(value: 'rm', child: Text('حذف النسخة من الجهاز')),
          const PopupMenuItem(value: 'del', child: Text('حذف من السحابة')),
        ],
      ),
    );
  }

  Widget _signedIn(BuildContext context) {
    final u = cloud.user!;
    final used = cloud.usedBytes;
    final frac = cloud.quotaBytes == 0 ? 0.0 : (used / cloud.quotaBytes).clamp(0.0, 1.0).toDouble();
    final pending = cloud.songs.where((c) => !cloud.isDownloaded(c)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          context,
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.accent.withAlpha(60),
                child: Text((u.email ?? '?').substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      cloud.lastSync == null
                          ? 'لم تتم مزامنة بعد'
                          : 'آخر مزامنة: ${_ago(cloud.lastSync!)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _confirm(context, 'تسجيل الخروج؟', 'خروج', cloud.signOut),
                child: const Text('خروج'),
              ),
            ],
          ),
        ),
        _card(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('المساحة', style: TextStyle(fontWeight: FontWeight.bold))),
                  Text('${(frac * 100).round()}%', style: const TextStyle(color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  color: frac > 0.9 ? Colors.redAccent : context.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${fmtBytes(used)} من ${fmtBytes(cloud.quotaBytes)} • ${cloud.songs.length} أغنية',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        if (cloud.busy)
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cloud.mode == 'upload' ? 'جاري الرفع...' : 'جاري التنزيل...',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(cloud.current,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: cloud.total == 0 ? null : cloud.done / cloud.total,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  color: context.accent,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cloud.done} / ${cloud.total}${cloud.failed > 0 ? ' • فشل ${cloud.failed}' : ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: cloud.cancelJob, child: const Text('إيقاف')),
                  ],
                ),
                const Text('خلّ التطبيق مفتوح لين يخلص',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        if (cloud.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(cloud.lastError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: cloud.busy
                    ? null
                    : () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const UploadPickerPage())),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('رفع أغاني'),
              ),
              OutlinedButton.icon(
                onPressed: (cloud.busy || pending.isEmpty) ? null : () => cloud.download(pending),
                icon: const Icon(Icons.download_outlined),
                label: Text('تنزيل الكل (${pending.length})'),
              ),
              OutlinedButton.icon(
                onPressed: cloud.busy
                    ? null
                    : () async {
                        await cloud.startupSync();
                        if (context.mounted) toast(context, 'تمت المزامنة');
                      },
                icon: const Icon(Icons.sync),
                label: const Text('مزامنة الآن'),
              ),
            ],
          ),
        ),
        if (cloud.songs.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Text(
              'ما رفعت أغاني بعد.\nاضغط "رفع أغاني" واختر اللي تبي تحفظه بحسابك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.7),
            ),
          ),
        for (final c in cloud.songs) _songTile(context, c),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحساب والسحابة'), backgroundColor: Colors.transparent),
      body: ListenableBuilder(
        listenable: cloud,
        builder: (context, _) {
          if (!cloud.configured) return _notConfigured(context);
          if (!cloud.signedIn) return _signedOut(context);
          return _signedIn(context);
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

// ---------- اختيار أغاني للرفع ----------
class UploadPickerPage extends StatefulWidget {
  const UploadPickerPage({super.key});
  @override
  State<UploadPickerPage> createState() => _UploadPickerPageState();
}

class _UploadPickerPageState extends State<UploadPickerPage> {
  static const _maxFile = 50 * 1024 * 1024;
  final _q = TextEditingController();
  final Set<int> _sel = {};
  late final List<SongModel> _all;

  @override
  void initState() {
    super.initState();
    final inCloud = {for (final c in cloud.songs) c.key};
    _all = allSongs.where((s) => s.id > 0 && !inCloud.contains(cloud.keyOfSong(s))).toList();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<SongModel> get _filtered {
    final t = _q.text.trim().toLowerCase();
    if (t.isEmpty) return _all;
    return _all
        .where((s) => s.title.toLowerCase().contains(t) || artistOf(s).toLowerCase().contains(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final picked = _all.where((s) => _sel.contains(s.id)).toList();
    final totalSize = picked.fold<int>(0, (a, s) => a + s.size);
    final remaining = cloud.quotaBytes - cloud.usedBytes;
    final tooBig = totalSize > remaining;
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر أغاني للرفع'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              final ids = [for (final s in list) if (s.size <= _maxFile) s.id];
              if (ids.every(_sel.contains)) {
                _sel.removeAll(ids);
              } else {
                _sel.addAll(ids);
              }
            }),
            child: const Text('تحديد الكل'),
          ),
        ],
      ),
      body: Column(
        children: [
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
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _all.isEmpty
                ? const Center(
                    child: Text('كل أغانيك مرفوعة أو ما في أغاني',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      final big = s.size > _maxFile;
                      return CheckboxListTile(
                        value: _sel.contains(s.id),
                        onChanged: big
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _sel.add(s.id);
                                  } else {
                                    _sel.remove(s.id);
                                  }
                                }),
                        secondary: Art(id: s.id, size: 48, radius: 10),
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${artistOf(s)} • ${fmtBytes(s.size)}${big ? ' • أكبر من 50MB' : ''}',
                          maxLines: 1,
                          style: TextStyle(color: big ? Colors.redAccent : Colors.white54),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(color: context.card),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${picked.length} أغنية • ${fmtBytes(totalSize)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          tooBig
                              ? 'المساحة ما تكفي (المتبقي ${fmtBytes(remaining < 0 ? 0 : remaining)})'
                              : 'المتبقي ${fmtBytes(remaining < 0 ? 0 : remaining)}',
                          style: TextStyle(
                              color: tooBig ? Colors.redAccent : Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: (picked.isEmpty || tooBig)
                        ? null
                        : () {
                            cloud.uploadSongs(picked);
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('ارفع'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ===== END cloud_pages =====