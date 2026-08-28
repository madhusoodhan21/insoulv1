import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'shoe_icon.dart';
import 'app_toast.dart';
import 'app_shell.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _step = 1; // 1 = wear shoe, 2 = calibrate L/R
  bool _worn = false;
  bool _calibratingL = false;
  bool _calibratingR = false;
  bool _doneL = false;
  bool _doneR = false;

  bool get _bothDone => _doneL && _doneR;

  void _wearShoe() {
    if (_worn) return;
    setState(() => _worn = true);
  }

  void _goStep2() {
    if (!_worn) return;
    setState(() => _step = 2);
  }

  Future<void> _calibrateSide(String side) async {
    if (side == 'L') {
      if (_doneL || _calibratingL) return;
      setState(() => _calibratingL = true);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() {
        _calibratingL = false;
        _doneL = true;
      });
    } else {
      if (_doneR || _calibratingR) return;
      setState(() => _calibratingR = true);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() {
        _calibratingR = false;
        _doneR = true;
      });
    }
  }

  void _finish() {
    if (!_bothDone) return;
    showAppToast(context, 'Calibration completed');
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 20, height: 1, color: AppColors.border),
                  const SizedBox(width: 10),
                  Text(
                    'INSOLE SETUP',
                    style: AppFonts.display(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _StepBar(active: true, done: _step > 1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StepBar(active: _step == 2, done: false),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wear your shoe to begin',
          style: AppFonts.display(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          "Put the insole-fitted shoe on. The outline turns green once we can feel it's on your foot.",
          style: AppFonts.body(fontSize: 14, color: AppColors.textMid, height: 1.5),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _wearShoe,
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _worn ? AppColors.greenDim : AppColors.border,
                        ),
                      ),
                    ),
                    ShoeIcon(
                      size: 104,
                      color: _worn ? AppColors.green : AppColors.textDim,
                      glow: _worn,
                    ),
                    Positioned(
                      bottom: -34,
                      child: Text(
                        _worn ? 'Shoe detected' : 'Tap once the shoe is on',
                        style: AppFonts.body(
                          fontSize: 12,
                          color: _worn ? AppColors.green : AppColors.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _CtaButton(ready: _worn, label: 'Continue', onTap: _goStep2),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Now check the fit, one at a time',
          style: AppFonts.display(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Take the shoe off, then put it back on by itself — this lets us read your weight and calibrate each side.',
          style: AppFonts.body(fontSize: 14, color: AppColors.textMid, height: 1.5),
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PairShoe(
                  label: 'Left',
                  calibrating: _calibratingL,
                  done: _doneL,
                  onTap: () => _calibrateSide('L'),
                ),
                const SizedBox(width: 26),
                _PairShoe(
                  label: 'Right',
                  calibrating: _calibratingR,
                  done: _doneR,
                  onTap: () => _calibrateSide('R'),
                ),
              ],
            ),
          ),
        ),
        _CtaButton(ready: _bothDone, label: 'Finish setup', onTap: _finish),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  final bool active;
  final bool done;
  const _StepBar({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: done
            ? AppColors.green
            : (active ? AppColors.textMid : AppColors.borderSoft),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final bool ready;
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.ready, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: ready ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ready ? AppColors.green : AppColors.surfaceHi,
            foregroundColor: ready ? const Color(0xFF06120C) : AppColors.textDim,
            disabledBackgroundColor: AppColors.surfaceHi,
            disabledForegroundColor: AppColors.textDim,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: AppFonts.display(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _PairShoe extends StatelessWidget {
  final String label;
  final bool calibrating;
  final bool done;
  final VoidCallback onTap;

  const _PairShoe({
    required this.label,
    required this.calibrating,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = done
        ? AppColors.greenDim
        : (calibrating ? AppColors.textDim : AppColors.border);
    final iconColor = done ? AppColors.green : AppColors.textDim;
    final labelColor = done
        ? AppColors.green
        : (calibrating ? AppColors.textMid : AppColors.textDim);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 118,
        child: Column(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                  ),
                  if (calibrating)
                    const SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMid,
                      ),
                    ),
                  ShoeIcon(size: 52, color: iconColor, glow: done),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label.toUpperCase(),
              style: AppFonts.display(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              done ? 'Calibrated' : (calibrating ? 'Calibrating…' : 'Tap to calibrate'),
              style: AppFonts.body(fontSize: 11, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
