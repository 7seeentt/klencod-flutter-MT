import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core.dart';
import 'cloud.dart';
import 'cloud_pages.dart';
import 'brand.dart';

Route<void> _fadeTo(WidgetBuilder b) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, __, ___) => b(ctx),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    );

// ---------- السبلاش ----------
class IntroSplash extends StatefulWidget {
  final WidgetBuilder next;
  const IntroSplash({super.key, required this.next});
  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final p = await SharedPreferences.getInstance();
    final onboarded = p.getBool('onboarded') ?? false;
    final guest = p.getBool('guest') ?? false;
    await _c.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final needLogin = cloud.configured && !cloud.signedIn && !guest;
    Navigator.of(context).pushReplacement(_fadeTo(
      (ctx) => _Flow(onboarding: !onboarded, login: needLogin, next: widget.next),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b) => ((_c.value - a) / (b - a)).clamp(0.0, 1.0).toDouble();

  double _bar(int i) {
    final t = ((_c.value - (0.20 + 0.06 * i)) / 0.25).clamp(0.0, 1.0).toDouble();
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final pop = Curves.easeOutBack.transform(_seg(0.0, 0.30));
          final fade = _seg(0.0, 0.18);
          final word = Curves.easeOut.transform(_seg(0.55, 0.80));
          final sub = Curves.easeOut.transform(_seg(0.70, 0.95));
          final glow = _seg(0.0, 0.5);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.9,
                    colors: [brandColor.withAlpha((70 * glow).round()), Colors.transparent],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * pop,
                        child: BrandMark(size: 120, bars: [for (var i = 0; i < 5; i++) _bar(i)]),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Opacity(
                      opacity: word,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - word)),
                        child: const Text('MT',
                            style: TextStyle(
                                fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: 8)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: sub,
                      child: const Text('MUSIC TIME',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 5,
                              color: Colors.white54,
                              fontWeight: FontWeight.w600)),
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

// ---------- تسلسل الشاشات: ترحيب ثم دخول ثم التطبيق ----------
class _Flow extends StatefulWidget {
  final bool onboarding;
  final bool login;
  final WidgetBuilder next;
  const _Flow({required this.onboarding, required this.login, required this.next});
  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  late int _stage = widget.onboarding ? 0 : (widget.login ? 1 : 2);

  void _advance() {
    setState(() {
      if (_stage == 0 && widget.login) {
        _stage = 1;
      } else {
        _stage = 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_stage == 0) {
      child = OnboardingPage(key: const ValueKey('s0'), onDone: _advance);
    } else if (_stage == 1) {
      child = AuthScreen(key: const ValueKey('s1'), gate: true, onDone: _advance);
    } else {
      child = Builder(key: const ValueKey('s2'), builder: widget.next);
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
  }
}

// ---------- شاشة الترحيب (أول مرة فقط) ----------
class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  final _pc = PageController();
  int _i = 0;
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  static const _slides = [
    _Slide(Icons.headphones_rounded, 'أهلًا بيك بـ MT',
        'مشغّل أغانيك الخاص، بتصميم أنيق وإحساس احترافي.'),
    _Slide(Icons.lyrics_rounded, 'كلمات تتحرك مع الأغنية',
        'اضغط أيقونة الكلمات بشاشة التشغيل، وشوف السطر الحالي يتلوّن مع الصوت.'),
    _Slide(Icons.cloud_sync_rounded, 'مكتبتك وياك وين ما رحت',
        'سجّل حساب وتنحفظ مفضلتك وقوائمك وأغانيك، وترجع لك على أي جوال.'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    _float.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
    if (!mounted) return;
    widget.onDone();
  }

  Widget _slide(_Slide s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -12 + 24 * _float.value),
              child: child,
            ),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [brandColor, brandDark()],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: brandColor.withAlpha(100), blurRadius: 50)],
              ),
              child: Icon(s.icon, size: 76, color: Colors.white),
            ),
          ),
          const SizedBox(height: 44),
          Text(s.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text(s.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _finish,
                child: const Text('تخطي', style: TextStyle(color: Colors.white54)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => _slide(_slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _i ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _i ? brandColor : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (last) {
                      _finish();
                    } else {
                      _pc.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic);
                    }
                  },
                  child: Text(last ? 'ابدأ' : 'التالي', style: const TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ===== END intro =====