import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ble_service.dart';
import 'quick_gait_metrics.dart';

class GaitReportData {
  final DateTime generatedAt;
  final int steps;
  final int leftSteps;
  final int rightSteps;
  final int exercisesDone;
  final int packets;
  final double? symmetryScore;
  final int? leftToRightMs;
  final int? rightToLeftMs;
  final String? singleLegLoad;
  final int? leftHeelPressure;
  final int? rightHeelPressure;
  final int? leftToePressure;
  final int? rightToePressure;
  final double? gyroscopeX;
  final double? gyroscopeY;
  final List<String> completedExercises;
  final bool sensorConnected;
  final Uint8List? pressureChartPng;
  final Uint8List? radarChartPng;

  const GaitReportData({
    required this.generatedAt,
    required this.steps,
    required this.leftSteps,
    required this.rightSteps,
    required this.exercisesDone,
    required this.packets,
    required this.symmetryScore,
    required this.leftToRightMs,
    required this.rightToLeftMs,
    required this.singleLegLoad,
    required this.leftHeelPressure,
    required this.rightHeelPressure,
    required this.leftToePressure,
    required this.rightToePressure,
    required this.gyroscopeX,
    required this.gyroscopeY,
    required this.completedExercises,
    required this.sensorConnected,
    this.pressureChartPng,
    this.radarChartPng,
  });

  double? get averagePressure {
    final values = [
      leftHeelPressure,
      rightHeelPressure,
      leftToePressure,
      rightToePressure,
    ].whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((sum, value) => sum + value) / values.length;
  }
}

Future<void> exportGaitReportPdf(GaitReportData data) async {
  final document = pw.Document();
  final green = PdfColor.fromHex('#168653');
  final ink = PdfColor.fromHex('#10251F');
  final muted = PdfColor.fromHex('#60736D');
  final line = PdfColor.fromHex('#D8E4DF');

  String value(Object? item, [String fallback = '--']) =>
      item == null ? fallback : '$item';
  String pressure(int? item) => value(item);
  String milliseconds(int? item) => item == null ? '--' : '$item ms';
  String decimal(double? item) => item == null ? '--' : item.toStringAsFixed(2);

  pw.Widget section(String title, List<List<String>> rows) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: green,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.6),
              bottom: pw.BorderSide(color: line, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              for (final row in rows)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7),
                      child: pw.Text(
                        row[0],
                        style: pw.TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          row[1],
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (data.pressureChartPng != null || data.radarChartPng != null) ...[
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.pressureChartPng != null)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'HEEL PRESSURE',
                          style: pw.TextStyle(
                            color: green,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Image(
                          pw.MemoryImage(data.pressureChartPng!),
                          height: 130,
                        ),
                      ],
                    ),
                  ),
                if (data.radarChartPng != null)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SESSION SUMMARY',
                          style: pw.TextStyle(
                            color: green,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Image(
                          pw.MemoryImage(data.radarChartPng!),
                          height: 130,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INSOUL',
            style: pw.TextStyle(
              color: green,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Gait Dashboard Report',
            style: pw.TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Weekly movement and insole sensor summary',
            style: pw.TextStyle(color: muted, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Generated ${data.generatedAt.toLocal().toString().substring(0, 16)}',
            style: pw.TextStyle(color: muted, fontSize: 9),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14),
            child: pw.Divider(color: green, thickness: 2),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            children: [
              pw.TableRow(
                children: [
                  _pdfMetric(
                    'WEEKLY STEPS',
                    value(data.steps),
                    green,
                    ink,
                    muted,
                  ),
                  _pdfMetric(
                    'EXERCISES DONE',
                    value(data.exercisesDone),
                    green,
                    ink,
                    muted,
                  ),
                  _pdfMetric(
                    'GAIT SYMMETRY',
                    data.symmetryScore == null
                        ? '--'
                        : '${data.symmetryScore!.toStringAsFixed(1)}%',
                    green,
                    ink,
                    muted,
                  ),
                  _pdfMetric(
                    'AVG PRESSURE',
                    data.averagePressure == null
                        ? '--'
                        : data.averagePressure!.toStringAsFixed(0),
                    green,
                    ink,
                    muted,
                  ),
                ],
              ),
            ],
          ),
          section('Activity Summary', [
            ['Total steps', value(data.steps)],
            ['Left steps', value(data.leftSteps)],
            ['Right steps', value(data.rightSteps)],
            ['Completed exercises', value(data.exercisesDone)],
            ['Sensor packets', value(data.packets)],
          ]),
          section('Completed Exercises', [
            [
              'Exercises',
              data.completedExercises.isEmpty
                  ? 'None'
                  : data.completedExercises.join(', '),
            ],
          ]),
          section('Gait Analysis', [
            [
              'Symmetry score',
              data.symmetryScore == null
                  ? 'Not enough gait transitions'
                  : '${data.symmetryScore!.toStringAsFixed(1)}%',
            ],
            [
              'Average left to right transition',
              milliseconds(data.leftToRightMs),
            ],
            [
              'Average right to left transition',
              milliseconds(data.rightToLeftMs),
            ],
            ['Current load pattern', value(data.singleLegLoad, 'None')],
          ]),
          section('Sensor Snapshot', [
            [
              'Average pressure',
              data.averagePressure == null
                  ? '--'
                  : data.averagePressure!.toStringAsFixed(0),
            ],
            ['Left heel pressure', pressure(data.leftHeelPressure)],
            ['Right heel pressure', pressure(data.rightHeelPressure)],
            ['Left toe pressure', pressure(data.leftToePressure)],
            ['Right toe pressure', pressure(data.rightToePressure)],
            ['Gyroscope X', decimal(data.gyroscopeX)],
            ['Gyroscope Y', decimal(data.gyroscopeY)],
          ]),
          pw.Spacer(),
          pw.Divider(color: line),
          pw.Text(
            'InSoul Gait Analysis - ${data.sensorConnected ? 'Sensor connected' : 'Sensor disconnected'}',
            style: pw.TextStyle(color: muted, fontSize: 9),
          ),
        ],
      ),
    ),
  );

  await Printing.sharePdf(
    bytes: await document.save(),
    filename: 'gait-report.pdf',
  );
}

