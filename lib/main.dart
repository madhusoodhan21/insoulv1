import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import 'ble_service.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'splash_screen.dart';

class AppSettings extends ChangeNotifier {
  double _fontScale = 0.75;

  double get fontScale => _fontScale;

  void setFontScale(double value) {
    if (value == _fontScale) return;
    _fontScale = value;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This UI is designed for a single portrait column (steps ring, stacked
  // cards, bottom nav) — lock orientation so it never gets stretched into
  // a landscape layout on phones/tablets that would otherwise rotate.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const InSoulApp());
}

class InSoulApp extends StatelessWidget {
  const InSoulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'InSoul',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            // Mobile-portrait layout: the whole app is designed around a single
            // narrow column, so we don't need MediaQuery orientation handling —
            // just constrain width so it also looks right on wider (tablet/web)
            // viewports instead of stretching edge to edge.
            builder: (context, child) {
              final adjusted = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.fontScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );

              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: adjusted,
                  ),
                ),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

@Preview(name: 'InSoul home screen', size: Size(480, 900))
Widget inSoulHomePreview() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BleService(initialize: false)),
      ChangeNotifierProvider(create: (_) => AppSettings()),
    ],
    child: Consumer<AppSettings>(
      builder: (context, settings, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    ),
  );
}
