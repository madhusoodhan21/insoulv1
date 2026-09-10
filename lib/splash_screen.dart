import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'scan_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: InSoul from Team: Big Steppers
  late final Animation<double> _insoulFadeIn;
  late final Animation<double> _insoulScale;
  late final Animation<double> _insoulFadeOut;

  // Phase 2: Powered by VEGA logo
  late final Animation<double> _vegaFadeIn;
  late final Animation<double> _vegaScale;
  late final Animation<double> _vegaFadeOut;

  @override
  void initState() {
    super.initState();

    // Total sequence duration: 4.8 seconds
    // 0.0s - 0.5s: InSoul fade in + gentle scale
    // 0.5s - 1.8s: InSoul hold
    // 1.8s - 2.3s: InSoul fade out
    // 2.3s - 2.8s: VEGA fade in + gentle scale
    // 2.8s - 4.1s: VEGA hold
    // 4.1s - 4.6s: VEGA fade out
    // 4.6s - 4.8s: Navigate smoothly to ScanScreen
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );

    _insoulFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.12, curve: Curves.easeOutCubic),
      ),
    );

    _insoulScale = Tween<double>(begin: 0.92, end: 1.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.44, curve: Curves.easeOutQuad),
      ),
    );

    _insoulFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.48, curve: Curves.easeInOutCubic),
      ),
    );

    _vegaFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    _vegaScale = Tween<double>(begin: 0.92, end: 1.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.90, curve: Curves.easeOutQuad),
      ),
    );

    _vegaFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.86, 0.98, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward().then((_) {
      _navigateToConnectionScreen();
    });
  }

  void _navigateToConnectionScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScanScreen(isEntryFlow: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final insoulOpacity =
              (_insoulFadeIn.value * _insoulFadeOut.value).clamp(0.0, 1.0);
          final vegaOpacity =
              (_vegaFadeIn.value * _vegaFadeOut.value).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Ambient soft radial gradient in background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        AppColors.greenDim.withValues(alpha: 0.18),
                        AppColors.bg,
                      ],
                    ),
                  ),
                ),
              ),

              // Phase 1: InSoul logo from team: big steppers
              if (insoulOpacity > 0.0)
                Opacity(
                  opacity: insoulOpacity,
                  child: Transform.scale(
                    scale: _insoulScale.value,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // InSoul Logo Image (enlarged & sharp)
                            Image.asset(
                              'assets/images/insoul_logo.png',
                              width: 320,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 24),
                            // "FROM TEAM: BIG STEPPERS" Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHi,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.borderSoft,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'FROM TEAM: ',
                                    style: AppFonts.label(
                                      fontSize: 11.5,
                                      color: AppColors.textDim,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'BIG STEPPERS',
                                    style: AppFonts.label(
                                      fontSize: 12.5,
                                      color: AppColors.greenBright,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Phase 2: Powered by VEGA logo
              if (vegaOpacity > 0.0)
                Opacity(
                  opacity: vegaOpacity,
                  child: Transform.scale(
                    scale: _vegaScale.value,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'POWERED BY',
                              style: AppFonts.label(
                                fontSize: 13,
                                color: AppColors.textDim,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // VEGA Logo Image (significantly enlarged & centered)
                            Image.asset(
                              'assets/images/VEGA logo.png',
                              width: 290,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Skip button in top-right corner for quick access during testing
              Positioned(
                top: 48,
                right: 20,
                child: GestureDetector(
                  onTap: _navigateToConnectionScreen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SKIP',
                      style: AppFonts.label(
                        fontSize: 10,
                        color: AppColors.textDim,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
