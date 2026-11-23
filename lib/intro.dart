import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core.dart';

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

class _IntroSplashState extends State<IntroSplash> with TickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _bars =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  bool _first = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final p = await SharedPreferences.getInstance();
    _first = !(p.getBool('onboarded') ?? false);
    _c.forward();
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeTo((ctx) => _first ? OnboardingPage(next: widget.next) : widget.next(ctx)),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _bars.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, Curve c) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    final logoScale = _iv(0.0, 0.40, Curves.easeOutBack);
    final logoFade = _iv(0.0, 0.25, Curves.easeOut);
    final text = _iv(0.30, 0.60, Curves.easeOut);
    final tag = _iv(0.55, 0.85, Curves.easeOut);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.4 + 0.5 * _c.value,
                  colors: [a.withAlpha((90 * _c.value).round()), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: logoScale,
                  child: FadeTransition(
                    opacity: logoFade,
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        gradient: LinearGradient(
                          colors: [a, Color.lerp(a, Colors.black, 0.55)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [BoxShadow(color: a.withAlpha(120), blurRadius: 50)],
                      ),
                      child: AnimatedBuilder(
                        animation: _bars,
                        builder: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final h = 18 +
                                40 * (0.5 + 0.5 * math.sin(_bars.value * 2 * math.pi + i * 0.9));
                            return Container(
                              width: 8,
                              height: h,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: text,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(text),
                    child: const Text(
                      'musicApp',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: tag,
                  child: const Text('موسيقاك .. بطريقتك',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 56,
            left: 90,
            right: 90,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _c.value,
                  minHeight: 3,
                  backgroundColor: Colors.white10,
                  color: a,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  final WidgetBuilder next;
  const OnboardingPage({super.key, required this.next});
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
    _Slide(Icons.headphones_rounded, 'مرحبًا بك في musicApp',
        'مشغّل أغانيك الخاص، بتصميم أنيق وإحساس احترافي.'),
    _Slide(Icons.lyrics_rounded, 'كلمات تتحرك مع الأغنية',
        'اضغط أيقونة الكلمات بشاشة التشغيل، وشوف السطر الحالي يتلوّن مع الصوت.'),
    _Slide(Icons.auto_awesome_rounded, 'مكتبتك بطريقتك',
        'مفضلة وقوائم تشغيل وإحصائيات استماعك، وألوان تتغير مع كل غلاف.'),
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
    Navigator.of(context).pushReplacement(_fadeTo(widget.next));
  }

  Widget _slide(_Slide s) {
    final a = context.accent;
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
                  colors: [a, Color.lerp(a, Colors.black, 0.55)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: a.withAlpha(100), blurRadius: 50)],
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
                      color: i == _i ? context.accent : Colors.white24,
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