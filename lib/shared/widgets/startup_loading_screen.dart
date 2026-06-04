import 'package:flutter/material.dart';

/// Branded animated loading screen shown immediately on startup while heavy
/// async initialization (database, Matrix client, localization) completes.
///
/// Uses no localization or providers — just the app's visual identity.
/// Self-contained so it can be shown before the [MaterialApp.router] is
/// even constructed.
class StartupLoadingScreen extends StatefulWidget {
  const StartupLoadingScreen({super.key});

  @override
  State<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<StartupLoadingScreen>
    with TickerProviderStateMixin {
  // Sage green brand color used for the logo and pulsing dots.
  static const _sage = Color(0xFF5B8C5A);
  static const _lightBg = Color(0xFFFFFBF8);
  static const _darkBg = Color(0xFF111315);

  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _dotsController;
  late final AnimationController _glowController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Logo: scale up + fade in over 600ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // Text: fade + slide up, starts after logo
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Dots: looping for pulse effect
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Glow: slow pulsing radial gradient
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Sequence the animations
    _logoController.forward().then((_) {
      if (mounted) {
        _textController.forward();
        _dotsController.repeat();
        _glowController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? _darkBg : _lightBg;
    final textColor =
        isDark ? const Color(0xFFE3E2DF) : const Color(0xFF1A1C1E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        backgroundColor: bg,
        body: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowSize = 0.4 + (_glowController.value * 0.15);
            final glowOpacity = isDark ? 0.12 : 0.08;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: glowSize,
                  colors: [_sage.withValues(alpha: glowOpacity), bg],
                ),
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: const Image(
                    image: AssetImage('assets/icon/logo.png'),
                    width: 88,
                    height: 88,
                    errorBuilder: _logoErrorBuilder,
                  ),
                ),

                const SizedBox(height: 20),

                // App name slides up
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Text(
                      'substitution',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Pulsing dots loader
                AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        // Stagger each dot by 0.2 of the animation cycle
                        final offset = i * 0.2;
                        final t = (_dotsController.value - offset) % 1.0;
                        // Smooth pulse: peak at 0.3, fade by 0.6
                        final pulse =
                            t < 0.3
                                ? (t / 0.3)
                                : t < 0.6
                                ? 1.0 - ((t - 0.3) / 0.3)
                                : 0.0;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sage.withValues(
                              alpha: 0.25 + (pulse * 0.75),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _logoErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const Icon(Icons.spa_rounded, size: 88, color: _sage);
  }
}
