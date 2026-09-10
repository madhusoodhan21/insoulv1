import 'dart:async';

enum LoadState { none, leftOnly, rightOnly, both }

class ImuSample {
  const ImuSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  final double? ax;
  final double? ay;
  final double? az;
  final double? gx;
  final double? gy;
  final double? gz;
}

abstract class GaitEvent {}

class StepEvent extends GaitEvent {
  StepEvent({
    required this.foot,
    required this.totalSteps,
    required this.leftSteps,
    required this.rightSteps,
    this.timestampMs,
  });

  final String foot;
  final int totalSteps;
  final int leftSteps;
  final int rightSteps;
  final int? timestampMs;
}

class LoadStateChangedEvent extends GaitEvent {
  LoadStateChangedEvent({
    required this.state,
    required this.active,
    required this.leftPressed,
    required this.rightPressed,
  });

  final LoadState state;
  final bool active;
  final bool leftPressed;
  final bool rightPressed;
}

class SymmetryComputedEvent extends GaitEvent {
  SymmetryComputedEvent({
    required this.avgLToR,
    required this.avgRToL,
    required this.score,
  });

  final double avgLToR;
  final double avgRToL;
  final double score;
}

class PacketGapEvent extends GaitEvent {
  PacketGapEvent({
    required this.previousSeq,
    required this.currentSeq,
    required this.missedSamples,
  });

  final int previousSeq;
  final int currentSeq;
  final int missedSamples;
}

class GaitProcessor {
  GaitProcessor();

  static const int pressThreshold = 1800;
  static const int releaseThreshold = 1200;
  static const int minimumStepIntervalMs = 300;
  static const int simultaneousHeelWindowMs = 150;
  static const int startupSettlingMs = 1500;
  static const int symmetryBatchSize = 5;
  static const int idleGapMs = 2000;
  static const double symmetryPenaltyFactor = 0.5;

  final StreamController<GaitEvent> _eventController =
      StreamController<GaitEvent>.broadcast();

  Stream<GaitEvent> get events => _eventController.stream;

  bool _leftPressed = false;
  bool _rightPressed = false;
  bool _leftHeelPressed = false;
  bool _rightHeelPressed = false;
  bool _leftToePressed = false;
  bool _rightToePressed = false;
  int _leftStepCount = 0;
  int _rightStepCount = 0;
  String? _lastStepFoot;
  int? _lastStepTime;
  final List<int> _leftToRightTransitions = <int>[];
  final List<int> _rightToLeftTransitions = <int>[];
  LoadState _currentLoadState = LoadState.none;
  double _symmetryScore = 100.0;
  int? _avgLToRMs;
  int? _avgRToLMs;
  int? _lastSeq;
  ImuSample? _lastImuSample;
  int? _firstFirmwareTime;
  int? _lastLeftStepTime;
  int? _lastRightStepTime;
  String? _recentHeelStrikeFoot;
  int? _recentHeelStrikeTime;

  bool get leftPressed => _leftPressed;
  bool get rightPressed => _rightPressed;
  bool get leftHeelPressed => _leftHeelPressed;
  bool get rightHeelPressed => _rightHeelPressed;
  bool get leftToePressed => _leftToePressed;
  bool get rightToePressed => _rightToePressed;
  bool get toeStandingActive =>
      (_leftToePressed || _rightToePressed) &&
      !_leftHeelPressed &&
      !_rightHeelPressed;
  int get leftStepCount => _leftStepCount;
  int get rightStepCount => _rightStepCount;
  int get totalStepCount => _leftStepCount + _rightStepCount;
  String? get lastStepFoot => _lastStepFoot;
  int? get lastStepTime => _lastStepTime;
  LoadState get currentLoadState => _currentLoadState;
  double get symmetryScore => _symmetryScore;
  int? get leftToRightMs => _avgLToRMs;
  int? get rightToLeftMs => _avgRToLMs;
  ImuSample? get lastImuSample => _lastImuSample;

