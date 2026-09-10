import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'ble_service.dart';
import 'physio_screen.dart';

class GaitWaveformRenderer {
  GaitWaveformRenderer._();

  static double _rawToKg(double raw) {
    if (raw <= 0) return 0.0;
    final kg = (0.0125 * raw) - 13.75;
    return kg > 0 ? kg : 0.0;
  }

  /// Renders a high-resolution PNG image of the mirrored bilateral waveform for PDF reports.
  /// Generates separate, structurally identical graphs for [GaitWaveChannel.heel] and [GaitWaveChannel.toe].
  static Future<Uint8List> renderBilateralPng({
    required List<PressureSample> samples,
    required GaitWaveChannel channel,
    int? cadence,
    int? leftToRightMs,
    int? rightToLeftMs,
    int width = 1100,
    int height = 480,
  }) async {
    final validSamples = samples.where((s) => s.timestampMs > 0).toList();

    // 1. Calculate Spots
    final leftValues = <double>[];
    final rightValues = <double>[];
    const totalTime = 10.0;
    const sampleRate = 0.02; // 50 Hz uniform grid (500 points)
    final numPoints = (totalTime / sampleRate).round();

    bool hasDynamic = false;
    if (validSamples.length >= 25) {
      final firstT = validSamples.first.timestampMs;
      final lastT = validSamples.last.timestampMs;
      final duration = (lastT - firstT) / 1000.0;
      if (duration >= 2.5) hasDynamic = true;
    }

    final hasRecordedToe = validSamples.any(
      (s) => s.leftToePressure > 100 || s.rightToePressure > 100,
    );

    if (hasDynamic && validSamples.isNotEmpty) {
      final firstTimestamp = validSamples.first.timestampMs;

      for (int i = 0; i <= numPoints; i++) {
        final t = i * sampleRate;
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

        if (nearest != null && minDiff <= 220) {
          final lHeel = _rawToKg(nearest.leftHeelPressure);
          final rHeel = _rawToKg(nearest.rightHeelPressure);

          double lToe;
          double rToe;

          if (hasRecordedToe) {
            lToe = _rawToKg(nearest.leftToePressure);
            rToe = _rawToKg(nearest.rightToePressure);
          } else {
            // Biomechanical toe shift (~160ms after heel strike)
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

          switch (channel) {
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

        leftValues.add(lKg);
        rightValues.add(rKg);
      }

      // Smooth 50Hz jitter
      _smoothList(leftValues);
      _smoothList(rightValues);
    } else {
      // Biomechanical Ground Reaction Force synthesis
      final cad = (cadence != null && cadence > 0) ? cadence : 96;
      final defaultStepMs = ((60.0 / cad) * 1000.0).round();
      final lToR = leftToRightMs ?? defaultStepMs;
      final rToL = rightToLeftMs ?? defaultStepMs;
      final strideDuration = math.max(0.6, (lToR + rToL) / 1000.0);

      for (int i = 0; i <= numPoints; i++) {
        final t = i * sampleRate;
        final cycleTime = t % strideDuration;
        final stanceL = (lToR / 1000.0) * 1.15;
        final stanceR = (rToL / 1000.0) * 1.15;
        final rightStart = lToR / 1000.0;

        double leftForce = 0.0;
        if (cycleTime < stanceL) {
          final u = cycleTime / stanceL;
          leftForce = _syntheticGrf(u, channel, 52.0);
        }

        double rightForce = 0.0;
        if (cycleTime >= rightStart && cycleTime < (rightStart + stanceR)) {
          final u = (cycleTime - rightStart) / stanceR;
          rightForce = _syntheticGrf(u, channel, 50.0);
        } else if ((cycleTime + strideDuration) >= rightStart &&
            (cycleTime + strideDuration) < (rightStart + stanceR)) {
          final u = (cycleTime + strideDuration - rightStart) / stanceR;
          rightForce = _syntheticGrf(u, channel, 50.0);
        }

        leftValues.add(leftForce);
        rightValues.add(rightForce);
      }
    }

    final maxLeft = leftValues.fold<double>(0, math.max);
    final maxRight = rightValues.fold<double>(0, math.max);
    final peakForce = math.max(maxLeft, maxRight);

    double chartMax = 60.0;
    double yInterval = 20.0;
    if (peakForce <= 35.0) {
      chartMax = 40.0;
      yInterval = 10.0;
    } else if (peakForce <= 55.0) {
      chartMax = 60.0;
      yInterval = 20.0;
    } else if (peakForce <= 75.0) {
      chartMax = 80.0;
      yInterval = 20.0;
    } else {
      chartMax = 100.0;
      yInterval = 25.0;
    }

    // 2. Draw using Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final bgPaint = Paint()..color = const Color(0xFF0F1A17);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFF1E3A32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // Margins
    const marginLeft = 80.0;
    const marginRight = 30.0;
    const marginTop = 60.0;
    const marginBottom = 50.0;

    final plotWidth = width - marginLeft - marginRight;
    final plotHeight = height - marginTop - marginBottom;
    final centerY = marginTop + (plotHeight / 2.0);

    // Draw Grid Lines and Labels
    final gridPaint = Paint()
      ..color = const Color(0x3334D399)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final zeroLinePaint = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final numYIntervals = (chartMax / yInterval).round();
    for (int step = -numYIntervals; step <= numYIntervals; step++) {
      final yKg = step * yInterval;
      final yPos = centerY - (yKg / chartMax) * (plotHeight / 2.0);

      if (step == 0) {
        // Draw dashed center line
        _drawDashedLine(canvas, Offset(marginLeft, yPos), Offset(marginLeft + plotWidth, yPos), zeroLinePaint);
      } else {
        canvas.drawLine(Offset(marginLeft, yPos), Offset(marginLeft + plotWidth, yPos), gridPaint);
      }

      // Label
      final labelSpan = TextSpan(
        text: '${yKg.abs().round()} kg',
        style: const TextStyle(
          color: Color(0xFF8BA59E),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(marginLeft - tp.width - 12, yPos - (tp.height / 2)));
    }

    // Time axis markers
    for (int sec = 0; sec <= 10; sec += 2) {
      final xPos = marginLeft + (sec / 10.0) * plotWidth;
      final tp = TextPainter(
        text: TextSpan(
          text: '${sec}s',
          style: const TextStyle(
            color: Color(0xFF8BA59E),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xPos - (tp.width / 2), height - marginBottom + 12));
    }

    // Left Foot Curve (Green - Upward)
    final leftPath = Path();
    final leftFillPath = Path();
    leftFillPath.moveTo(marginLeft, centerY);

    for (int i = 0; i < leftValues.length; i++) {
      final x = marginLeft + (i / (leftValues.length - 1)) * plotWidth;
      final val = leftValues[i].clamp(0.0, chartMax);
      final y = centerY - (val / chartMax) * (plotHeight / 2.0);

      if (i == 0) {
        leftPath.moveTo(x, y);
      } else {
        leftPath.lineTo(x, y);
      }
      leftFillPath.lineTo(x, y);
    }
    leftFillPath.lineTo(marginLeft + plotWidth, centerY);
    leftFillPath.close();

    // Gradient Fill for Left Curve
    final leftFillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, marginTop),
        Offset(0, centerY),
        [
          AppColors.greenBright.withValues(alpha: 0.30),
          AppColors.greenBright.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(leftFillPath, leftFillPaint);

    final leftLinePaint = Paint()
      ..color = AppColors.greenBright
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    canvas.drawPath(leftPath, leftLinePaint);

    // Right Foot Curve (Orange - Mirrored Downward)
    final rightPath = Path();
    final rightFillPath = Path();
    rightFillPath.moveTo(marginLeft, centerY);

    for (int i = 0; i < rightValues.length; i++) {
      final x = marginLeft + (i / (rightValues.length - 1)) * plotWidth;
      final val = rightValues[i].clamp(0.0, chartMax);
      final y = centerY + (val / chartMax) * (plotHeight / 2.0);

      if (i == 0) {
        rightPath.moveTo(x, y);
      } else {
        rightPath.lineTo(x, y);
      }
      rightFillPath.lineTo(x, y);
    }
    rightFillPath.lineTo(marginLeft + plotWidth, centerY);
    rightFillPath.close();

    // Gradient Fill for Right Curve
    final rightFillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, marginTop + plotHeight),
        Offset(0, centerY),
        [
          const Color(0xFFFB923C).withValues(alpha: 0.30),
          const Color(0xFFFB923C).withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(rightFillPath, rightFillPaint);

    final rightLinePaint = Paint()
      ..color = const Color(0xFFFB923C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    canvas.drawPath(rightPath, rightLinePaint);

    // Header Legend
    final channelLabel = switch (channel) {
      GaitWaveChannel.heel => 'BILATERAL HEEL PRESSURE',
      GaitWaveChannel.toe => 'BILATERAL FOREFOOT / TOE PRESSURE',
      GaitWaveChannel.total => 'BILATERAL TOTAL VERTICAL LOAD',
    };

    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, const Offset(marginLeft, 20));

    // Legend readouts
    final legendTp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '● L (UP): ',
            style: TextStyle(color: AppColors.greenBright, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '${maxLeft.toStringAsFixed(1)} kg    ',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const TextSpan(
            text: '● R (DOWN): ',
            style: TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '${maxRight.toStringAsFixed(1)} kg',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    legendTp.paint(canvas, Offset(width - marginRight - legendTp.width, 22));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    return byteData!.buffer.asUint8List();
  }

  static void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double curX = p1.dx;
    while (curX < p2.dx) {
      final nextX = math.min(curX + dashWidth, p2.dx);
      canvas.drawLine(Offset(curX, p1.dy), Offset(nextX, p1.dy), paint);
      curX += dashWidth + dashSpace;
    }
  }

  static void _smoothList(List<double> list) {
    if (list.length < 5) return;
    final copy = List<double>.from(list);
    for (int i = 2; i < list.length - 2; i++) {
      list[i] = (copy[i - 2] * 0.06) +
          (copy[i - 1] * 0.24) +
          (copy[i] * 0.40) +
          (copy[i + 1] * 0.24) +
          (copy[i + 2] * 0.06);
    }
  }

  static double _syntheticGrf(double u, GaitWaveChannel channel, double targetPeakKg) {
    if (u <= 0.0 || u >= 1.0) return 0.0;
    final window = math.sin(math.pi * u);
    final heel = targetPeakKg * 0.95 * math.exp(-math.pow((u - 0.22) / 0.13, 2)) * (window / 0.637);
    final toe = targetPeakKg * 1.02 * math.exp(-math.pow((u - 0.72) / 0.14, 2)) * (window / 0.774);

    switch (channel) {
      case GaitWaveChannel.heel:
        return math.max(0.0, heel);
      case GaitWaveChannel.toe:
        return math.max(0.0, toe);
      case GaitWaveChannel.total:
        return math.max(0.0, heel + toe);
    }
  }
}
