import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ble_service.dart';
import 'app_theme.dart';
import 'app_toast.dart';
import 'calibration_screen.dart';
import 'diagnostics_screen.dart';
import 'accelerometer_screen.dart';
import 'scan_screen.dart';
import 'serial_monitor_screen.dart';
import 'main.dart';

/// Profile screen — matches the Stitch "profile" mockup: avatar header,
/// Daily Step Goal card, Hardware Status card, then a Preferences list.
/// Adds a new "Accelerometer" row (per your request) that opens a live
/// MPU6050 readout screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsOn = true;
  int _stepGoal = 8000;

  Future<void> _editStepGoal() async {
    final controller = TextEditingController(text: _stepGoal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit step goal',
          style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: AppFonts.body(fontSize: 14),
          decoration: const InputDecoration(suffixText: 'steps'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.body(fontSize: 13, color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text)),
            child: Text(
              'Save',
              style: AppFonts.headline(fontSize: 13, color: AppColors.green),
            ),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _stepGoal = result);
    }
  }

  Future<void> _showPrivacyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Privacy',
          style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your step, gait, and pressure data stays on this device and is only '
          'sent to your insole over a direct Bluetooth connection — nothing is '
          'uploaded automatically.',
          style: AppFonts.body(
            fontSize: 13,
            color: AppColors.textMid,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got it',
              style: AppFonts.headline(fontSize: 13, color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign out?',
          style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This disconnects your insole and takes you back to the connect screen.',
          style: AppFonts.body(
            fontSize: 13,
            color: AppColors.textMid,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppFonts.body(fontSize: 13, color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign out',
              style: AppFonts.headline(fontSize: 13, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<BleService>().disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ScanScreen(isEntryFlow: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final settings = context.watch<AppSettings>();
    final fontSizeLabel = settings.fontScale > 1.2
        ? 'Larger'
        : settings.fontScale < 0.9
        ? 'Smaller'
        : 'Default';

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
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
                  const Icon(Icons.more_vert, color: AppColors.textDim),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceHi,
                  border: Border.all(color: AppColors.green, width: 2),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'TBS',
                      style: AppFonts.metric(fontSize: 32, color: AppColors.green),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Team Big Steppers',
                style: AppFonts.headline(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text('PREMIUM MEMBER', style: AppFonts.label(fontSize: 11)),
              const SizedBox(height: 22),
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY STEP GOAL',
                            style: AppFonts.label(fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$_stepGoal',
                                  style: AppFonts.metric(
                                    fontSize: 30,
                                    color: AppColors.green,
                                  ),
                                ),
                                TextSpan(
                                  text: ' steps',
                                  style: AppFonts.body(
                                    fontSize: 14,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.directions_walk,
                      color: AppColors.green,
                      size: 26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'HARDWARE STATUS',
                          style: AppFonts.label(fontSize: 11),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ble.connected
                                ? AppColors.greenDim
                                : AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(width: 5),
                              Text(
                                ble.connected ? 'Connected' : 'Disconnected',
                                style: AppFonts.body(
                                  fontSize: 11,
                                  color: ble.connected
                                      ? AppColors.green
                                      : AppColors.textDim,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'InSoul Shoe V1',
                      style: AppFonts.headline(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.battery_std,
                          size: 14,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ble.connected ? '82% Battery' : '— Battery',
                          style: AppFonts.body(
                            fontSize: 12.5,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _TiltVisualizer(
                axis: 'X',
                value: _tiltDegrees(
                  ble.accelerationX,
                  ble.accelerationY,
                  ble.accelerationZ,
                ),
              ),
              const SizedBox(height: 12),
              _TiltVisualizer(
                axis: 'Y',
                value: _tiltDegrees(
                  ble.accelerationY,
                  ble.accelerationX,
                  ble.accelerationZ,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('PREFERENCES', style: AppFonts.label(fontSize: 11)),
              ),
              const SizedBox(height: 10),
              _card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.bluetooth,
                      title: 'Bluetooth Connections',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.flag_outlined,
                      title: 'Edit Step Goal',
                      value: '${(_stepGoal / 1000).toStringAsFixed(0)}k',
                      onTap: _editStepGoal,
                    ),
                    _ProfileRow(
                      icon: Icons.straighten,
                      title: 'Units',
                      value: 'Metric',
                    ),
                    _ProfileRow(
                      icon: Icons.text_fields,
                      title: 'Font Size',
                      trailing: SizedBox(
                        width: 174,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Slider(
                                value: settings.fontScale,
                                min: 0.75,
                                max: 1.35,
                                divisions: 10,
                                activeColor: AppColors.green,
                                inactiveColor: AppColors.surfaceHighest,
                                onChanged: (value) =>
                                    settings.setFontScale(value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fontSizeLabel,
                              style: AppFonts.body(
                                fontSize: 11,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.speed,
                      title: 'Gyroscope',
                      value: 'MPU6050',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccelerometerScreen(),
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.terminal,
                      title: 'Serial Monitor',
                      value: 'Keyboard debug',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SerialMonitorScreen(),
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.watch_outlined,
                      title: 'Connected Shoe Model',
                      value: 'InSoul V1',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CalibrationScreen(),
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.bar_chart_rounded,
                      title: 'Diagnostics',
                      value: 'Run scan',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      trailing: Switch(
                        value: _notificationsOn,
                        activeTrackColor: AppColors.greenDim,
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.green
                              : AppColors.textDim,
                        ),
                        onChanged: (v) {
                          setState(() => _notificationsOn = v);
                          showAppToast(
                            context,
                            v ? 'Notifications on' : 'Notifications off',
                          );
                        },
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      onTap: _showPrivacyDialog,
                    ),
                    _ProfileRow(
                      icon: Icons.logout,
                      title: 'Sign out',
                      onTap: _confirmSignOut,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: child,
    );
  }
}

double? _tiltDegrees(double? axis, double? otherAxis, double? verticalAxis) {
  if (axis == null || otherAxis == null || verticalAxis == null) return null;
  return math.atan2(axis, math.sqrt(otherAxis * otherAxis + verticalAxis * verticalAxis)) *
      180 /
      math.pi;
}

class _TiltVisualizer extends StatefulWidget {
  final String axis;
  final double? value;

  const _TiltVisualizer({required this.axis, required this.value});

  @override
  State<_TiltVisualizer> createState() => _TiltVisualizerState();
}

class _TiltVisualizerState extends State<_TiltVisualizer> {
  double? _smoothedValue;

  @override
  Widget build(BuildContext context) {
    if (widget.value == null) {
      _smoothedValue = null;
    } else {
      _smoothedValue = _smoothedValue == null
          ? widget.value
          : _smoothedValue! + (widget.value! - _smoothedValue!) * 0.18;
    }

    final value = _smoothedValue;
    final displayValue = value == null
        ? '—'
      : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}°';

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
              Text('MPU6050 TILT ${widget.axis}', style: AppFonts.label(fontSize: 11)),
              const Spacer(),
              Text(
                displayValue,
                style: AppFonts.metric(fontSize: 17, color: AppColors.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: CustomPaint(painter: _TiltBarPainter(value: value)),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+45°',
                style: AppFonts.body(fontSize: 10, color: AppColors.textDim),
              ),
              Text(
                '0',
                style: AppFonts.body(fontSize: 10, color: AppColors.textDim),
              ),
              Text(
                '-45°',
                style: AppFonts.body(fontSize: 10, color: AppColors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TiltBarPainter extends CustomPainter {
  final double? value;

  const _TiltBarPainter({required this.value});

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

    final normalized = ((value ?? 0) / 45).clamp(-1.0, 1.0);
    final endX = centerX - normalized * centerX;
    final startX = normalized >= 0 ? endX : centerX;
    final rightX = normalized >= 0 ? centerX : endX;
    final fill = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        startX,
        center.dy - trackHeight / 2,
        rightX,
        center.dy + trackHeight / 2,
      ),
      const Radius.circular(4),
    );
    if (value != null && normalized != 0) {
      canvas.drawRRect(fill, Paint()..color = AppColors.green);
    }

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      Paint()
        ..color = AppColors.text
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 5, Paint()..color = AppColors.greenBright);
  }

  @override
  bool shouldRepaint(covariant _TiltBarPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLast;

  const _ProfileRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.borderSoft)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppFonts.body(fontSize: 14, color: AppColors.text),
              ),
            ),
            ?trailing,
            if (trailing == null && value != null)
              Text(
                value!,
                style: AppFonts.body(fontSize: 12.5, color: AppColors.textDim),
              ),
            if (trailing == null && onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textDim,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