  void processSample(Map<String, dynamic> sample) {
    if (sample['type'] != 'sample') {
      return;
    }

    final seq = _asInt(sample['seq']);
    if (seq != null && _lastSeq != null && seq > _lastSeq! + 1) {
      _eventController.add(
        PacketGapEvent(
          previousSeq: _lastSeq!,
          currentSeq: seq,
          missedSamples: seq - _lastSeq! - 1,
        ),
      );
    }
    _lastSeq = seq ?? _lastSeq;

    final firmwareMillis = _asInt(sample['t']);
    if (seq != null && firmwareMillis != null) {
      _firstFirmwareTime ??= firmwareMillis;
    }
    final allowStepDetection =
        seq == null ||
        firmwareMillis == null ||
        firmwareMillis - (_firstFirmwareTime ?? firmwareMillis) >=
            startupSettlingMs;
    final fsr = sample['fsr'];
    if (fsr is Map) {
      final leftFsr = fsr['l'];
      final rightFsr = fsr['r'];
      final leftHeelValue = _heelValue(leftFsr);
      final rightHeelValue = _heelValue(rightFsr);
      final simultaneousHeelLoad =
          leftHeelValue != null &&
          rightHeelValue != null &&
          !_leftHeelPressed &&
          !_rightHeelPressed &&
          leftHeelValue > pressThreshold &&
          rightHeelValue > pressThreshold;

      if (leftFsr is Map) {
        final leftToeValue = _asDouble(leftFsr['toe']);
        _processFoot(
          'L',
          leftHeelValue,
          leftToeValue,
          firmwareMillis,
          allowStepDetection && !simultaneousHeelLoad,
        );
      } else {
        final leftValue = _asDouble(leftFsr);
        if (leftValue != null) {
          _processFoot(
            'L',
            leftValue,
            leftValue,
            firmwareMillis,
            allowStepDetection && !simultaneousHeelLoad,
          );
        }
      }

      if (rightFsr is Map) {
        final rightToeValue = _asDouble(rightFsr['toe']);
        _processFoot(
          'R',
          rightHeelValue,
          rightToeValue,
          firmwareMillis,
          allowStepDetection && !simultaneousHeelLoad,
        );
      } else {
        final rightValue = _asDouble(rightFsr);
        if (rightValue != null) {
          _processFoot(
            'R',
            rightValue,
            rightValue,
            firmwareMillis,
            allowStepDetection && !simultaneousHeelLoad,
          );
        }
      }
    }

    final imu = sample['imu'];
    if (imu is Map) {
      final imuMap = Map<String, dynamic>.from(imu);
      _lastImuSample = ImuSample(
        ax: _asDouble(imuMap['ax']),
        ay: _asDouble(imuMap['ay']),
        az: _asDouble(imuMap['az']),
        gx: _asDouble(imuMap['gx']),
        gy: _asDouble(imuMap['gy']),
        gz: _asDouble(imuMap['gz']),
      );
    }

    final nextLoadState = _computeLoadState();
    if (nextLoadState != _currentLoadState) {
      _currentLoadState = nextLoadState;
      _eventController.add(
        LoadStateChangedEvent(
          state: nextLoadState,
          active: nextLoadState != LoadState.none,
          leftPressed: _leftPressed,
          rightPressed: _rightPressed,
        ),
      );
    }
  }

  void dispose() {
    _eventController.close();
  }

