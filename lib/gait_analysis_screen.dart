import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'app_toast.dart';
import 'ble_service.dart';
import 'gait_processor.dart';
import 'gait_waveform_renderer.dart';
import 'physio_screen.dart';
import 'quick_gait_metrics.dart';
import 'report_exporter.dart';
import 'serial_exporter.dart';

class GaitAnalysisScreen extends StatefulWidget {
  const GaitAnalysisScreen({super.key});

  @override
  State<GaitAnalysisScreen> createState() => _GaitAnalysisScreenState();
}

class _GaitAnalysisScreenState extends State<GaitAnalysisScreen> {
  StreamSubscription<GaitEvent>? _gaitSubscription;
  Timer? _timer;
  int _secondsRemaining = 10;
  int _stepsAtStart = 0;
  int _detectedSteps = 0;
  bool _waitingForWalk = true;
  bool _running = false;
  bool _complete = false;
  List<String> _capturedSerialLines = const [];
  List<PressureSample> _capturedSamples = const [];
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    final ble = context.read<BleService>();
    _stepsAtStart = ble.stepCount;
    _gaitSubscription = ble.gaitEvents.listen(_onGaitEvent);
  }

  void _onGaitEvent(GaitEvent event) {
    if (event is! StepEvent || _complete) return;
    if (_waitingForWalk) {
      _detectedSteps++;
      if (_detectedSteps >= 2) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    if (_running || _complete) return;
    // Reset pressure samples to capture only this session's data
    final ble = context.read<BleService>();
    ble.resetPressureSamples();
    ble.startGaitAnalysisSerialCapture();
    setState(() {
      _waitingForWalk = false;
      _running = true;
      _secondsRemaining = 10;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        final bleService = context.read<BleService>();
        _capturedSerialLines = bleService.finishGaitAnalysisSerialCapture();
        _capturedSamples = List<PressureSample>.from(bleService.pressureSamples);
        setState(() {
          _secondsRemaining = 0;
          _running = false;
          _complete = true;
        });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gaitSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _complete ? _buildResult(context) : _buildWalkView(context),
        ),
      ),
    );
  }

  Widget _buildWalkView(BuildContext context) {
    return Padding(
      key: const ValueKey('walk'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(context),
          const Spacer(),
          Text(
            'GAIT',
            style: AppFonts.headline(fontSize: 42, fontWeight: FontWeight.w800),
          ),
          Text(
            'ANALYSIS',
            style: AppFonts.headline(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: AppColors.greenBright,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _running ? 'Keep walking naturally' : 'Walk now',
            style: AppFonts.body(fontSize: 20, color: AppColors.textMid),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _running ? null : _startCountdown,
              child: Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.greenBright, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.2),
                      blurRadius: 30,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _running
                    ? Text(
                        '$_secondsRemaining',
                        style: AppFonts.metric(
                          fontSize: 64,
                          color: AppColors.greenBright,
                        ),
                      )
                    : Icon(
                        Icons.directions_walk,
                        size: 72,
                        color: AppColors.greenBright,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              _running
                  ? 'SESSION IN PROGRESS'
                  : 'TAP CIRCLE TO START (OR WALK 2 STEPS)',
              textAlign: TextAlign.center,
              style: AppFonts.label(fontSize: 11, color: AppColors.textDim),
            ),
          ),
          const Spacer(),
          Text(
            'InSoul will record a 10-second capture of bilateral foot forces, cadence, and symmetry. Tap above or walk naturally.',
            style: AppFonts.body(
              fontSize: 12,
              color: AppColors.textDim,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final ble = context.watch<BleService>();
    final steps = (ble.stepCount - _stepsAtStart).clamp(0, 9999);
    final metrics = QuickGaitMetrics.calculate(
      samples: _capturedSamples,
      steps: steps,
      symmetryScore: ble.symmetryScore,
      leftToRightMs: ble.leftToRightMs,
      rightToLeftMs: ble.rightToLeftMs,
    );

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(context),
          const SizedBox(height: 28),

          // Header: Title & Mobility Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'GAIT ANALYSIS',
                        style: AppFonts.headline(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'REPORT',
                        style: AppFonts.headline(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenBright,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.greenBright.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.greenBright,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      metrics.mobilityStatus,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenBright,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sub-banner: Limping assessment & Fall Risk Level
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    metrics.limpingSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Fall Risk: ',
                      style: TextStyle(fontSize: 11, color: AppColors.textDim),
                    ),
                    Text(
                      metrics.fallRiskLevel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: metrics.gaitVariabilityCv > 4.5
                            ? const Color(0xFFFB923C)
                            : AppColors.greenBright,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Primary 2x2 Key Metric Cards Grid
          Row(
            children: [
              Expanded(
                child: _resultMetric('CADENCE', '${metrics.cadence}', 'STEPS/MIN'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _resultMetric(
                  'SYMMETRY',
                  metrics.symmetryScore == null
                      ? '--'
                      : '${metrics.symmetryScore!.toStringAsFixed(1)}%',
                  metrics.limpingSummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _resultMetric(
                  'DOUBLE SUPPORT',
                  '${metrics.doubleSupportPercent}%',
                  '${metrics.doubleSupportMs} ms TOTAL',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _resultMetric(
                  'VARIABILITY',
                  '${metrics.gaitVariabilityCv}%',
                  metrics.fallRiskLevel,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bilateral Temporal Sub-Phasing (Phasogram) Card
          _buildPhasogramCard(metrics),

          const SizedBox(height: 24),

          // Step Kinematics & Roll Fluidity Grid
          _buildKinematicsGrid(metrics),

          const SizedBox(height: 28),

          // Pressure Waveform Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'PRESSURE',
                style: AppFonts.headline(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Text(
                'GRAPH',
                style: AppFonts.headline(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenBright,
                ),
              ),
              const Spacer(),
              Text(
                '50 Hz Dual Insole Telemetry',
                style: AppFonts.body(fontSize: 10, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interactive Bilateral Waveform (mirrored downward orange, upward green)
          BilateralHeelWaveform(
            ble: ble,
            samples: _capturedSamples,
            height: 260,
            cadence: metrics.cadence,
            leftToRightMs: metrics.leftToRightMs,
            rightToLeftMs: metrics.rightToLeftMs,
          ),

          const SizedBox(height: 28),

          // Action Toolbar: PDF Download and Visualizer Export
          _buildActionToolbar(metrics),
        ],
      ),
    );
  }

  Widget _buildPhasogramCard(QuickGaitMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BILATERAL GAIT PHASOGRAM',
                style: AppFonts.label(fontSize: 11, color: AppColors.greenBright),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Text(
                  'Norm: 60% / 40%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Left Limb Bar
          _phasogramBar(
            label: 'LEFT FOOT',
            stancePct: metrics.leftStancePercent,
            swingPct: metrics.leftSwingPercent,
            color: AppColors.greenBright,
          ),
          const SizedBox(height: 14),

          // Right Limb Bar
          _phasogramBar(
            label: 'RIGHT FOOT',
            stancePct: metrics.rightStancePercent,
            swingPct: metrics.rightSwingPercent,
            color: const Color(0xFFFB923C),
          ),
          const SizedBox(height: 14),

          // Legend & Double Support readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.greenBright,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Stance', style: TextStyle(fontSize: 10, color: AppColors.textMid)),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Swing', style: TextStyle(fontSize: 10, color: AppColors.textDim)),
                ],
              ),
              Text(
                'DST: ${metrics.doubleSupportPercent}% (${metrics.doubleSupportMs} ms)',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phasogramBar({
    required String label,
    required double stancePct,
    required double swingPct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              'Stance: ${stancePct.toStringAsFixed(1)}%  ·  Swing: ${swingPct.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 12,
            color: AppColors.surfaceHi,
            child: Row(
              children: [
                Expanded(
                  flex: (stancePct * 10).round().clamp(1, 1000),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.85), color],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: (swingPct * 10).round().clamp(1, 1000),
                  child: Container(
                    color: AppColors.surfaceHi,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKinematicsGrid(QuickGaitMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP KINEMATICS & ROLL FLUIDITY',
          style: AppFonts.label(fontSize: 11, color: AppColors.greenBright),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _analysisMetric(
                'STRIDE TIME',
                metrics.strideTimeMs == null ? '--' : '${metrics.strideTimeMs} ms',
                'heel-to-heel duration',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analysisMetric(
                'A/P ROLL TIME',
                '${metrics.heelToToeTransitionMs} ms',
                'heel to toe transition',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _analysisMetric(
                'L → R TRANSITION',
                metrics.leftToRightMs == null ? '--' : '${metrics.leftToRightMs} ms',
                'measured swing-step gap',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analysisMetric(
                'R → L TRANSITION',
                metrics.rightToLeftMs == null ? '--' : '${metrics.rightToLeftMs} ms',
                'measured swing-step gap',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionToolbar(QuickGaitMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExportingPdf ? null : () => _downloadPdfReport(metrics),
            icon: _isExportingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_isExportingPdf ? 'GENERATING PDF...' : 'DOWNLOAD REPORT'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              await downloadGaitSerialLog(_capturedSerialLines);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Visualizer data sent')),
              );
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('SEND VISUALIZER'),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPdfReport(QuickGaitMetrics metrics) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      showAppToast(context, 'Rendering separate Heel & Toe waveforms (50 Hz)...');

      // Separate Heel Graph (bilateral mirrored)
      final heelChartPng = await GaitWaveformRenderer.renderBilateralPng(
        samples: _capturedSamples,
        channel: GaitWaveChannel.heel,
        cadence: metrics.cadence,
        leftToRightMs: metrics.leftToRightMs,
        rightToLeftMs: metrics.rightToLeftMs,
      );

      // Separate Toe Graph (bilateral mirrored, structure-wise identical)
      final toeChartPng = await GaitWaveformRenderer.renderBilateralPng(
        samples: _capturedSamples,
        channel: GaitWaveChannel.toe,
        cadence: metrics.cadence,
        leftToRightMs: metrics.leftToRightMs,
        rightToLeftMs: metrics.rightToLeftMs,
      );

      final reportData = QuickGaitReportData(
        generatedAt: DateTime.now(),
        metrics: metrics,
        samples: _capturedSamples,
        heelChartPng: heelChartPng,
        toeChartPng: toeChartPng,
      );

      await exportQuickGaitAnalysisPdf(reportData);

      if (mounted) {
        showAppToast(context, 'PDF Report generated successfully');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'PDF Generation error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Widget _analysisMetric(String label, String value, String detail) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.label(fontSize: 9)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.metric(fontSize: 20, color: AppColors.greenBright),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: AppFonts.body(fontSize: 9, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        Text(
          'IN',
          style: AppFonts.headline(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(
          'SOUL',
          style: AppFonts.headline(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.textMid),
        ),
      ],
    );
  }

  Widget _resultMetric(String label, String value, String unit) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textDim, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: AppFonts.label(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: AppFonts.metric(fontSize: 38, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unit,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppFonts.label(fontSize: 11, color: AppColors.greenBright),
            ),
          ),
        ],
      ),
    );
  }
}
