import 'package:flutter_test/flutter_test.dart';
import 'package:insoulv1/gait_processor.dart';

void main() {
  test('hysteresis press/release logic increments per-foot counts once', () {
    final processor = GaitProcessor();

    processor.processSample({
      'type': 'sample',
      't': 1000,
      'fsr': {'l': 3000, 'r': 300},
    });
    expect(processor.leftStepCount, 1);
    expect(processor.rightStepCount, 0);
    expect(processor.currentLoadState, LoadState.leftOnly);

    processor.processSample({
      'type': 'sample',
      't': 1010,
      'fsr': {'l': 1200, 'r': 300},
    });
    expect(processor.leftPressed, isFalse);
    expect(processor.currentLoadState, LoadState.none);
  });

  test('symmetry batch is computed from opposite-foot transition gaps', () {
    final processor = GaitProcessor();

    for (var i = 0; i < 5; i++) {
      final base = 1000 + (i * 200);

      // L -> R transition
      processor.processSample({
        'type': 'sample',
        't': base,
        'fsr': {'l': 3000, 'r': 100},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 20,
        'fsr': {'l': 100, 'r': 100},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 40,
        'fsr': {'l': 100, 'r': 3000},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 60,
        'fsr': {'l': 100, 'r': 100},
      });

      // R -> L transition
      processor.processSample({
        'type': 'sample',
        't': base + 80,
        'fsr': {'l': 100, 'r': 3000},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 100,
        'fsr': {'l': 100, 'r': 100},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 120,
        'fsr': {'l': 3000, 'r': 100},
      });
      processor.processSample({
        'type': 'sample',
        't': base + 140,
        'fsr': {'l': 100, 'r': 100},
      });
    }

    expect(processor.symmetryScore, isNotNull);
    expect(processor.leftToRightMs, isNotNull);
    expect(processor.rightToLeftMs, isNotNull);
    expect(processor.symmetryScore, inInclusiveRange(0.0, 100.0));
  });

  test('missing imu data is ignored without affecting sample processing', () {
    final processor = GaitProcessor();

    processor.processSample({
      'type': 'sample',
      't': 5000,
      'fsr': {'l': 3500, 'r': 1500},
    });

    expect(processor.currentLoadState, LoadState.leftOnly);
    expect(processor.leftPressed, isTrue);
    expect(processor.rightPressed, isFalse);
    expect(processor.lastImuSample, isNull);
  });

  test('idle gaps are excluded from symmetry transitions', () {
    final processor = GaitProcessor();

    Map<String, dynamic> sample(int time, int left, int right) => {
      'type': 'sample',
      't': time,
      'fsr': {
        'l': {'heel': left, 'toe': left},
        'r': {'heel': right, 'toe': right},
      },
    };

    var time = 1000;
    for (var i = 0; i < 5; i++) {
      processor.processSample(sample(time, 3000, 100));
      processor.processSample(sample(time + 20, 100, 100));
      processor.processSample(sample(time + 40, 100, 3000));
      processor.processSample(sample(time + 60, 100, 100));
      processor.processSample(sample(time + 80, 100, 3000));
      processor.processSample(sample(time + 100, 100, 100));
      processor.processSample(sample(time + 120, 3000, 100));
      processor.processSample(sample(time + 140, 100, 100));
      time += 200;
    }

    time += 3000;
    for (var i = 0; i < 5; i++) {
      processor.processSample(sample(time, 100, 3000));
      processor.processSample(sample(time + 20, 100, 100));
      processor.processSample(sample(time + 40, 3000, 100));
      processor.processSample(sample(time + 60, 100, 100));
      processor.processSample(sample(time + 80, 3000, 100));
      processor.processSample(sample(time + 100, 100, 100));
      processor.processSample(sample(time + 120, 100, 3000));
      processor.processSample(sample(time + 140, 100, 100));
      time += 200;
    }

    expect(processor.symmetryScore, greaterThan(90));
  });

  test('toe pressure does not count as a step before a heel strike', () {
    final processor = GaitProcessor();

    Map<String, dynamic> sample(int leftHeel, int leftToe) => {
      'type': 'sample',
      't': 1000,
      'fsr': {
        'l': {'heel': leftHeel, 'toe': leftToe},
        'r': {'heel': 100, 'toe': 100},
      },
    };

    processor.processSample(sample(100, 3000));
    expect(processor.leftStepCount, 0);
    expect(processor.leftPressed, isTrue);

    processor.processSample(sample(100, 100));
    processor.processSample(sample(3000, 100));
    expect(processor.leftStepCount, 1);
  });

  test('firmware startup pressure does not count as a step', () {
    final processor = GaitProcessor();

    processor.processSample({
      'type': 'sample',
      'seq': 0,
      't': 0,
      'fsr': {
        'l': {'heel': 3000, 'toe': 3000},
        'r': {'heel': 3000, 'toe': 3000},
      },
    });
    processor.processSample({
      'type': 'sample',
      'seq': 1,
      't': 1600,
      'fsr': {
        'l': {'heel': 3000, 'toe': 3000},
        'r': {'heel': 3000, 'toe': 3000},
      },
    });

    expect(processor.totalStepCount, 0);
  });

  test('heel release and minimum interval prevent duplicate steps', () {
    final processor = GaitProcessor();

    Map<String, dynamic> sample(int seq, int time, int heel) => {
      'type': 'sample',
      'seq': seq,
      't': time,
      'fsr': {
        'l': {'heel': heel, 'toe': 100},
        'r': {'heel': 100, 'toe': 100},
      },
    };

    processor.processSample(sample(0, 0, 100));
    processor.processSample(sample(1, 1500, 2000));
    processor.processSample(sample(2, 1600, 1000));
    processor.processSample(sample(3, 1700, 2000));
    expect(processor.leftStepCount, 1);

    processor.processSample(sample(4, 2000, 1000));
    processor.processSample(sample(5, 2100, 2000));
    expect(processor.leftStepCount, 2);
  });

  test('simultaneous heel loading does not count two steps', () {
    final processor = GaitProcessor();

    Map<String, dynamic> sample(int seq, int time, int left, int right) => {
      'type': 'sample',
      'seq': seq,
      't': time,
      'fsr': {
        'l': {'heel': left, 'toe': 100},
        'r': {'heel': right, 'toe': 100},
      },
    };

    processor.processSample(sample(0, 0, 100, 100));
    processor.processSample(sample(1, 1600, 2500, 2500));

    expect(processor.totalStepCount, 0);
    expect(processor.currentLoadState, LoadState.both);
  });

  test('staggered heel loading within standing window is ignored', () {
    final processor = GaitProcessor();

    Map<String, dynamic> sample(int seq, int time, int left, int right) => {
      'type': 'sample',
      'seq': seq,
      't': time,
      'fsr': {
        'l': {'heel': left, 'toe': 100},
        'r': {'heel': right, 'toe': 100},
      },
    };

    processor.processSample(sample(0, 0, 100, 100));
    processor.processSample(sample(1, 1600, 2500, 100));
    processor.processSample(sample(2, 1700, 2500, 2500));

    expect(processor.totalStepCount, 0);
  });
}
