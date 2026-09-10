import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ble_service.dart';
import 'app_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  bool _scanning = false;
  double? _impedance;
  double? _voltage;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
      _impedance = null;
      _voltage = null;
    });
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _impedance = 420 + math.Random().nextInt(60).toDouble();
      _voltage = 3.6 + math.Random().nextDouble() * 0.3;
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final receivingPackets =
        ble.lastPacketAt != null &&
        DateTime.now().difference(ble.lastPacketAt!).inSeconds < 2;
    final hasImuData =
        ble.gyroscopeX != null &&
        ble.gyroscopeY != null &&
        ble.gyroscopeZ != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Diagnostics', style: AppFonts.display(fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ble.connected ? AppColors.greenDim : AppColors.redDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ble.connected ? 'Insole connected' : 'Insole not connected',
                  style: AppFonts.body(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ble.connected ? AppColors.green : AppColors.red,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'MPU6050 live output',
                            style: AppFonts.display(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          hasImuData
                              ? 'Receiving MPU6050'
                              : receivingPackets
                              ? 'Packets, no MPU data'
                              : 'No recent data',
                          style: AppFonts.body(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasImuData
                                ? AppColors.green
                                : receivingPackets
                                ? AppColors.yellow
                                : AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ble.packetCount} BLE packets received',
                      style: AppFonts.body(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ImuTile(
                            label: 'Gyro X',
                            value: ble.gyroscopeX,
                            unit: '°/s',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ImuTile(
                            label: 'Gyro Y',
                            value: ble.gyroscopeY,
                            unit: '°/s',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ImuTile(
                            label: 'Gyro Z',
                            value: ble.gyroscopeZ,
                            unit: '°/s',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 130,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _WavePainter(
                      phase: _wave.value * 2 * math.pi,
                      active: _scanning,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ReadoutTile(
                      label: 'Sensor impedance',
                      value: _impedance == null
                          ? '—'
                          : '${_impedance!.toStringAsFixed(0)} Ω',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadoutTile(
                      label: 'Battery voltage',
                      value: _voltage == null
                          ? '—'
                          : '${_voltage!.toStringAsFixed(2)} V',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _scanning ? null : _runScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: const Color(0xFF06120C),
                    disabledBackgroundColor: AppColors.surfaceHi,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _scanning ? 'Scanning…' : 'Run diagnostic scan',
                    style: AppFonts.display(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadoutTile extends StatelessWidget {
  final String label;
  final String value;
  const _ReadoutTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.body(fontSize: 11, color: AppColors.textMid),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppFonts.dot(fontSize: 18, color: AppColors.text)),
        ],
      ),
    );
  }
}

class _ImuTile extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;

  const _ImuTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.body(fontSize: 10, color: AppColors.textMid),
        ),
        const SizedBox(height: 3),
        Text(
          value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
          style: AppFonts.dot(fontSize: 13, color: AppColors.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  final bool active;
  _WavePainter({required this.phase, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? AppColors.green : AppColors.textDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final midY = size.height / 2;
    final amp = active ? size.height * 0.32 : size.height * 0.08;
    for (double x = 0; x <= size.width; x += 2) {
      final y = midY + amp * math.sin((x / size.width * 4 * math.pi) + phase);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.active != active;
}
