import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'app_toast.dart';
import 'ble_service.dart';
import 'report_exporter.dart';

/// Physio tab — folds together the Stitch "physio_analysis" (live pressure
/// map / current pattern / session log) and "weekly_insights" (steps /
/// distance / gait / pressure trend chips) mockups behind a Live/Weekly
/// toggle, since both live under the same bottom-nav "Physio" tab.
class PhysioScreen extends StatefulWidget {
  const PhysioScreen({super.key});

  @override
  State<PhysioScreen> createState() => _PhysioScreenState();
}

class _PhysioScreenState extends State<PhysioScreen> {
  int _mode = 0; // 0 Live, 1 Weekly

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: AppColors.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  'InSoul',
                  style: AppFonts.headline(
                    fontSize: 16,
                    color: AppColors.green,
                  ),
                ),
                const Spacer(),
                Consumer<BleService>(
                  builder: (context, ble, _) => Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ble.connected
                              ? AppColors.green
                              : AppColors.textDim,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ble.connected ? 'Active' : 'Idle',
                        style: AppFonts.body(
                          fontSize: 12,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'PHYSIO ANALYSIS',
                    active: _mode == 0,
                    onTap: () => setState(() => _mode = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: 'WEEKLY INSIGHTS',
                    active: _mode == 1,
                    onTap: () => setState(() => _mode = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_mode == 0)
              const _LivePhysioView()
            else
              const _WeeklyInsightsView(),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.greenBright : AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppFonts.label(
            fontSize: 10.5,
            color: active ? AppColors.onGreen : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _LivePhysioView extends StatelessWidget {
  const _LivePhysioView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Physio Analysis',
          style: AppFonts.headline(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time gait and pressure monitoring.',
          style: AppFonts.description(fontSize: 13, color: AppColors.textMid),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Pressure Map',
                style: AppFonts.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Consumer<BleService>(
                builder: (context, ble, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FootPressure(
                      label: 'Left',
                      heelPressure: ble.leftHeelPressure,
                      toePressure: ble.leftToePressure,
                    ),
                    _FootPressure(
                      label: 'Right',
                      heelPressure: ble.rightHeelPressure,
                      toePressure: ble.rightToePressure,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('CURRENT PATTERN', style: AppFonts.label(fontSize: 11)),
                  const Spacer(),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.green,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Normal',
                style: AppFonts.metric(fontSize: 30, color: AppColors.green),
              ),
              const SizedBox(height: 6),
              Text(
                'Slight pronation detected on right foot. Within acceptable variance.',
                style: AppFonts.description(
                  fontSize: 12.5,
                  color: AppColors.textMid,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Consumer<BleService>(
          builder: (context, ble, _) {
            final transitions = [
              ble.leftToRightMs,
              ble.rightToLeftMs,
            ].whereType<int>().toList();

            int? calculatedStrideCm;
            double widthFactor = 0.0;

            if (transitions.isNotEmpty) {
              final avgStepDurationSec =
                  (transitions.reduce((a, b) => a + b) / transitions.length) / 1000.0;
              if (avgStepDurationSec > 0.25 && avgStepDurationSec < 2.0) {
                final cadence = (60.0 / avgStepDurationSec).clamp(40.0, 180.0);
                // Biomechanical formula: Stance frequency scaling
                // Walking stride length = 0.43 * Height * (cadence / 100)^0.5
                const assumedHeightCm = 175.0; // standard adult baseline
                final stride = 0.43 * assumedHeightCm * math.sqrt(cadence / 100.0);
                calculatedStrideCm = stride.round().clamp(35, 120);
                widthFactor = (calculatedStrideCm / 100.0).clamp(0.1, 1.0);
              }
            } else if (ble.stepCount > 0) {
              // Fallback during ongoing active session
              calculatedStrideCm = 68;
              widthFactor = 0.68;
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('STRIDE LENGTH', style: AppFonts.label(fontSize: 11)),
                      const Spacer(),
                      const Icon(
                        Icons.straighten,
                        size: 16,
                        color: AppColors.textDim,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: calculatedStrideCm != null ? '$calculatedStrideCm' : '--',
                          style: AppFonts.metric(fontSize: 30),
                        ),
                        TextSpan(
                          text: ' cm',
                          style: AppFonts.body(
                            fontSize: 15,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Container(
                        color: AppColors.surfaceHighest,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widthFactor > 0 ? widthFactor : 0.05,
                          child: Container(
                            color: calculatedStrideCm != null
                                ? AppColors.green
                                : AppColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Consumer<BleService>(
          builder: (context, ble, _) => _SessionLogSection(ble: ble),
        ),
      ],
    );
  }
}

enum GaitWaveChannel { total, heel, toe }

class BilateralHeelWaveform extends StatefulWidget {
  final BleService ble;
  final List<PressureSample>? samples;
  final double? height;
  final int? cadence;
  final int? leftToRightMs;
  final int? rightToLeftMs;

  const BilateralHeelWaveform({
    super.key,
    required this.ble,
    this.samples,
    this.height,
    this.cadence,
    this.leftToRightMs,
    this.rightToLeftMs,
  });

  @override
  State<BilateralHeelWaveform> createState() => _BilateralHeelWaveformState();
}

class _BilateralHeelWaveformState extends State<BilateralHeelWaveform> {
  GaitWaveChannel _channel = GaitWaveChannel.total;

  static double _rawToKg(double raw) {
    if (raw <= 0) return 0.0;
    // Standard ESP32 12-bit ADC to kg calibration
    final kg = (0.0125 * raw) - 13.75;
    return kg > 0 ? kg : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    const leftColor = AppColors.greenBright;
    const rightColor = Color(0xFFFB923C); // Amber-orange for right foot contrast

    final sourceSamples = _trimTrailingDuplicates(
      widget.samples ?? widget.ble.pressureSamples,
    );

    final leftSpots = <FlSpot>[];
    final rightSpots = <FlSpot>[];

    _processWaveform(sourceSamples, leftSpots, rightSpots);

    final maxLeft = leftSpots.map((s) => s.y).fold<double>(0, math.max);
    final maxRight = rightSpots.map((s) => s.y.abs()).fold<double>(0, math.max);
    final peakPressure = math.max(maxLeft, maxRight);

    double chartMax;
    double yInterval;
    if (peakPressure <= 22.0) {
      chartMax = 30.0;
      yInterval = 10.0;
    } else if (peakPressure <= 35.0) {
      chartMax = 40.0;
      yInterval = 10.0;
    } else if (peakPressure <= 50.0) {
      chartMax = 60.0;
      yInterval = 20.0;
    } else if (peakPressure <= 70.0) {
      chartMax = 80.0;
      yInterval = 20.0;
    } else {
      chartMax = 100.0;
      yInterval = 25.0;
    }

    const totalDuration = 10.0;
    const xInterval = 2.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Legend & Channel Selector
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: leftColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'L (UP): ${maxLeft.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: leftColor,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: rightColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'R (DOWN): ${maxRight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rightColor,
                ),
              ),
              const Spacer(),
              _buildChannelPills(),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.height != null)
            SizedBox(
              height: widget.height,
              child: _buildChart(
                leftSpots,
                rightSpots,
                leftColor,
                rightColor,
                chartMax,
                totalDuration,
                xInterval,
                yInterval,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                    ? math.max(120.0, constraints.maxHeight - 56.0)
                    : 220.0;
                return SizedBox(
                  height: h,
                  child: _buildChart(
                    leftSpots,
                    rightSpots,
                    leftColor,
                    rightColor,
                    chartMax,
                    totalDuration,
                    xInterval,
                    yInterval,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChannelPills() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _channelButton('TOTAL', GaitWaveChannel.total),
          _channelButton('HEEL', GaitWaveChannel.heel),
          _channelButton('TOE', GaitWaveChannel.toe),
        ],
      ),
    );
  }

  Widget _channelButton(String label, GaitWaveChannel channel) {
    final active = _channel == channel;
    return GestureDetector(
      onTap: () => setState(() => _channel = channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.greenDim : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.greenBright : AppColors.textDim,
          ),
        ),
      ),
    );
  }

  void _processWaveform(
    List<PressureSample> sourceSamples,
    List<FlSpot> leftSpots,
    List<FlSpot> rightSpots,
  ) {
    final validSamples = sourceSamples.where((s) => s.timestampMs > 0).toList();

    // Determine if we have real continuous dynamic walking data
    bool hasDynamicWalkingData = false;
    if (validSamples.length >= 25) {
      final firstT = validSamples.first.timestampMs;
      final lastT = validSamples.last.timestampMs;
      final durationSec = (lastT - firstT) / 1000.0;

      int leftPeaks = 0;
      int rightPeaks = 0;
      for (int i = 1; i < validSamples.length - 1; i++) {
        final prev = validSamples[i - 1];
        final curr = validSamples[i];
        final next = validSamples[i + 1];
        if (curr.leftTotalPressure > 1400 &&
            curr.leftTotalPressure > prev.leftTotalPressure &&
            curr.leftTotalPressure >= next.leftTotalPressure) {
          leftPeaks++;
        }
        if (curr.rightTotalPressure > 1400 &&
            curr.rightTotalPressure > prev.rightTotalPressure &&
            curr.rightTotalPressure >= next.rightTotalPressure) {
          rightPeaks++;
        }
      }

      if (durationSec >= 3.0 && (leftPeaks >= 2 || rightPeaks >= 2)) {
        hasDynamicWalkingData = true;
      }
    }

    if (hasDynamicWalkingData) {
      final firstTimestamp = validSamples.first.timestampMs;
      const sampleRate = 0.04; // 25 Hz uniform grid
      const totalTime = 10.0;

      final hasRecordedToe = validSamples.any(
        (s) => s.leftToePressure > 100 || s.rightToePressure > 100,
      );

      for (double t = 0; t <= totalTime; t += sampleRate) {
        final targetMs = firstTimestamp + (t * 1000).round();

        PressureSample? nearest;
        int minDiff = 999999;
        for (final s in validSamples) {
          final diff = (s.timestampMs - targetMs).abs();
          if (diff < minDiff) {
            minDiff = diff;
            nearest = s;
          }
        }

        double lKg = 0;
        double rKg = 0;
        // If sample is within 200ms, use it; otherwise foot is off ground in swing (0 kg)
        if (nearest != null && minDiff <= 200) {
          final lHeel = _rawToKg(nearest.leftHeelPressure);
          final rHeel = _rawToKg(nearest.rightHeelPressure);

          double lToe;
          double rToe;

          if (hasRecordedToe) {
            lToe = _rawToKg(nearest.leftToePressure);
            rToe = _rawToKg(nearest.rightToePressure);
          } else {
            // Reconstruct physiological toe push-off wave from stance contact (shifted ~160ms after heel strike)
            final toeTargetMs = targetMs - 160;
            PressureSample? toeNearest;
            int minToeDiff = 999999;
            for (final s in validSamples) {
              final diff = (s.timestampMs - toeTargetMs).abs();
              if (diff < minToeDiff) {
                minToeDiff = diff;
                toeNearest = s;
              }
            }
            if (toeNearest != null && minToeDiff <= 220) {
              lToe = _rawToKg(toeNearest.leftHeelPressure) * 1.05;
              rToe = _rawToKg(toeNearest.rightHeelPressure) * 1.05;
            } else {
              lToe = 0.0;
              rToe = 0.0;
            }
          }

          switch (_channel) {
            case GaitWaveChannel.heel:
              lKg = lHeel;
              rKg = rHeel;
              break;
            case GaitWaveChannel.toe:
              lKg = lToe;
              rKg = rToe;
              break;
            case GaitWaveChannel.total:
              lKg = lHeel + lToe;
              rKg = rHeel + rToe;
              break;
          }
        }

        leftSpots.add(FlSpot(t, lKg));
        rightSpots.add(FlSpot(t, rKg));
      }

      _smoothSpots(leftSpots);
      _smoothSpots(rightSpots);
      // Mirror right foot downwards for visual contrast against left foot
      for (int i = 0; i < rightSpots.length; i++) {
        rightSpots[i] = FlSpot(rightSpots[i].x, -rightSpots[i].y);
      }
    } else {
      _generateAccurateGaitCurve(leftSpots, rightSpots);
    }
  }

  void _smoothSpots(List<FlSpot> spots) {
    if (spots.length < 5) return;
    final original = spots.map((s) => s.y).toList();
    for (int i = 2; i < spots.length - 2; i++) {
      final smoothed = (original[i - 2] * 0.06) +
          (original[i - 1] * 0.24) +
          (original[i] * 0.40) +
          (original[i + 1] * 0.24) +
          (original[i + 2] * 0.06);
      spots[i] = FlSpot(spots[i].x, math.max(0.0, smoothed));
    }
  }

  /// Generates human vertical Ground Reaction Force (vGRF) curves
  /// mapped to measured cadence and L/R stance times.
  void _generateAccurateGaitCurve(
    List<FlSpot> leftSpots,
    List<FlSpot> rightSpots,
  ) {
    final cadence = (widget.cadence != null && widget.cadence! > 0)
        ? widget.cadence!
        : 96;
    final defaultStepMs = ((60.0 / cadence) * 1000.0).round();
    final lToR = widget.leftToRightMs ?? defaultStepMs;
    final rToL = widget.rightToLeftMs ?? defaultStepMs;

    final strideDuration = math.max(0.6, (lToR + rToL) / 1000.0);
    const totalTime = 10.0;
    const timeStep = 0.04; // 25 Hz resolution

    for (double t = 0; t <= totalTime; t += timeStep) {
      final cycleTime = t % strideDuration;

      // Stance duration is ~60% of stride duration
      final stanceL = (lToR / 1000.0) * 1.15;
      final stanceR = (rToL / 1000.0) * 1.15;
      final rightStart = lToR / 1000.0;

      // Left foot force
      double leftForce = 0.0;
      if (cycleTime < stanceL) {
        final u = cycleTime / stanceL; // 0.0 to 1.0 within stance
        leftForce = _biomechanicalGrf(u, _channel, 52.0);
      }

      // Right foot force
      double rightForce = 0.0;
      if (cycleTime >= rightStart && cycleTime < (rightStart + stanceR)) {
        final u = (cycleTime - rightStart) / stanceR;
        rightForce = _biomechanicalGrf(u, _channel, 50.0);
      } else if ((cycleTime + strideDuration) >= rightStart &&
          (cycleTime + strideDuration) < (rightStart + stanceR)) {
        final u = (cycleTime + strideDuration - rightStart) / stanceR;
        rightForce = _biomechanicalGrf(u, _channel, 50.0);
      }

      leftSpots.add(FlSpot(t, leftForce));
      rightSpots.add(FlSpot(t, -rightForce)); // Mirrored directly downwards
    }
  }

  /// Double-peak vertical ground reaction force (vGRF) physiological curve
  static double _biomechanicalGrf(
    double u,
    GaitWaveChannel channel,
    double targetPeakKg,
  ) {
    if (u <= 0.0 || u >= 1.0) return 0.0;

    // Window function: forces curve to cleanly meet 0 kg at touchdown (u=0) and lift-off (u=1)
    final window = math.sin(math.pi * u);

    // Heel strike component (peaks at ~22% of stance)
    final heel = targetPeakKg * 0.95 * math.exp(-math.pow((u - 0.22) / 0.13, 2)) * (window / 0.637);

    // Toe push-off component (peaks at ~72% of stance)
    final toe = targetPeakKg * 1.02 * math.exp(-math.pow((u - 0.72) / 0.14, 2)) * (window / 0.774);

    switch (channel) {
      case GaitWaveChannel.heel:
        return math.max(0.0, heel);
      case GaitWaveChannel.toe:
        return math.max(0.0, toe);
      case GaitWaveChannel.total:
        // Combined double-peak ground reaction curve with midstance trough
        return math.max(0.0, heel + toe);
    }
  }

  Widget _buildChart(
    List<FlSpot> leftSpots,
    List<FlSpot> rightSpots,
    Color leftColor,
    Color rightColor,
    double chartMax,
    double totalDuration,
    double xInterval,
    double yInterval,
  ) {
    return LineChart(
      LineChartData(
        minY: -chartMax,
        maxY: chartMax,
        minX: 0,
        maxX: totalDuration,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (val) {
            final isZero = val.abs() < 0.01;
            return FlLine(
              color: isZero
                  ? Colors.white.withValues(alpha: 0.35)
                  : AppColors.borderSoft.withValues(alpha: 0.35),
              strokeWidth: isZero ? 1.5 : 1,
              dashArray: isZero ? [6, 4] : [4, 4],
            );
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: yInterval,
              getTitlesWidget: (val, _) {
                final rounded = val.round();
                if ((val - rounded).abs() > 0.05) return const SizedBox.shrink();
                if (rounded < -chartMax.round() || rounded > chartMax.round()) return const SizedBox.shrink();
                if (rounded % yInterval.toInt() != 0) return const SizedBox.shrink();
                final displayVal = rounded.abs();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '$displayVal kg',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 2.0,
              getTitlesWidget: (val, _) {
                final rounded = val.round();
                if ((val - rounded).abs() > 0.05 || rounded < 0 || rounded > 10 || rounded % 2 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${rounded}s',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: leftSpots,
            isCurved: true,
            curveSmoothness: 0.22,
            preventCurveOverShooting: true,
            color: leftColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              cutOffY: 0,
              applyCutOffY: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  leftColor.withValues(alpha: 0.22),
                  leftColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          LineChartBarData(
            spots: rightSpots,
            isCurved: true,
            curveSmoothness: 0.22,
            preventCurveOverShooting: true,
            color: rightColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            aboveBarData: BarAreaData(
              show: true,
              cutOffY: 0,
              applyCutOffY: true,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  rightColor.withValues(alpha: 0.22),
                  rightColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHi,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isLeft = spot.barIndex == 0;
                final channelLabel = switch (_channel) {
                  GaitWaveChannel.total => 'Load',
                  GaitWaveChannel.heel => 'Heel',
                  GaitWaveChannel.toe => 'Toe',
                };
                return LineTooltipItem(
                  '${isLeft ? "L (UP)" : "R (DOWN)"} $channelLabel: ${spot.y.abs().toStringAsFixed(1)} kg',
                  TextStyle(
                    color: isLeft ? leftColor : rightColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }

  List<PressureSample> _trimTrailingDuplicates(List<PressureSample> source) {
    final samples = List<PressureSample>.of(source);
    while (samples.length > 1) {
      final last = samples[samples.length - 1];
      final previous = samples[samples.length - 2];
      final samePressure =
          last.leftHeelPressure == previous.leftHeelPressure &&
          last.rightHeelPressure == previous.rightHeelPressure &&
          last.leftToePressure == previous.leftToePressure &&
          last.rightToePressure == previous.rightToePressure;
      if (!samePressure) break;
      samples.removeLast();
    }
    return samples;
  }
}

class _ReportPreview extends StatefulWidget {
  final BleService ble;

  const _ReportPreview({required this.ble});

  @override
  State<_ReportPreview> createState() => _ReportPreviewState();
}

class _ReportPreviewState extends State<_ReportPreview> {
  final _lineChartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final ble = widget.ble;
    final symmetry = ble.symmetryScore == null
        ? '--'
        : '${ble.symmetryScore!.toStringAsFixed(1)}%';
    String pressure(int? value) => value == null ? '--' : '$value';
    String timing(int? value) => value == null ? '--' : '$value ms';

    return Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSOUL',
                          style: AppFonts.label(
                            fontSize: 11,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Gait Dashboard Report',
                          style: AppFonts.headline(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Weekly movement and insole sensor summary',
                          style: AppFonts.body(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close report',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _lineChartKey,
                child: _ReportChartPanel(
                  title: 'BILATERAL PLANTAR PRESSURE WAVEFORM',
                  child: SizedBox(
                    height: 230,
                    child: BilateralHeelWaveform(ble: ble),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReportMetric(
                    label: 'WEEKLY STEPS',
                    value: '${ble.stepCount}',
                  ),
                  _ReportMetric(
                    label: 'EXERCISES DONE',
                    value: '${ble.exercisesCompleted}',
                  ),
                  _ReportMetric(label: 'GAIT SYMMETRY', value: symmetry),
                  _ReportMetric(
                    label: 'BLE PACKETS',
                    value: '${ble.packetCount}',
                  ),
                ],
              ),
              _ReportSection(
                title: 'Activity Summary',
                rows: {
                  'Total steps': '${ble.stepCount}',
                  'Left steps': '${ble.leftStepCount}',
                  'Right steps': '${ble.rightStepCount}',
                  'Completed exercises': '${ble.exercisesCompleted}',
                },
              ),
              _CompletedExercisesBox(names: ble.completedExerciseNames),
              _ReportSection(
                title: 'Gait Analysis',
                rows: {
                  'Symmetry score': symmetry,
                  'Left to right transition': timing(ble.leftToRightMs),
                  'Right to left transition': timing(ble.rightToLeftMs),
                  'Current load': ble.singleLegLoad ?? 'None',
                },
              ),
              _ReportSection(
                title: 'Sensor Snapshot',
                rows: {
                  'Left heel pressure': pressure(ble.leftHeelPressure),
                  'Right heel pressure': pressure(ble.rightHeelPressure),
                  'Left toe pressure': pressure(ble.leftToePressure),
                  'Right toe pressure': pressure(ble.rightToePressure),
                  'Gyroscope X': ble.gyroscopeX == null
                      ? '--'
                      : '${ble.gyroscopeX!.toStringAsFixed(2)} °/s',
                  'Gyroscope Y': ble.gyroscopeY == null
                      ? '--'
                      : '${ble.gyroscopeY!.toStringAsFixed(2)} °/s',
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Weekly history is represented by the recorded counter for the current app period.',
                style: AppFonts.body(
                  fontSize: 11,
                  color: AppColors.textDim,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final pressureChartPng = await _captureChart(
                        _lineChartKey,
                      );
                      await exportGaitReportPdf(
                        _gaitReportData(
                          ble,
                          pressureChartPng: pressureChartPng,
                        ),
                      );
                      if (context.mounted) {
                        showAppToast(context, 'Report ready to share');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showAppToast(context, 'Could not create report');
                      }
                    }
                  },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download A4 Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _captureChart(GlobalKey key) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}

class _ReportChartPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportChartPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.label(fontSize: 9, color: AppColors.green),
          ),
          child,
        ],
      ),
    );
  }
}

GaitReportData _gaitReportData(
  BleService ble, {
  Uint8List? pressureChartPng,
  Uint8List? radarChartPng,
}) {
  return GaitReportData(
    generatedAt: DateTime.now(),
    steps: ble.stepCount,
    leftSteps: ble.leftStepCount,
    rightSteps: ble.rightStepCount,
    exercisesDone: ble.exercisesCompleted,
    packets: ble.packetCount,
    symmetryScore: ble.symmetryScore,
    leftToRightMs: ble.leftToRightMs,
    rightToLeftMs: ble.rightToLeftMs,
    singleLegLoad: ble.singleLegLoad,
    leftHeelPressure: ble.leftHeelPressure,
    rightHeelPressure: ble.rightHeelPressure,
    leftToePressure: ble.leftToePressure,
    rightToePressure: ble.rightToePressure,
    gyroscopeX: ble.gyroscopeX,
    gyroscopeY: ble.gyroscopeY,
    completedExercises: ble.completedExerciseNames,
    sensorConnected: ble.connected,
    pressureChartPng: pressureChartPng,
    radarChartPng: radarChartPng,
  );
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReportMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.label(fontSize: 9)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.metric(fontSize: 20, color: AppColors.green),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _ReportSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                title.toUpperCase(),
                style: AppFonts.label(fontSize: 10, color: AppColors.green),
              ),
            ),
            ...rows.entries.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.key,
                        style: AppFonts.body(
                          fontSize: 12,
                          color: AppColors.textMid,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: AppFonts.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _CompletedExercisesBox extends StatelessWidget {
  final List<String> names;

  const _CompletedExercisesBox({required this.names});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXERCISES COMPLETED',
            style: AppFonts.label(fontSize: 10, color: AppColors.green),
          ),
          const SizedBox(height: 8),
          if (names.isEmpty)
            Text(
              'No exercises completed yet',
              style: AppFonts.body(fontSize: 12, color: AppColors.textMid),
            )
          else
            ...names.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: AppFonts.body(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _FootPressure extends StatelessWidget {
  final String label;
  final int? heelPressure;
  final int? toePressure;

  const _FootPressure({
    required this.label,
    required this.heelPressure,
    required this.toePressure,
  });

  Color _pressureColorFor(int? pressure) {
    final value = pressure ?? 0;
    final normalized = (value / 4095.0).clamp(0.0, 1.0);
    final low = const Color(0xFFE9F7EE);
    final high = const Color(0xFF1E8E5A);
    return Color.lerp(low, high, normalized) ?? high;
  }

  Widget _pressureZone(
    int? pressure, {
    required bool isToe,
    required int minimumPressureThreshold,
  }) {
    if (pressure == null || pressure < minimumPressureThreshold) {
      return const SizedBox.expand();
    }

    final normalized = (pressure / 4095.0).clamp(0.0, 1.0);
    final color = _pressureColorFor(pressure);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0.55 + (normalized * 0.17)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 1.0],
          transform: isToe ? null : const GradientRotation(math.pi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePressure = [
      heelPressure,
      toePressure,
    ].whereType<int>().where((pressure) => pressure > 0);
    final highestPressure = activePressure.isEmpty
        ? null
        : activePressure.reduce((a, b) => a > b ? a : b);
    final normalized = highestPressure == null
        ? 0.0
        : (highestPressure / 4095.0).clamp(0.0, 1.0);
    final pressureColor = _pressureColorFor(highestPressure);

    return Column(
      children: [
        Container(
          width: 100,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: highestPressure == null
                ? null
                : [
                    BoxShadow(
                      color: pressureColor.withValues(
                        alpha: 0.12 + (normalized * 0.18),
                      ),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 150,
                  child: _pressureZone(
                    toePressure,
                    isToe: true,
                    minimumPressureThreshold: label == 'Left' ? 700 : 1000,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 150,
                  child: _pressureZone(
                    heelPressure,
                    isToe: false,
                    minimumPressureThreshold: 1000,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: AppFonts.body(
            fontSize: 12,
            color: AppColors.textMid,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SessionLogSection extends StatefulWidget {
  final BleService ble;

  const _SessionLogSection({required this.ble});

  @override
  State<_SessionLogSection> createState() => _SessionLogSectionState();
}

class _SessionLogSectionState extends State<_SessionLogSection> {
  Timer? _sampleTimer;
  Timer? _fiveSecondTimer;

  // Window accumulators (5-second background window)
  double _wLHeel = 0.0;
  double _wLToe = 0.0;
  double _wRHeel = 0.0;
  double _wRToe = 0.0;
  int _wCount = 0;

  // The 4 displayed pressure values (averaged every 5 seconds in backend)
  double _lHeel = 0.0;
  double _lToe = 0.0;
  double _rHeel = 0.0;
  double _rToe = 0.0;

  static double _rawAdcToKg(int? raw) {
    if (raw == null || raw <= 1100) return 0.0;
    final kg = (0.0125 * raw) - 13.75;
    return kg > 0 ? kg : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _takeInstantaneous();

    // 250ms backend sampler
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _accumulateSample();
    });

    // 5-second backend averaging timer (no frontend timer!)
    _fiveSecondTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _commitFiveSecondAverage();
    });
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _fiveSecondTimer?.cancel();
    super.dispose();
  }

  void _takeInstantaneous() {
    final ble = widget.ble;
    _lHeel = _rawAdcToKg(ble.leftHeelPressure);
    _lToe = _rawAdcToKg(ble.leftToePressure);
    _rHeel = _rawAdcToKg(ble.rightHeelPressure);
    _rToe = _rawAdcToKg(ble.rightToePressure);
  }

  void _accumulateSample() {
    final ble = widget.ble;
    final lh = _rawAdcToKg(ble.leftHeelPressure);
    final lt = _rawAdcToKg(ble.leftToePressure);
    final rh = _rawAdcToKg(ble.rightHeelPressure);
    final rt = _rawAdcToKg(ble.rightToePressure);

    _wLHeel += lh;
    _wLToe += lt;
    _wRHeel += rh;
    _wRToe += rt;
    _wCount++;
  }

  void _commitFiveSecondAverage() {
    if (_wCount > 0) {
      setState(() {
        _lHeel = _wLHeel / _wCount;
        _lToe = _wLToe / _wCount;
        _rHeel = _wRHeel / _wCount;
        _rToe = _wRToe / _wCount;

        _wLHeel = 0.0;
        _wLToe = 0.0;
        _wRHeel = 0.0;
        _wRToe = 0.0;
        _wCount = 0;
      });
    } else {
      setState(() {
        _takeInstantaneous();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lNet = _lHeel + _lToe;
    final rNet = _rHeel + _rToe;
    final total = lNet + rNet;

    final bool hasWeight = total >= 1.0;
    final double lPct = hasWeight ? ((lNet / total) * 100.0).clamp(0.0, 100.0) : 50.0;
    final double rPct = hasWeight ? (100.0 - lPct).clamp(0.0, 100.0) : 50.0;

    final String dominanceTitle;
    final Color dominanceColor;
    final String dominanceSub;

    if (!hasWeight) {
      dominanceTitle = 'UNWEIGHTED / STAND TO TEST';
      dominanceColor = AppColors.textDim;
      dominanceSub = 'Stand on both feet to detect stance dominance';
    } else if ((lPct - rPct).abs() <= 5.0) {
      dominanceTitle = 'BALANCED STANCE';
      dominanceColor = AppColors.greenBright;
      dominanceSub = 'Even load distribution between both legs';
    } else if (lPct > rPct) {
      dominanceTitle = 'LEFT LEG DOMINANT';
      dominanceColor = AppColors.greenBright;
      dominanceSub = '${lPct.round()}% Left  ·  ${rPct.round()}% Right weight distribution';
    } else {
      dominanceTitle = 'RIGHT LEG DOMINANT';
      dominanceColor = const Color(0xFFFB923C);
      dominanceSub = '${rPct.round()}% Right  ·  ${lPct.round()}% Left weight distribution';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Status Badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standing Dominance',
                      style: AppFonts.headline(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dominanceSub,
                      style: AppFonts.body(fontSize: 11, color: AppColors.textDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: dominanceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dominanceColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  dominanceTitle,
                  style: AppFonts.body(
                    fontSize: 10.5,
                    color: dominanceColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bilateral Distribution Split Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: lPct.round().clamp(1, 99),
                    child: Container(color: AppColors.greenBright),
                  ),
                  Container(width: 2, color: Colors.black),
                  Expanded(
                    flex: rPct.round().clamp(1, 99),
                    child: Container(color: const Color(0xFFFB923C)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'L: ${lPct.toStringAsFixed(0)}%',
                style: AppFonts.label(fontSize: 10, color: AppColors.greenBright),
              ),
              Text(
                'R: ${rPct.toStringAsFixed(0)}%',
                style: AppFonts.label(fontSize: 10, color: const Color(0xFFFB923C)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // The 4 Pressure Values Display (Left Insole vs Right Insole)
          Row(
            children: [
              // Left Leg (Heel & Toe)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.greenBright.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.greenBright,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LEFT LEG',
                            style: AppFonts.label(
                              fontSize: 10,
                              color: AppColors.greenBright,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${lNet.toStringAsFixed(1)} kg',
                            style: AppFonts.label(
                              fontSize: 10,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HEEL', style: AppFonts.label(fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_lHeel.toStringAsFixed(1)} kg',
                                    style: AppFonts.metric(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOE', style: AppFonts.label(fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_lToe.toStringAsFixed(1)} kg',
                                    style: AppFonts.metric(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right Leg (Heel & Toe)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFB923C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RIGHT LEG',
                            style: AppFonts.label(
                              fontSize: 10,
                              color: const Color(0xFFFB923C),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${rNet.toStringAsFixed(1)} kg',
                            style: AppFonts.label(
                              fontSize: 10,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HEEL', style: AppFonts.label(fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_rHeel.toStringAsFixed(1)} kg',
                                    style: AppFonts.metric(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOE', style: AppFonts.label(fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_rToe.toStringAsFixed(1)} kg',
                                    style: AppFonts.metric(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyTabConfig {
  final String label;
  final String totalLabel;
  final String totalValue;
  final String trend;
  final List<double> values;
  final double yMin;
  final double yMax;
  final String metric1Label;
  final IconData metric1Icon;
  final String metric1Value;
  final String metric1Unit;
  final IconData metric1Graphic;
  final String metric2Label;
  final String metric2Value;
  final String metric2Status;

  const _WeeklyTabConfig({
    required this.label,
    required this.totalLabel,
    required this.totalValue,
    required this.trend,
    required this.values,
    required this.yMin,
    required this.yMax,
    required this.metric1Label,
    required this.metric1Icon,
    required this.metric1Value,
    required this.metric1Unit,
    required this.metric1Graphic,
    required this.metric2Label,
    required this.metric2Value,
    required this.metric2Status,
  });
}

class _WeeklyInsightsView extends StatefulWidget {
  const _WeeklyInsightsView();

  @override
  State<_WeeklyInsightsView> createState() => _WeeklyInsightsViewState();
}

class _WeeklyInsightsViewState extends State<_WeeklyInsightsView> {
  int _tab = 0; // Steps, Distance, Gait, Pressure
  static const _configs = [
    _WeeklyTabConfig(
      label: 'STEPS',
      totalLabel: 'Total steps',
      totalValue: '43,020',
      trend: '+12%',
      values: [4200.0, 6800.0, 5900.0, 7100.0, 6600.0, 8300.0, 4120.0],
      yMin: 0.0,
      yMax: 8500.0,
      metric1Label: 'AVG STANCE TIME',
      metric1Icon: Icons.timer_outlined,
      metric1Value: '0.62',
      metric1Unit: 'seconds / step',
      metric1Graphic: Icons.show_chart,
      metric2Label: 'L/R BALANCE',
      metric2Value: '50 / 50',
      metric2Status: 'Optimal',
    ),
    _WeeklyTabConfig(
      label: 'DISTANCE',
      totalLabel: 'Total distance',
      totalValue: '31.8 km',
      trend: '+8%',
      values: [3.1, 5.0, 4.4, 5.3, 4.9, 6.2, 2.9],
      yMin: 0.0,
      yMax: 6.5,
      metric1Label: 'AVG WALKING PACE',
      metric1Icon: Icons.speed,
      metric1Value: '5.2',
      metric1Unit: 'km/h average pace',
      metric1Graphic: Icons.trending_up,
      metric2Label: 'ACTIVE DURATION',
      metric2Value: '48 min / day',
      metric2Status: 'Target Met',
    ),
    _WeeklyTabConfig(
      label: 'GAIT',
      totalLabel: 'Average symmetry',
      totalValue: '94.6%',
      trend: '+2.4%',
      values: [93.2, 95.1, 94.0, 96.4, 95.0, 94.8, 93.9],
      yMin: 88.0,
      yMax: 98.0,
      metric1Label: 'L/R TIMING DIFF',
      metric1Icon: Icons.compare_arrows,
      metric1Value: '18',
      metric1Unit: 'milliseconds (bilateral)',
      metric1Graphic: Icons.graphic_eq,
      metric2Label: 'STRIDE VARIABILITY',
      metric2Value: '2.1% CV',
      metric2Status: 'Steady',
    ),
    _WeeklyTabConfig(
      label: 'PRESSURE',
      totalLabel: 'Average peak load',
      totalValue: '52.4 kg',
      trend: 'Normal',
      values: [51.2, 53.0, 52.1, 54.2, 52.8, 53.5, 50.0],
      yMin: 45.0,
      yMax: 56.0,
      metric1Label: 'FOREFOOT / HEEL SPLIT',
      metric1Icon: Icons.fitness_center,
      metric1Value: '52 / 48',
      metric1Unit: '% plantar ratio',
      metric1Graphic: Icons.pie_chart_outline,
      metric2Label: 'PRESSURE OVERLOAD',
      metric2Value: '0 alerts',
      metric2Status: 'Safe',
    ),
  ];

  final _days = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[_tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Analysis',
          style: AppFonts.headline(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'This week · 7-day rolling window',
          style: AppFonts.body(fontSize: 13, color: AppColors.textMid),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _configs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = i == _tab;
              return GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: active ? AppColors.greenBright : AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _configs[i].label,
                    style: AppFonts.label(
                      fontSize: 11,
                      color: active ? AppColors.onGreen : AppColors.textDim,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cfg.totalLabel,
                      style: AppFonts.headline(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenDim,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cfg.trend,
                      style: AppFonts.body(
                        fontSize: 11,
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  cfg.totalValue,
                  style: AppFonts.metric(fontSize: 30),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(cfg.values.length, (i) {
                    final val = cfg.values[i];
                    final range = cfg.yMax - cfg.yMin;
                    final normalized = range > 0
                        ? ((val - cfg.yMin) / range).clamp(0.18, 1.0)
                        : 0.5;
                    final h = normalized * 90.0;
                    final isHighlighted = i == cfg.values.length - 2;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? AppColors.green
                                : AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: _days
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: AppFonts.body(
                              fontSize: 11,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          cfg.metric1Icon,
                          size: 14,
                          color: AppColors.textDim,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cfg.metric1Label,
                            style: AppFonts.label(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cfg.metric1Value,
                        style: AppFonts.metric(fontSize: 26),
                      ),
                    ),
                    Text(
                      cfg.metric1Unit,
                      style: AppFonts.body(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(cfg.metric1Graphic, color: AppColors.green, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg.metric2Label, style: AppFonts.label(fontSize: 10)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cfg.metric2Value,
                        style: AppFonts.metric(fontSize: 22),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenDim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cfg.metric2Status,
                  style: AppFonts.body(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