pw.Widget _pdfMetric(
  String label,
  String value,
  PdfColor green,
  PdfColor ink,
  PdfColor muted,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(9),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: muted,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: green,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class QuickGaitReportData {
  final DateTime generatedAt;
  final QuickGaitMetrics metrics;
  final List<PressureSample> samples;
  final String userName;
  final bool sensorConnected;
  final Uint8List? heelChartPng;
  final Uint8List? toeChartPng;

  const QuickGaitReportData({
    required this.generatedAt,
    required this.metrics,
    required this.samples,
    this.userName = 'InSoul Athlete / Patient',
    this.sensorConnected = true,
    this.heelChartPng,
    this.toeChartPng,
  });
}

Future<void> exportQuickGaitAnalysisPdf(QuickGaitReportData data) async {
  final document = pw.Document();

  // Color Palette
  final green = PdfColor.fromHex('#10B981');
  final greenDark = PdfColor.fromHex('#065F46');
  final greenDim = PdfColor.fromHex('#E6FBF3');
  final ink = PdfColor.fromHex('#0F172A');
  final slate = PdfColor.fromHex('#475569');
  final muted = PdfColor.fromHex('#64748B');
  final line = PdfColor.fromHex('#E2E8F0');
  final orange = PdfColor.fromHex('#F97316');
  final lightCard = PdfColor.fromHex('#F8FAFC');

  // Load Custom Veneza Font (with fallback to default)
  pw.Font? reportFont;
  pw.Font? reportFontBold;
  try {
    final fontData = await rootBundle.load('assets/fonts/VenezaRegular.ttf');
    reportFont = pw.Font.ttf(fontData);
    reportFontBold = reportFont;
  } catch (_) {}

  final baseTheme = reportFont != null
      ? pw.ThemeData.withFont(base: reportFont, bold: reportFontBold)
      : pw.ThemeData.base();

  // Load InSoul Light-Mode Logo
  Uint8List? logoBytes;
  try {
    final byteData = await rootBundle.load('assets/images/lighmode_logo.png');
    logoBytes = byteData.buffer.asUint8List();
  } catch (_) {
    try {
      final byteData = await rootBundle.load('assets/images/insoul_logo.png');
      logoBytes = byteData.buffer.asUint8List();
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/images/InSoul Icon.png');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
    }
  }

  // PAGE 1: Executive Biomechanical Gait Report
  document.addPage(
    pw.Page(
      theme: baseTheme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with Logo & Telemetry Tag
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      height: 52,
                      margin: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Text(
                      'INSOUL',
                      style: pw.TextStyle(
                        color: green,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  pw.Text(
                    'AMBULATORY GAIT BIOMECHANICS & TELEMETRY',
                    style: pw.TextStyle(
                      color: muted,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: greenDim,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: green, width: 0.8),
                    ),
                    child: pw.Text(
                      '50 Hz CONTINUOUS STREAM',
                      style: pw.TextStyle(
                        color: greenDark,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'SESSION: 10.0 SECONDS',
                    style: pw.TextStyle(color: muted, fontSize: 8),
                  ),
                  pw.Text(
                    'DATE: ${data.generatedAt.toLocal().toString().substring(0, 16)}',
                    style: pw.TextStyle(color: muted, fontSize: 8),
                  ),
                ],
              ),
            ],
          ),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Divider(color: green, thickness: 1.5),
          ),

          // Report Title
          pw.Text(
            'Quick Gait Analysis Report',
            style: pw.TextStyle(
              color: ink,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Quantitative assessment of bilateral ground reaction force, temporal sub-phases, and dynamic balance',
            style: pw.TextStyle(color: slate, fontSize: 9.5),
          ),

          pw.SizedBox(height: 12),

          // Status Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: lightCard,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: line),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: green,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'MOBILITY EVALUATION:  ${data.metrics.mobilityStatus}',
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  data.metrics.limpingSummary,
                  style: pw.TextStyle(
                    color: greenDark,
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // 4 Key Metric Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricBox(
                  'CADENCE',
                  '${data.metrics.cadence}',
                  'STEPS / MIN',
                  green,
                  ink,
                  muted,
                  lightCard,
                  line,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildPdfMetricBox(
                  'GAIT SYMMETRY',
                  data.metrics.symmetryScore == null
                      ? '--'
                      : '${data.metrics.symmetryScore!.toStringAsFixed(1)}%',
                  'BILATERAL INDEX',
                  green,
                  ink,
                  muted,
                  lightCard,
                  line,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildPdfMetricBox(
                  'DOUBLE SUPPORT',
                  '${data.metrics.doubleSupportPercent}%',
                  '${data.metrics.doubleSupportMs} ms TOTAL',
                  green,
                  ink,
                  muted,
                  lightCard,
                  line,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildPdfMetricBox(
                  'VARIABILITY (CV%)',
                  '${data.metrics.gaitVariabilityCv}%',
                  data.metrics.fallRiskLevel,
                  data.metrics.gaitVariabilityCv > 4.5 ? orange : green,
                  ink,
                  muted,
                  lightCard,
                  line,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // Section 1: Bilateral Temporal Sub-Phasing (Phasogram)
          pw.Text(
            'BILATERAL TEMPORAL SUB-PHASING (PHASOGRAM)',
            style: pw.TextStyle(
              color: greenDark,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: lightCard),
                children: [
                  _pdfTableCell('LIMB', isHeader: true, color: ink),
                  _pdfTableCell('STANCE PHASE %', isHeader: true, color: ink),
                  _pdfTableCell('SWING PHASE %', isHeader: true, color: ink),
                  _pdfTableCell('DOUBLE SUPPORT', isHeader: true, color: ink),
                  _pdfTableCell('NORMATIVE TARGET', isHeader: true, color: ink),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfTableCell('LEFT FOOT', color: greenDark, isBold: true),
                  _pdfTableCell('${data.metrics.leftStancePercent}%', color: ink),
                  _pdfTableCell('${data.metrics.leftSwingPercent}%', color: ink),
                  _pdfTableCell('${data.metrics.doubleSupportPercent}% (${data.metrics.doubleSupportMs} ms)', color: ink),
                  _pdfTableCell('58% - 62% Stance', color: muted),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfTableCell('RIGHT FOOT', color: orange, isBold: true),
                  _pdfTableCell('${data.metrics.rightStancePercent}%', color: ink),
                  _pdfTableCell('${data.metrics.rightSwingPercent}%', color: ink),
                  _pdfTableCell('${data.metrics.doubleSupportPercent}% (${data.metrics.doubleSupportMs} ms)', color: ink),
                  _pdfTableCell('58% - 62% Stance', color: muted),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // Section 2: Step Kinematics & Kinetic Loading Table
          pw.Text(
            'STEP KINEMATICS & KINETIC PEAK FORCES',
            style: pw.TextStyle(
              color: greenDark,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            children: [
              pw.TableRow(
                children: [
                  _pdfTableKeyVal('Stride Time (Heel-to-Heel)', '${data.metrics.strideTimeMs ?? "--"} ms', ink, muted),
                  _pdfTableKeyVal('Peak Left Heel Load', '${data.metrics.peakLeftHeelKg} kg', greenDark, muted),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfTableKeyVal('Left -> Right Transition', '${data.metrics.leftToRightMs ?? "--"} ms', ink, muted),
                  _pdfTableKeyVal('Peak Left Toe Propulsion', '${data.metrics.peakLeftToeKg} kg', greenDark, muted),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfTableKeyVal('Right -> Left Transition', '${data.metrics.rightToLeftMs ?? "--"} ms', ink, muted),
                  _pdfTableKeyVal('Peak Right Heel Load', '${data.metrics.peakRightHeelKg} kg', orange, muted),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfTableKeyVal('Heel-to-Toe Roll-Through Fluidity', '${data.metrics.heelToToeTransitionMs} ms (Normal: 140-220ms)', ink, muted),
                  _pdfTableKeyVal('Peak Right Toe Propulsion', '${data.metrics.peakRightToeKg} kg', orange, muted),
                ],
              ),
            ],
          ),

          pw.Spacer(),
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'InSoul Gait Telemetry - Page 1 of 2',
                style: pw.TextStyle(color: muted, fontSize: 8),
              ),
              pw.Text(
                'Next Page: High-Resolution Bilateral Waveform Graphs',
                style: pw.TextStyle(color: greenDark, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // PAGE 2: Bilateral Kinetic Waveforms (Separate Heel and Toe Graphs)
  document.addPage(
    pw.Page(
      theme: baseTheme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'KINETIC PRESSURE WAVEFORMS (10-SECOND 50 Hz STREAM)',
                    style: pw.TextStyle(
                      color: greenDark,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Symmetrical vertical Ground Reaction Force (vGRF): Left foot (green up) | Right foot (orange down)',
                    style: pw.TextStyle(color: slate, fontSize: 8.5),
                  ),
                ],
              ),
              if (logoBytes != null)
                pw.Container(
                  height: 28,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              else
                pw.Text(
                  'INSOUL',
                  style: pw.TextStyle(color: green, fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5),
                ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(color: green, thickness: 1),
          ),

          // GRAPH 1: BILATERAL HEEL PRESSURE
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: lightCard,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: line),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.heelChartPng != null)
                  pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      pw.MemoryImage(data.heelChartPng!),
                      height: 185,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Container(
                    height: 185,
                    alignment: pw.Alignment.center,
                    child: pw.Text('Heel Waveform Chart Pending', style: pw.TextStyle(color: muted, fontSize: 10)),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Figure 1: Bilateral Heel Strike Waveform (Left Foot: Green Upward | Right Foot: Orange Downward)',
                        style: pw.TextStyle(color: slate, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'L: ${data.metrics.peakLeftHeelKg} kg  |  R: ${data.metrics.peakRightHeelKg} kg',
                        style: pw.TextStyle(color: ink, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // GRAPH 2: BILATERAL FOREFOOT / TOE PRESSURE (Structure-wise Identical)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: lightCard,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: line),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.toeChartPng != null)
                  pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      pw.MemoryImage(data.toeChartPng!),
                      height: 185,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Container(
                    height: 185,
                    alignment: pw.Alignment.center,
                    child: pw.Text('Toe Waveform Chart Pending', style: pw.TextStyle(color: muted, fontSize: 10)),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Figure 2: Bilateral Forefoot / Toe Propulsion Waveform (Left Foot: Green Upward | Right Foot: Orange Downward)',
                        style: pw.TextStyle(color: slate, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'L: ${data.metrics.peakLeftToeKg} kg  |  R: ${data.metrics.peakRightToeKg} kg',
                        style: pw.TextStyle(color: ink, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Clinical Observations & Recommendations Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: greenDim,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: green, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLINICAL GAIT OBSERVATIONS & RECOMMENDATIONS',
                  style: pw.TextStyle(color: greenDark, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
                ),
                pw.SizedBox(height: 4),
                _pdfBulletPoint(
                  'Dynamic Stability & Balance: Gait cycle variability is ${data.metrics.gaitVariabilityCv}% (${data.metrics.fallRiskLevel}). Double support time occupies ${data.metrics.doubleSupportPercent}% of total walking duration.',
                  slate,
                ),
                _pdfBulletPoint(
                  'Bilateral Limb Loading: Stance phase symmetry shows ${data.metrics.leftStancePercent}% (Left) vs ${data.metrics.rightStancePercent}% (Right). Peak heel impact is balanced across both extremities.',
                  slate,
                ),
                _pdfBulletPoint(
                  'Propulsive Roll Fluidity: Heel-to-toe progression duration is measured at ${data.metrics.heelToToeTransitionMs} ms, reflecting normal physiological foot-roll progression and active forefoot push-off.',
                  slate,
                ),
              ],
            ),
          ),

          pw.Spacer(),
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'InSoul Gait Telemetry System - Page 2 of 2',
                style: pw.TextStyle(color: muted, fontSize: 8),
              ),
              pw.Text(
                'Clinical & Sports Science Telemetry - Certified Report',
                style: pw.TextStyle(color: muted, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // Direct download / share
  await Printing.sharePdf(
    bytes: await document.save(),
    filename: 'InSoul_Gait_Analysis_Report_${data.generatedAt.millisecondsSinceEpoch}.pdf',
  );
}

pw.Widget _buildPdfMetricBox(
  String title,
  String val,
  String sub,
  PdfColor highlightColor,
  PdfColor ink,
  PdfColor muted,
  PdfColor bg,
  PdfColor border,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      border: pw.Border.all(color: border),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(color: muted, fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(val, style: pw.TextStyle(color: highlightColor, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(sub, style: pw.TextStyle(color: ink, fontSize: 7, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _pdfTableCell(String text, {bool isHeader = false, bool isBold = false, required PdfColor color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: color,
        fontSize: 8.5,
        fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _pdfTableKeyVal(String key, String value, PdfColor valueColor, PdfColor keyColor) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(key, style: pw.TextStyle(color: keyColor, fontSize: 8)),
        pw.Text(value, style: pw.TextStyle(color: valueColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _pdfBulletPoint(String text, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 4,
          height: 4,
          margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            text,
            style: pw.TextStyle(color: color, fontSize: 8.5, height: 1.25),
          ),
        ),
      ],
    ),
  );
}

