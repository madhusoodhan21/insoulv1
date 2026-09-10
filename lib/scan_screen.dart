import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'ble_service.dart';
import 'app_theme.dart';
import 'app_shell.dart';

/// "Connect Shoe" screen — matches the Stitch design's connect_shoe mockup:
/// logo badge, pulsing Bluetooth target, pill "SCAN DEVICES" button, and an
/// "Available Devices" list. All BLE mechanics (scan/connect/permissions)
/// are untouched from the original ScanScreen — only the visuals changed.
class ScanScreen extends StatefulWidget {
  /// True when this screen is the app's mandatory connect-first entry
  /// point (pushed as `home:` in main.dart) — a successful connection then
  /// replaces this route with AppShell instead of popping back to a caller.
  final bool isEntryFlow;

  const ScanScreen({super.key, this.isEntryFlow = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _isTransitioning = false;

  Route<void> _homeRoute() {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 850),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AppShell(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            const ColoredBox(color: Colors.black),
            FadeTransition(opacity: animation, child: child),
          ],
        );
      },
    );
  }

  Future<void> _proceedToHome(BleService ble) async {
    if (_isTransitioning) return;
    setState(() => _isTransitioning = true);
    final stopScan = ble.isScanning ? ble.stopScan() : Future<void>.value();
    await Future.wait([
      stopScan,
      Future<void>.delayed(const Duration(seconds: 1)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(_homeRoute());
  }

  // NOTE: scanning is intentionally NOT auto-started here. On Flutter Web,
  // FlutterBluePlus.startScan() calls the browser's
  // navigator.bluetooth.requestDevice(), which Chrome/Edge only allow in
  // direct response to a user click. Requiring an explicit tap on the
  // "Scan Devices" button below keeps that working on web, and is
  // harmless on Android/iOS/desktop.
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final btOff = ble.adapterState != BluetoothAdapterState.on &&
        ble.adapterState != BluetoothAdapterState.unknown;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: !widget.isEntryFlow,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.sensors, color: ble.connected ? AppColors.green : AppColors.textDim),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final logoSize = constraints.maxWidth.clamp(220.0, 340.0).toDouble();
                        final animationSize = constraints.maxWidth.clamp(260.0, 320.0).toDouble();
                        final ringSize = animationSize - 40;
                        final centerSize = animationSize * 0.594;
                        return Column(
                          children: [
                            Hero(
                              tag: 'insoul-logo',
                              child: SizedBox(
                                width: logoSize,
                                height: 90,
                                child: Image.asset(
                                  'assets/images/insoul_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            Text(
                              'Make sure your InSoul shoes are in docked mode',
                              textAlign: TextAlign.center,
                              style: AppFonts.description(fontSize: 15, color: AppColors.textMid),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: animationSize,
                              height: animationSize,
                              child: AnimatedBuilder(
                                animation: _pulse,
                                builder: (context, _) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _pulseRing(ringSize, 0.0),
                                      _pulseRing(ringSize, 0.5),
                                      Container(
                                        width: centerSize,
                                        height: centerSize,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.surfaceHigher,
                                        ),
                                        alignment: Alignment.center,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          child: _isTransitioning
                                              ? SizedBox(
                                                  key: const ValueKey('loading'),
                                                  width: centerSize * 0.38,
                                                  height: centerSize * 0.38,
                                                  child: const CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    color: AppColors.greenBright,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.bluetooth,
                                                  key: const ValueKey('bluetooth'),
                                                  size: centerSize * 0.38,
                                                  color: ble.isScanning ? AppColors.greenBright : AppColors.green,
                                                ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (btOff)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.redDim,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Bluetooth is off. Please enable it in system settings.',
                          style: AppFonts.body(fontSize: 12, color: AppColors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: ble.isScanning ? null : () => ble.startScan(),
                        icon: const Icon(Icons.radar, size: 18),
                        label: Text(
                          ble.isScanning ? 'SCANNING…' : 'SCAN DEVICES',
                          style: AppFonts.label(fontSize: 14, color: AppColors.onGreen, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.greenBright,
                          foregroundColor: AppColors.onGreen,
                          disabledBackgroundColor: AppColors.surfaceHigher,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!ble.connected)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Debug: Y = left FSR · U = right FSR',
                          style: AppFonts.label(fontSize: 10, color: AppColors.textDim),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _proceedToHome(ble);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMid,
                          side: const BorderSide(color: AppColors.border),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'CONTINUE WITHOUT CONNECTING',
                          style: AppFonts.label(fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('AVAILABLE DEVICES', style: AppFonts.label(fontSize: 11)),
                    ),
                    const SizedBox(height: 10),
                    if (ble.scanResults.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ble.isScanning ? 'Scanning…' : 'No devices found yet.',
                          style: AppFonts.body(fontSize: 13, color: AppColors.textDim),
                        ),
                      )
                    else
                      ...ble.scanResults.map((r) {
                        final name = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                ? r.advertisementData.advName
                                : 'Unknown device');
                        final isTarget = BleService.kTargetDeviceNames.contains(name);
                        return _DeviceRow(
                          name: name,
                          subtitle: '${r.device.remoteId} · RSSI ${r.rssi} dBm',
                          highlighted: isTarget,
                          onConnect: () async {
                            final connected = await ble.connectTo(r.device);
                            if (!context.mounted) return;
                            if (connected) {
                              if (widget.isEntryFlow) {
                                await _proceedToHome(ble);
                              } else {
                                Navigator.of(context).pop(true);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ble.status)),
                              );
                            }
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulseRing(double maxSize, double delay) {
    final t = (_pulse.value + delay) % 1.0;
    final size = 130 + (maxSize - 130) * t;
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onConnect;

  const _DeviceRow({
    required this.name,
    required this.subtitle,
    required this.highlighted,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? AppColors.green.withValues(alpha: 0.4) : AppColors.borderSoft,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.greenDim,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.directions_walk, color: AppColors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppFonts.body(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(fontSize: 11, color: AppColors.textDim),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onConnect,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green,
              side: const BorderSide(color: AppColors.green, width: 1.5),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('CONNECT', style: AppFonts.label(fontSize: 11, color: AppColors.green)),
          ),
        ],
      ),
    );
  }
}
