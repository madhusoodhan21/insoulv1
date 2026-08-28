import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import 'ble_service.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'scan_screen.dart';

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
    return ChangeNotifierProvider(
      create: (_) => BleService(),
      child: MaterialApp(
        title: 'InSoul',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Mobile-portrait layout: the whole app is designed around a single
        // narrow column, so we don't need MediaQuery orientation handling —
        // just constrain width so it also looks right on wider (tablet/web)
        // viewports instead of stretching edge to edge.
        builder: (context, child) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: child,
              ),
            ),
          );
        },
        home: const ScanScreen(isEntryFlow: true),
      ),
    );
  }
}

@Preview(name: 'InSoul home screen', size: Size(480, 900))
Widget inSoulHomePreview() {
  return ChangeNotifierProvider(
    create: (_) => BleService(initialize: false),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    ),
  );
}