  /// Debugging method: Set heel/toe states via keyboard input
  void debugSetSensorState(String foot, String sensor, bool pressed) {
    if (foot == 'L') {
      if (sensor == 'heel') {
        _leftHeelPressed = pressed;
      } else if (sensor == 'toe') {
        _leftToePressed = pressed;
      }
    } else if (foot == 'R') {
      if (sensor == 'heel') {
        _rightHeelPressed = pressed;
      } else if (sensor == 'toe') {
        _rightToePressed = pressed;
      }
    }

    // Update overall foot pressed state
    final leftNew = _leftHeelPressed || _leftToePressed;
    final rightNew = _rightHeelPressed || _rightToePressed;

    if (leftNew != _leftPressed) {
      _leftPressed = leftNew;
      if (leftNew) _leftStepCount++;
    }
    if (rightNew != _rightPressed) {
      _rightPressed = rightNew;
      if (rightNew) _rightStepCount++;
    }

    // Emit load state change
    final nextLoadState = _computeLoadState();
    if (nextLoadState != _currentLoadState) {
      _currentLoadState = nextLoadState;
      _eventController.add(
        LoadStateChangedEvent(
          state: nextLoadState,
          active: nextLoadState != LoadState.none,
          leftPressed: _leftPressed,
          rightPressed: _rightPressed,
        ),
      );
    }
  }

  void _processFoot(
    String footLabel,
    double? heelValue,
    double? toeValue,
    int? firmwareMillis,
    bool allowStepDetection,
  ) {
    if (heelValue == null || toeValue == null) {
      return;
    }

    // Process heel
    bool heelPressed = footLabel == 'L' ? _leftHeelPressed : _rightHeelPressed;
    var heelStrike = false;
    if (!heelPressed && heelValue > pressThreshold) {
      heelStrike =
          allowStepDetection && _canCountStep(footLabel, firmwareMillis);
      if (footLabel == 'L') {
        _leftHeelPressed = true;
      } else {
        _rightHeelPressed = true;
      }
    } else if (heelPressed && heelValue <= releaseThreshold) {
      if (footLabel == 'L') {
        _leftHeelPressed = false;
      } else {
        _rightHeelPressed = false;
      }
    }

    // Process toe
    bool toePressed = footLabel == 'L' ? _leftToePressed : _rightToePressed;
    if (!toePressed && toeValue > pressThreshold) {
      if (footLabel == 'L') {
        _leftToePressed = true;
      } else {
        _rightToePressed = true;
      }
    } else if (toePressed && toeValue <= releaseThreshold) {
      if (footLabel == 'L') {
        _leftToePressed = false;
      } else {
        _rightToePressed = false;
      }
    }

    // Update overall foot pressed state (heel OR toe)
    final newPressed = (footLabel == 'L'
        ? _leftHeelPressed || _leftToePressed
        : _rightHeelPressed || _rightToePressed);
    final wasPressed = footLabel == 'L' ? _leftPressed : _rightPressed;

    if (!wasPressed && newPressed) {
      if (footLabel == 'L') {
        _leftPressed = true;
      } else {
        _rightPressed = true;
      }
    } else if (wasPressed && !newPressed) {
      if (footLabel == 'L') {
        _leftPressed = false;
      } else {
        _rightPressed = false;
      }
    }

    var stepTriggered = heelStrike;
    if (!stepTriggered && !wasPressed && toePressed) {
      stepTriggered =
          allowStepDetection && _canCountStep(footLabel, firmwareMillis);
    }

    if (stepTriggered) {
      final oppositeFoot = footLabel == 'L' ? 'R' : 'L';
      final recentTime = _recentHeelStrikeTime;
      final isStaggeredStandingLoad =
          _recentHeelStrikeFoot == oppositeFoot &&
          recentTime != null &&
          _firstFirmwareTime != null &&
          firmwareMillis != null &&
          firmwareMillis - recentTime <= simultaneousHeelWindowMs;

      if (isStaggeredStandingLoad) {
        if (_recentHeelStrikeFoot == 'L' && _leftStepCount > 0) {
          _leftStepCount--;
        } else if (_recentHeelStrikeFoot == 'R' && _rightStepCount > 0) {
          _rightStepCount--;
        }
        _recentHeelStrikeFoot = null;
        _recentHeelStrikeTime = null;
        return;
      }

      if (footLabel == 'L') {
        _leftStepCount++;
        _lastLeftStepTime = firmwareMillis;
      } else {
        _rightStepCount++;
        _lastRightStepTime = firmwareMillis;
      }
      if (_firstFirmwareTime != null) {
        _recentHeelStrikeFoot = footLabel;
        _recentHeelStrikeTime = firmwareMillis;
      }
      _onStep(footLabel, firmwareMillis);
    }
  }

