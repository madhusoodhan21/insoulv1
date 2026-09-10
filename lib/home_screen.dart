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
  final VoidCallback? onOpenExercise;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenGaitAnalysis;

  const HomeScreen({
    super.key,
    this.onOpenExercise,
    this.onOpenProfile,
    this.onOpenGaitAnalysis,
  });

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
  int goal = 8000;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final displaySteps = ble.stepCount;
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
        : 'Good Symmetry';
    final symmetryImbalance =
        ble.leftToRightMs == null || ble.rightToLeftMs == null
        ? null
        : ((ble.leftToRightMs! - ble.rightToLeftMs!) /
                  (ble.leftToRightMs! + ble.rightToLeftMs!))
              .clamp(-1.0, 1.0);
    final transitionTimes = [
      ble.leftToRightMs,
      ble.rightToLeftMs,
    ].whereType<int>().toList();
    final averageBetweenStepsMs = transitionTimes.isEmpty
        ? null
        : (transitionTimes.reduce((a, b) => a + b) / transitionTimes.length)
              .round();
    final averageBetweenSteps = averageBetweenStepsMs == null
        ? '--'
        : averageBetweenStepsMs >= 1000
        ? '${(averageBetweenStepsMs / 1000).toStringAsFixed(2)}s'
        : '${averageBetweenStepsMs}ms';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'insoul-logo',
                  child: SizedBox(
                    width: 180,
                    height: 72,
                    child: ClipRect(
                      child: Transform.translate(
                        offset: const Offset(-24, 0),
                        child: Image.asset(
                          'assets/images/insoul_logo.png',
                          width: 180,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: Container(
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
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'User',
                        style: AppFonts.headline(
                          fontSize: 28,
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
            SizedBox(
              height: 198,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DashboardMetricCard(
                      title: 'STEPS TODAY',
                      icon: Icons.directions_walk,
                      value: _formatSteps(displaySteps),
                      detail: '${(progress * 100).round()}% of target achieved',
                      progress: progress,
                      valueColor: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GaitSymmetryCard(
                      title: 'GAIT SYMMETRY',
                      value: symmetryScore == null
                          ? '--'
                          : '${symmetryScore.toStringAsFixed(1)}%',
                      status: goodBalance
                          ? 'Good Balance'
                          : limpingLeg ?? 'Needs Attention',
                      imbalance: symmetryImbalance,
                      valueColor: symmetryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Avg between steps',
                    value: averageBetweenSteps,
                    sub: 'left/right transitions',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Avg gait symmetry',
                    value: symmetryScore == null
                        ? '--'
                        : '${symmetryScore.toStringAsFixed(1)}%',
                    sub: 'weekly',
                    valueColor: symmetryScore == null
                        ? AppColors.textDim
                        : symmetryColor,
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
            const SizedBox(height: 14),
            // Quick Gait Analysis Hero Feature Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.greenBright.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface,
                    AppColors.greenDim.withValues(alpha: 0.35),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.greenDim,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.greenBright.withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.directions_walk,
                          color: AppColors.greenBright,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'QUICK GAIT ANALYSIS',
                                    style: AppFonts.headline(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.greenDim,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '10-SEC CLINICAL SCREENING',
                                style: AppFonts.label(
                                  fontSize: 9.5,
                                  color: AppColors.greenBright,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Evaluate bilateral ground reaction forces, temporal symmetry, limb dominance, and fall risk score.',
                    style: AppFonts.description(
                      fontSize: 12.5,
                      color: AppColors.textMid,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onOpenGaitAnalysis,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        'START 10S GAIT SCAN',
                        style: AppFonts.label(
                          fontSize: 12,
                          color: AppColors.onGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenBright,
                        foregroundColor: AppColors.onGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
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

class _DashboardMetricCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String value;
  final String detail;
  final double progress;
  final Color valueColor;

  const _DashboardMetricCard({
    required this.title,
    this.icon,
    required this.value,
    required this.detail,
    required this.progress,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: valueColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: valueColor, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.label(fontSize: 15),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Big number
          Center(
            child: Text(
              value,
              style: AppFonts.metric(fontSize: 48, color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          
          // Indicator (progress bar)
          Center(child: _StepDotProgress(progress: progress)),
          const SizedBox(height: 12),
          
          // Subtitle
          Center(
            child: Text(
              detail,
              style: AppFonts.body(
                fontSize: 11,
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
          
          // Flexible spacer to maintain alignment
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _StepDotProgress extends StatelessWidget {
  final double progress;

  const _StepDotProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final activeDots = (progress.clamp(0.0, 1.0) * 48).round();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (row) => Padding(
            padding: EdgeInsets.only(bottom: row == 2 ? 0 : 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(16, (column) {
                final index = row * 16 + column;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < activeDots
                          ? const Color(0xFFF1F5ED)
                          : AppColors.surfaceHighest,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class GaitSymmetryCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final double? imbalance;
  final Color valueColor;

  const GaitSymmetryCard({
    super.key,
    required this.title,
    required this.value,
    required this.status,
    required this.imbalance,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: valueColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (title)
          Text(
            title,
            style: AppFonts.label(fontSize: 15),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          
          // Big number
          Center(
            child: Text(
              value,
              style: AppFonts.metric(fontSize: 48, color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          
          // Indicator (symmetry bar)
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: GaitSymmetryBarPainter(imbalance: imbalance),
            ),
          ),
          const SizedBox(height: 12),
          
          // Subtitle (status)
          Center(
            child: Text(
              status,
              style: AppFonts.body(
                fontSize: 11,
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          
          // Flexible spacer to maintain alignment
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class GaitSymmetryBarPainter extends CustomPainter {
  final double? imbalance;

  const GaitSymmetryBarPainter({required this.imbalance});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final center = Offset(centerX, size.height / 2);
    const trackHeight = 8.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, center.dy - trackHeight / 2, size.width, trackHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.surfaceHighest);

    final normalized = (imbalance ?? 0).clamp(-1.0, 1.0);
    final markerX = centerX - normalized * (size.width / 2 - 6);
    final fillStart = math.min(centerX, markerX);
    final fillEnd = math.max(centerX, markerX);
    if (imbalance != null && fillEnd > fillStart) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          fillStart,
          center.dy - trackHeight / 2,
          fillEnd,
          center.dy + trackHeight / 2,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(fill, Paint()..color = AppColors.amber);
    }

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      Paint()
        ..color = AppColors.green
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(markerX, center.dy),
      5,
      Paint()
        ..color = imbalance == null ? AppColors.textDim : AppColors.greenBright,
    );
  }

  @override
  bool shouldRepaint(covariant GaitSymmetryBarPainter oldDelegate) =>
      oldDelegate.imbalance != imbalance;
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
