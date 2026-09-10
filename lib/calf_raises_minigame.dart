import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'ble_service.dart';

/// Calf Raises form guide - uses uniform sine wave mountains to guide proper form.
/// Player follows the curve by tilting. Each mountain crest = 1 rep.
/// Tracks accuracy of following the curve.
class CalfRaisesMinigame extends StatefulWidget {
  final int targetReps;
  final VoidCallback? onComplete;

  const CalfRaisesMinigame({
    super.key,
    required this.targetReps,
    this.onComplete,
  });

  @override
  State<CalfRaisesMinigame> createState() => _CalfRaisesMinigameState();
}

class _CalfRaisesMinigameState extends State<CalfRaisesMinigame>
    with SingleTickerProviderStateMixin {
  late final BleService _ble;
  late AnimationController _gameController;
  Timer? _gameLoop;

  // Game state
  bool _gameStarted = false;
  bool _gameCompleted = false;
  int _repsCompleted = 0;
  double _playerY = 0.0; // -1 to 1, 0 is center
  double? _smoothedTilt;
  double _scrollOffset = 0.0;
  static const double _scrollSpeed = 2.0;
  static const double _waveLength = 250.0;
  static const double _waveAmplitude = 0.6;
  late final int _targetReps;

  // Simple accuracy tracking
  double _accuracy = 0.0;
  int _lastCountedWave = -1;
  static const double _touchThreshold = 0.6; // Much more forgiving - was 0.25

  // For simple accuracy: time on wave / total time
  int _onWaveFrames = 0;
  int _totalFrames = 0;

  @override
  void initState() {
    super.initState();
    _targetReps = widget.targetReps;
    _ble = context.read<BleService>();
    _gameController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  void _startGame() {
    if (_gameStarted) return;
    setState(() {
      _gameStarted = true;
      _repsCompleted = 0;
      _playerY = 0.0;
      _smoothedTilt = null;
      _scrollOffset = 0.0;
      _accuracy = 0.0;
      _lastCountedWave = -1;
      _onWaveFrames = 0;
      _totalFrames = 0;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      _updateGame();
    });
  }

  double _getWaveY(double x) {
    return _waveAmplitude * math.sin((x / _waveLength) * 2 * math.pi);
  }

  void _updateGame() {
    // Use static MPU6050 tilt from gravity. A 45-degree tilt reaches the
    // edge of the game range, so holding the shoe tilted controls the player.
    final accelerationX = _ble.accelerationX;
    final accelerationY = _ble.accelerationY;
    final accelerationZ = _ble.accelerationZ;
    if (accelerationX != null &&
        accelerationY != null &&
        accelerationZ != null) {
      final tiltDegrees = math.atan2(
            accelerationX,
            math.sqrt(
              accelerationY * accelerationY +
                  accelerationZ * accelerationZ,
            ),
          ) *
          180 /
          math.pi;
      final normalized = (tiltDegrees / 45.0).clamp(-1.0, 1.0);
      final rawTilt = -normalized;
      _smoothedTilt = _smoothedTilt == null
          ? rawTilt
          : _smoothedTilt! + (rawTilt - _smoothedTilt!) * 0.18;

      setState(() {
        _playerY = _smoothedTilt!;
      });
    }

    // Scroll the wave
    setState(() {
      _scrollOffset += _scrollSpeed;
    });

    // Simple accuracy: check if on wave
    const playerX = 50.0;
    final targetY = _getWaveY(playerX + _scrollOffset);
    final distance = (_playerY - targetY).abs();

    _totalFrames++;
    if (distance <= _touchThreshold) {
      _onWaveFrames++;
    }

    // Update accuracy as percentage of time on wave
    if (_totalFrames > 0) {
      setState(() {
        _accuracy = (_onWaveFrames / _totalFrames) * 100.0;
      });
    }

    // Count reps
    final wavePosition = ((_scrollOffset + playerX) / _waveLength) % 1.0;
    final currentWave = ((_scrollOffset + playerX) / _waveLength).toInt();

    if (currentWave != _lastCountedWave && wavePosition >= 0.24 && wavePosition <= 0.26) {
      _lastCountedWave = currentWave;
      setState(() {
        _repsCompleted++;
        if (_repsCompleted >= _targetReps) {
          _endGame();
        }
      });
    }
  }

  void _endGame() {
    _gameLoop?.cancel();
    setState(() {
      _gameCompleted = true;
    });

    // Show DONE animation
    _gameController.forward().then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _gameController.reverse().then((_) {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          });
        }
      });
    });
  }

  void _resetGame() {
    setState(() {
      _gameStarted = false;
      _gameCompleted = false;
      _repsCompleted = 0;
      _playerY = 0.0;
      _smoothedTilt = null;
      _scrollOffset = 0.0;
      _accuracy = 0.0;
      _lastCountedWave = -1;
      _onWaveFrames = 0;
      _totalFrames = 0;
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _gameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameCompleted) {
      // Show DONE screen like toe standing
      return Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: FadeTransition(
          opacity: _gameController,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DONE!',
                  style: AppFonts.metric(
                    fontSize: 85,
                    color: AppColors.greenBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_repsCompleted < _targetReps)
                  Text(
                    'Rep $_repsCompleted of $_targetReps',
                    style: AppFonts.body(
                      fontSize: 14,
                      color: AppColors.textMid,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calf Raises - Rep $_repsCompleted/$_targetReps',
                  style: AppFonts.headline(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textDim,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Rep counter
            Text(
              '$_repsCompleted/$_targetReps',
              style: AppFonts.body(
                fontSize: 14,
                color: AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _gameStarted ? 'Keep moving with the guide' : 'Get in form!',
              style: AppFonts.body(
                fontSize: 13,
                color: _gameStarted ? AppColors.greenBright : AppColors.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 160, maxWidth: 260),
              child: Image.asset(
                'assets/images/calf rises.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            // Game canvas
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _FormGuidePainter(
                    playerY: _playerY,
                    scrollOffset: _scrollOffset,
                    waveLength: 200.0,
                    waveAmplitude: _waveAmplitude,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            if (!_gameStarted && !_gameCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenBright,
                    foregroundColor: AppColors.onGreen,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    'START',
                    style: AppFonts.label(
                      fontSize: 13,
                      color: AppColors.onGreen,
                    ),
                  ),
                ),
              ),
            if (_gameCompleted) ...[
              Text(
                'Complete!',
                style: AppFonts.metric(fontSize: 32, color: AppColors.green),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Accuracy: ${_accuracy.toStringAsFixed(1)}%',
                style: AppFonts.body(fontSize: 14, color: AppColors.textMid),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDim,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Done',
                        style: AppFonts.label(
                          fontSize: 13,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenBright,
                        foregroundColor: AppColors.onGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        'Retry',
                        style: AppFonts.label(
                          fontSize: 13,
                          color: AppColors.onGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormGuidePainter extends CustomPainter {
  final double playerY;
  final double scrollOffset;
  final double waveLength;
  final double waveAmplitude;

  _FormGuidePainter({
    required this.playerY,
    required this.scrollOffset,
    required this.waveLength,
    required this.waveAmplitude,
  });

  double _getWaveY(double x) {
    return waveAmplitude * math.sin((x / waveLength) * 2 * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.bg, AppColors.surfaceHi],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final centerY = size.height / 2;

    // Draw the single sine wave guide
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wavePath = Path();
    bool firstPoint = true;
    for (double x = -50; x < size.width + 50; x += 2) {
      final waveY = _getWaveY(x + scrollOffset);
      final screenY = centerY + (waveY * size.height / 2.8);

      if (firstPoint) {
        wavePath.moveTo(x, screenY);
        firstPoint = false;
      } else {
        wavePath.lineTo(x, screenY);
      }
    }
    canvas.drawPath(wavePath, wavePaint);

    // Draw player indicator at center (x = 50)
    const playerX = 50.0;
    final targetWaveY = _getWaveY(
      playerX + scrollOffset,
    ); // Check wave at player's x position
    final playerScreenY = centerY + (playerY * size.height / 2.8);
    final targetScreenY = centerY + (targetWaveY * size.height / 2.8);

    // Check if touching the wave
    final distance = (playerY - targetWaveY).abs();
    final isTouching = distance <= 0.25;

    // Hitbox circle
    const playerSize = 18.0;
    const hitboxRadius = playerSize * 1.1 * 1.5;
    final hitboxPaint = Paint()
      ..color = (isTouching ? AppColors.green : AppColors.amber).withValues(
        alpha: 0.1,
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(playerX, playerScreenY),
      hitboxRadius,
      hitboxPaint,
    );

    // Player triangle - rotated 90 degrees to the right (pointing right)
    // Color changes: GREEN when on wave, YELLOW when not
    final playerPath = Path();
    playerPath.moveTo(playerX + playerSize, playerScreenY); // Right point
    playerPath.lineTo(
      playerX - playerSize / 2,
      playerScreenY + playerSize,
    ); // Bottom-left
    playerPath.lineTo(
      playerX - playerSize / 2,
      playerScreenY - playerSize,
    ); // Top-left
    playerPath.close();

    final playerPaint = Paint()
      ..color = isTouching ? AppColors.green : AppColors.amber
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = (isTouching ? AppColors.green : AppColors.amber).withValues(
        alpha: 0.3,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(playerPath, shadowPaint);
    canvas.drawPath(playerPath, playerPaint);

    // Draw distance line from player to wave (only when not touching)
    if (!isTouching && distance < 0.5) {
      final linePaint = Paint()
        ..color = AppColors.amber.withValues(alpha: 0.6 * (1 - distance / 0.5))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(playerX, playerScreenY),
        Offset(playerX, targetScreenY),
        linePaint,
      );
    }

    // Glow effect when touching the wave
    if (isTouching) {
      final glowPaint = Paint()
        ..color = AppColors.green.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(playerX, playerScreenY), 28, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_FormGuidePainter oldDelegate) {
    return oldDelegate.playerY != playerY ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}