  bool _canCountStep(String footLabel, int? firmwareMillis) {
    if (firmwareMillis == null || _firstFirmwareTime == null) return true;
    final previous = footLabel == 'L' ? _lastLeftStepTime : _lastRightStepTime;
    return previous == null ||
        firmwareMillis - previous >= minimumStepIntervalMs;
  }

  double? _heelValue(Object? foot) {
    if (foot is Map) return _asDouble(foot['heel']);
    return _asDouble(foot);
  }

  void _onStep(String footLabel, int? firmwareMillis) {
    _eventController.add(
      StepEvent(
        foot: footLabel,
        totalSteps: totalStepCount,
        leftSteps: _leftStepCount,
        rightSteps: _rightStepCount,
        timestampMs: firmwareMillis,
      ),
    );

    if (firmwareMillis == null) {
      return;
    }

    if (_lastStepFoot == null) {
      _lastStepFoot = footLabel;
      _lastStepTime = firmwareMillis;
      return;
    }

    final previousTime = _lastStepTime ?? firmwareMillis;
    final delta = firmwareMillis - previousTime;
    if (delta > idleGapMs) {
      _leftToRightTransitions.clear();
      _rightToLeftTransitions.clear();
      _lastStepFoot = footLabel;
      _lastStepTime = firmwareMillis;
      return;
    }

    if (_lastStepFoot == footLabel) {
      _lastStepFoot = footLabel;
      _lastStepTime = firmwareMillis;
      return;
    }

    if (_lastStepFoot == 'L' && footLabel == 'R') {
      _leftToRightTransitions.add(delta);
    } else if (_lastStepFoot == 'R' && footLabel == 'L') {
      _rightToLeftTransitions.add(delta);
    }

    _lastStepFoot = footLabel;
    _lastStepTime = firmwareMillis;

    if (_leftToRightTransitions.length >= symmetryBatchSize &&
        _rightToLeftTransitions.length >= symmetryBatchSize) {
      _computeSymmetry();
      _leftToRightTransitions.clear();
      _rightToLeftTransitions.clear();
    }
  }

  void _computeSymmetry() {
    final leftWindow = _leftToRightTransitions.take(symmetryBatchSize).toList();
    final rightWindow = _rightToLeftTransitions
        .take(symmetryBatchSize)
        .toList();
    if (leftWindow.isEmpty || rightWindow.isEmpty) {
      return;
    }

    final avgLToR = leftWindow.reduce((a, b) => a + b) / leftWindow.length;
    final avgRToL = rightWindow.reduce((a, b) => a + b) / rightWindow.length;
    final avgAll = (avgLToR + avgRToL) / 2.0;
    if (avgAll <= 0) {
      _symmetryScore = 100.0;
      _avgLToRMs = avgLToR.round();
      _avgRToLMs = avgRToL.round();
      _eventController.add(
        SymmetryComputedEvent(
          avgLToR: avgLToR,
          avgRToL: avgRToL,
          score: _symmetryScore,
        ),
      );
      return;
    }

    final symmetryIndex = (avgLToR - avgRToL).abs() / avgAll * 100.0;
    _symmetryScore = (100.0 - (symmetryIndex * symmetryPenaltyFactor)).clamp(
      0.0,
      100.0,
    );
    _avgLToRMs = avgLToR.round();
    _avgRToLMs = avgRToL.round();

    _eventController.add(
      SymmetryComputedEvent(
        avgLToR: avgLToR,
        avgRToL: avgRToL,
        score: _symmetryScore,
      ),
    );
  }

  LoadState _computeLoadState() {
    if (_leftPressed && _rightPressed) {
      return LoadState.both;
    }
    if (_leftPressed) {
      return LoadState.leftOnly;
    }
    if (_rightPressed) {
      return LoadState.rightOnly;
    }
    return LoadState.none;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
