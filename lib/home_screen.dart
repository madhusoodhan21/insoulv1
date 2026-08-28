import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import 'ble_service.dart';
import 'app_theme.dart';
import 'app_toast.dart';
import 'scan_screen.dart';
import 'metric_card.dart';

/// Dashboard screen — matches the Stitch "insoul_dashboard" mockup:
/// greeting header + connection pill, big steps ring card, gait symmetry
/// bar, and metric cards below.
class HomeScreen extends StatefulWidget {
  final int stepsAddedTick;
  final VoidCallback? onOpenExercise;

  const HomeScreen({super.key, this.stepsAddedTick = 0, this.onOpenExercise});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

@Preview(name: 'InSoul home screen', size: Size(480, 900))
Widget homeScreenPreview() {
  return ChangeNotifierProvider(
    create: (_) => BleService(initialize: false),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    ),
  );
}

class _HomeScreenState extends State<HomeScreen> {
  // Demo data — matches the design's placeholder values. Real sensor
  // values get wired in once the full insole sensor suite exists; step
  // count already comes live from the ESP32 below.
  int steps = 6248;
  int goal = 8000;

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stepsAddedTick != oldWidget.stepsAddedTick) {
      setState(() => steps += 500);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    // Once the insole is connected, the ring shows the live ESP32 value
    // (BleService.stepCount) instead of the local demo counter. During a
    // brief reconnect, fall back to the *last known* real value instead of
    // snapping back to the demo counter.
    final displaySteps = (ble.connected || ble.hasEverConnected)
        ? ble.stepCount
        : steps;
    final remaining = (goal - displaySteps).clamp(0, goal);
    final progress = (displaySteps / goal).clamp(0.0, 1.0);
    final symmetryScore = ble.symmetryScore;
    final goodBalance = symmetryScore != null && symmetryScore >= 75;
    final symmetryColor = symmetryScore == null
      ? AppColors.textDim
      : Color.lerp(
        AppColors.red,
        AppColors.green,
        (symmetryScore / 100).clamp(0.0, 1.0),
        )!;
    final limpingLeg = ble.leftToRightMs == null || ble.rightToLeftMs == null
        ? null
        : ble.leftToRightMs! > ble.rightToLeftMs!
        ? 'Left Leg Limping'
        : ble.rightToLeftMs! > ble.leftToRightMs!
        ? 'Right Leg Limping'
        : 'Balanced';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/images/insoul_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.bg,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting,',
                        style: AppFonts.headline(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'User',
                        style: AppFonts.headline(
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready for your daily walk?',
                        style: AppFonts.body(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ConnPill(ble: ble),
            const SizedBox(height: 20),
            // --- Steps ring card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(220, 220),
                          painter: _RingPainter(progress: progress),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: AppColors.green,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatSteps(displaySteps),
                              style: AppFonts.metric(fontSize: 38),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'STEPS TODAY',
                              style: AppFonts.label(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _GoalStat(label: 'Goal', value: _formatSteps(goal)),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppColors.borderSoft,
                      ),
                      _GoalStat(
                        label: 'Remaining',
                        value: _formatSteps(remaining),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- Gait symmetry card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: symmetryColor.withValues(
                    alpha: symmetryScore == null ? 0.2 : 0.65,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'GAIT SYMMETRY',
                        style: AppFonts.label(fontSize: 11),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: symmetryColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 13,
                              color: goodBalance
                                  ? symmetryColor
                                  : symmetryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              goodBalance
                                  ? 'Good Balance'
                                  : limpingLeg ?? 'Needs Attention',
                              style: AppFonts.body(
                                fontSize: 11,
                                color: symmetryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    symmetryScore == null
                        ? '--'
                        : '${symmetryScore.toStringAsFixed(1)}%',
                    style: AppFonts.metric(fontSize: 30, color: symmetryColor),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 136,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SymmetryGaugePainter(
                        score: ble.symmetryScore ?? 0,
                        hasScore: ble.symmetryScore != null,
                        leftToRightMs: ble.leftToRightMs,
                        rightToLeftMs: ble.rightToLeftMs,
                        color: symmetryColor,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ble.leftToRightMs == null
                            ? 'Left --'
                            : 'L-R ${ble.leftToRightMs} ms',
                        style: AppFonts.body(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                      Text(
                        ble.rightToLeftMs == null
                            ? 'Right --'
                            : 'R-L ${ble.rightToLeftMs} ms',
                        style: AppFonts.body(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: MetricCard(
                    label: 'Distance Covered',
                    value: '3.1 km',
                    sub: '0.74m avg stride',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Wear Time',
                    value: '4h 15m',
                    sub: 'Active pressure',
                    valueColor: AppColors.sky,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: widget.onOpenExercise,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY PROTOCOL',
                            style: AppFonts.label(fontSize: 11),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Continue your exercise routine',
                            style: AppFonts.body(
                              fontSize: 12,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: AppColors.textDim,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSteps(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _GoalStat extends StatelessWidget {
  final String label;
  final String value;
  const _GoalStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppFonts.body(fontSize: 12, color: AppColors.textDim),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ConnPill extends StatelessWidget {
  final BleService ble;
  const _ConnPill({required this.ble});

  @override
  Widget build(BuildContext context) {
    final connected = ble.connected;
    return GestureDetector(
      onTap: () async {
        if (connected) {
          await ble.disconnect();
          if (context.mounted) showAppToast(context, 'Insole disconnected');
        } else {
          ble.startScan();
          final picked = await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => const ScanScreen()));
          if (picked == true && context.mounted) {
            showAppToast(context, 'InSoul Shoe V1 Connected');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? AppColors.green : AppColors.textDim,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              connected ? 'INSOUL ACTIVE' : 'TAP TO CONNECT',
              style: AppFonts.label(
                fontSize: 11,
                color: connected ? AppColors.text : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 13;

    final track = Paint()
      ..color = AppColors.surfaceHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final prog = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, prog);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SymmetryGaugePainter extends CustomPainter {
  final double score;
  final bool hasScore;
  final int? leftToRightMs;
  final int? rightToLeftMs;
  final Color color;

  _SymmetryGaugePainter({
    required this.score,
    required this.hasScore,
    required this.leftToRightMs,
    required this.rightToLeftMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 18, size.height - 20);
    const startAngle = math.pi;

    final tickPaint = Paint()
      ..color = AppColors.textDim
      ..strokeWidth = 1.5;
    for (var tick = 0; tick <= 10; tick++) {
      final angle = startAngle + (math.pi * tick / 10);
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 13),
        center.dy + math.sin(angle) * (radius + 13),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius + 7),
        center.dy + math.sin(angle) * (radius + 7),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (hasScore) {
      final ltrMs = leftToRightMs ?? 0;
      final rtlMs = rightToLeftMs ?? 0;
      final timingTotal = ltrMs + rtlMs;
      final timingDifference = timingTotal == 0
          ? 0.0
          : ((ltrMs - rtlMs) / timingTotal).clamp(-1.0, 1.0);
      final needleAngle = (math.pi * 1.5) + (timingDifference * math.pi / 2);
      final needleEnd = Offset(
        center.dx + math.cos(needleAngle) * (radius - 5),
        center.dy + math.sin(needleAngle) * (radius - 5),
      );
      final needle = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, needleEnd, needle);
      canvas.drawCircle(center, 6, Paint()..color = color);
      canvas.drawCircle(center, 2.5, Paint()..color = AppColors.bg);
    }

    // _drawLabel(canvas, '100', Offset(center.dx - 17, center.dy - radius - 3));
  }


  @override
  bool shouldRepaint(covariant _SymmetryGaugePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.hasScore != hasScore ||
      oldDelegate.leftToRightMs != leftToRightMs ||
      oldDelegate.rightToLeftMs != rightToLeftMs;
}
