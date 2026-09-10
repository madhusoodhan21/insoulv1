import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gamepads/gamepads.dart';
import 'package:permission_handler/permission_handler.dart';

import 'gait_processor.dart';

class PressureSample {
  const PressureSample({
    required this.stepIndex,
    required this.timestampMs,
    required this.leftHeelPressure,
    required this.rightHeelPressure,
    this.leftToePressure = 0,
    this.rightToePressure = 0,
  });

  final int stepIndex;
  final int timestampMs;
  final double leftHeelPressure;
  final double rightHeelPressure;
  final double leftToePressure;
  final double rightToePressure;

  double get leftTotalPressure => leftHeelPressure + leftToePressure;
  double get rightTotalPressure => rightHeelPressure + rightToePressure;
}

/// InSoul insole BLE service.
///
/// This connection flow (permissions -> scan with webOptionalServices ->
/// connect with License.nonprofit -> discoverServices -> setNotifyValue(true)
/// -> THEN subscribe to onValueReceived) is copied from the button_counter
/// reference project after it was confirmed working on a real device and on
/// Flutter Web. Swap kServiceUuid / kCharacteristicUuid for the actual
/// insole firmware's UUIDs once that sketch exists; the connection mechanics
/// below don't need to change.
class BleService extends ChangeNotifier {
  // TODO: replace with the real InSoul insole service/characteristic UUIDs
  // once the sensor firmware is written. Left as the button-counter's UUIDs
  // for now so this is a drop-in, testable connection path.
  static const String kServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String kCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String kTargetDeviceName = "GaitSymmetryAnalyzer";
  static const Set<String> kTargetDeviceNames = {
    'GaitSymmetryAnalyzer',
    'SmartGait_L',
    'SmartGait_R',
    'InSoul',
    'ButtonCounter',
  };

  static bool isInSoulRelatedDeviceName(String? name) {
    if (name == null || name.trim().isEmpty) return false;

    final normalized = name.trim();
    final lowered = normalized.toLowerCase();

    return kTargetDeviceNames.any(
          (candidate) => candidate.toLowerCase() == lowered,
        ) ||
        lowered.contains('insoul') ||
        lowered.contains('smartgait') ||
        lowered.contains('gaitsymmetry') ||
        lowered.contains('buttoncounter');
  }

  final List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;

  BluetoothDevice? device;
  BluetoothConnectionState connectionState =
      BluetoothConnectionState.disconnected;
  String status = 'Not connected';

  // Live values received from the ESP32 gait firmware.
  bool pressureDetected = false;
  bool toeStandingActive = false;
  String? singleLegLoad;
  int? exerciseElapsedMs;
  int stepCount = 0;
  int leftStepCount = 0;
  int rightStepCount = 0;
  int exercisesCompleted = 0;
  final List<String> completedExerciseNames = <String>[];
  double? symmetryScore;
  int? leftToRightMs;
  int? rightToLeftMs;
  double? accelerationX;
  double? accelerationY;
  double? accelerationZ;
  double? gyroscopeX;
  double? gyroscopeY;
  double? gyroscopeZ;
  // FSR pressure values in kilograms (converted from ADC counts)
  int? leftHeelPressure;
  int? leftToePressure;
  int? rightHeelPressure;
  int? rightToePressure;
  DateTime? lastPacketAt;
  int packetCount = 0;
  final List<PressureSample> pressureSamples = <PressureSample>[];
  final List<String> debugSerialLines = <String>[];
  final List<String> gaitAnalysisSerialLines = <String>[];
  int _debugSampleSequence = 0;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanStateSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<void>? _servicesResetSub;
  StreamSubscription<GaitEvent>? _gaitSub;
  StreamSubscription<GamepadEvent>? _gamepadSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 20;
  bool _autoReconnect = true;
  bool _connecting = false;
  bool _hasEstablishedConnection = false;
  late GaitProcessor _gaitProcessor;

  // True once we've successfully read/subscribed at least once this app
  // session. Lets the UI keep showing the last real value (instead of a
  // placeholder) while a brief reconnect is in progress.
  bool hasEverConnected = false;

  bool get connected => connectionState == BluetoothConnectionState.connected;

  Stream<GaitEvent> get gaitEvents => _gaitProcessor.events;

  void setPressureDetected(bool value) {
    if (pressureDetected == value) return;
    pressureDetected = value;
    notifyListeners();
  }

  void recordExerciseCompleted(String exerciseName) {
    exercisesCompleted++;
    completedExerciseNames.add(exerciseName);
    notifyListeners();
  }

  void resetPressureSamples() {
    pressureSamples.clear();
    leftHeelPressure = 0;
    leftToePressure = 0;
    rightHeelPressure = 0;
    rightToePressure = 0;
    notifyListeners();
  }

  void startGaitAnalysisSerialCapture() {
    gaitAnalysisSerialLines.clear();
    _gaitAnalysisCaptureActive = true;
  }

  List<String> finishGaitAnalysisSerialCapture() {
    _gaitAnalysisCaptureActive = false;
    final capturedLines = List<String>.unmodifiable(gaitAnalysisSerialLines);
    gaitAnalysisSerialLines.clear();
    return capturedLines;
  }

  BleService({bool initialize = true}) {
    _gaitProcessor = GaitProcessor();
    _gaitSub = _gaitProcessor.events.listen(_handleGaitEvent);
    if (!initialize) return;
    _gamepadSub = Gamepads.events.listen(_handleGamepadEvent);
    _probeGamepads();
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      adapterState = s;
      notifyListeners();
    });
    _scanStateSub = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });
  }

  Future<void> _probeGamepads() async {
    try {
      final gamepads = await Gamepads.list();
      _appendDebugLine(
        jsonEncode({
          'type': 'gamepads',
          'count': gamepads.length,
          'controllers': gamepads.map((gamepad) => gamepad.name).toList(),
        }),
      );
    } catch (error) {
      _appendDebugLine(jsonEncode({'type': 'gamepads', 'error': '$error'}));
    }
  }

  void _handleGamepadEvent(GamepadEvent event) {
    if (connected) return;

    final key = event.key.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    _appendDebugLine(
      jsonEncode({
        'type': 'gamepad_event',
        'id': event.gamepadId,
        'key': event.key,
        'value': event.value,
      }),
    );

    final pressed = event.value.abs() > 0.2;
    final sensor = switch (key) {
      'right_trigger' ||
      'righttrigger' ||
      'right_trigger_axis' ||
      'righttriggeraxis' ||
      'r2' ||
      'trigger_7' ||
      'analog5' ||
      'analog_5' ||
      'button_7' ||
      'button_r2' ||
      'buttonrighttrigger' => ('R', 'toe'),
      'right_button' ||
      'rightbutton' ||
      'right_bumper' ||
      'rightbumper' ||
      'rb' ||
      'button_5' ||
      'button_rb' ||
      'buttonrightbumper' => ('R', 'heel'),
      'left_trigger' ||
      'lefttrigger' ||
      'left_trigger_axis' ||
      'lefttriggeraxis' ||
      'l2' ||
      'trigger_6' ||
      'analog4' ||
      'analog_4' ||
      'button_6' ||
      'button_l2' ||
      'buttonlefttrigger' => ('L', 'toe'),
      'left_button' ||
      'leftbutton' ||
      'left_bumper' ||
      'leftbumper' ||
      'lb' ||
      'button_4' ||
      'button_lb' ||
      'buttonleftbumper' => ('L', 'heel'),
      'a' || 'buttona' || 'button_0' => ('L', 'toe'),
      'b' || 'buttonb' || 'button_1' => ('L', 'heel'),
      'x' || 'buttonx' || 'button_2' => ('R', 'heel'),
      'y' || 'buttony' || 'button_3' => ('R', 'toe'),
      _ => null,
    };
    if (sensor != null) {
      debugSimulateSensorInput(sensor.$1, sensor.$2, pressed);
      return;
    }

    const gyroRange = 250.0;
    switch (key) {
      case 'rightthumbstickx':
      case 'right_stick_x':
      case 'rightstickx':
      case 'analog2':
      case 'analog_2':
        gyroscopeX = event.value * gyroRange;
      case 'rightthumbsticky':
      case 'right_stick_y':
      case 'rightsticky':
      case 'analog3':
      case 'analog_3':
        gyroscopeY = event.value * gyroRange;
      default:
        return;
    }
    debugSimulateGyroInput(gyroscopeX ?? 0, gyroscopeY ?? 0);
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final bluetoothDenied =
        [
          permissions[Permission.bluetoothScan],
          permissions[Permission.bluetoothConnect],
        ].any(
          (status) =>
              status == null ||
              status.isDenied ||
              status.isPermanentlyDenied ||
              status.isRestricted,
        );
    if (bluetoothDenied) {
      throw Exception('Bluetooth permissions were denied');
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;
    try {
      await _requestPermissions();
    } catch (e) {
      status = 'Scan blocked: $e';
      notifyListeners();
      return;
    }
    final adapterUnavailable =
        adapterState == BluetoothAdapterState.off ||
        adapterState == BluetoothAdapterState.unauthorized ||
        adapterState == BluetoothAdapterState.unavailable;
    if (!kIsWeb && adapterUnavailable) {
      status = 'Bluetooth is off or unavailable';
      notifyListeners();
      return;
    }
    scanResults.clear();
    isScanning = true;
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (!isInSoulRelatedDeviceName(deviceName)) {
          continue;
        }

        final idx = scanResults.indexWhere(
          (e) => e.device.remoteId == r.device.remoteId,
        );
        if (idx >= 0) {
          scanResults[idx] = r;
        } else {
          scanResults.add(r);
        }
      }
      scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        // Required for Flutter Web (Web Bluetooth's requestDevice() only
        // grants access to services listed here at scan time) — harmless
        // on Android/iOS.
        webOptionalServices: [Guid(kServiceUuid)],
      );
    } catch (_) {
      isScanning = false;
      status = 'Scan failed. Check Bluetooth permissions and try again.';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
  }

  Future<bool> connectTo(BluetoothDevice d) async {
    await stopScan();
    device = d;
    _autoReconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _hasEstablishedConnection = false;
    status = 'Connecting...';
    notifyListeners();

    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      connectionState = s;
      _appendDebugLine(jsonEncode({'type': 'ble_state', 'state': s.name}));
      if (s == BluetoothConnectionState.disconnected) {
        // The old GATT link is dead (e.g. the ESP32 was just re-flashed
        // and reset). Drop the stale subscriptions and, if we're supposed
        // to stay connected, start retrying instead of sitting frozen.
        _notifySub?.cancel();
        _servicesResetSub?.cancel();
        // FlutterBluePlus can emit the device's current disconnected state
        // immediately when the listener is attached. Do not treat that
        // initial value as a failed connection while _connect is in flight.
        if (_autoReconnect && !_connecting && _hasEstablishedConnection) {
          status = 'Reconnecting...';
          _scheduleReconnect(d);
        }
      }
      notifyListeners();
    });

    return _connect(d);
  }

  /// Retries the connection with a short backoff. This is the case that
  /// matters for "I pressed build on the ESP32" — the board reboots, the
  /// BLE link drops hard (no clean disconnect packet), and the ESP32 needs
  /// a few seconds to finish booting and start advertising again. A single
  /// fixed-timeout attempt often loses that race; retrying doesn't.
  void _scheduleReconnect(BluetoothDevice d) {
    _reconnectTimer?.cancel();
    if (!_autoReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      status = 'Lost connection — tap to reconnect';
      _autoReconnect = false;
      notifyListeners();
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts < 6 ? 2 : 5);
    status = 'Reconnecting (attempt $_reconnectAttempts)...';
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      if (_autoReconnect) _connect(d);
    });
  }

  Future<bool> _connect(BluetoothDevice d) async {
    if (_connecting) return false;
    _connecting = true;
    try {
      // license is a required parameter as of flutter_blue_plus 2.0 —
      // matches the verified-working reference project's connect() call.
      await d.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
      status = 'Connected — discovering services...';
      notifyListeners();
      final ready = await _discoverAndSubscribe(d);
      if (!ready) {
        // Wrong/missing service or characteristic — a real mismatch, not
        // a "still booting" issue, so don't keep retrying forever.
        _autoReconnect = false;
        await d.disconnect();
      } else {
        _reconnectAttempts = 0;
        _hasEstablishedConnection = true;
        hasEverConnected = true;
        _reconnectTimer?.cancel();
      }
      return ready;
    } catch (e) {
      // Most likely cause during development: the board hasn't finished
      // rebooting/re-advertising yet. Retry instead of giving up.
      status = 'Connect failed, retrying...';
      _appendDebugLine(jsonEncode({'type': 'ble_error', 'error': '$e'}));
      connectionState = BluetoothConnectionState.disconnected;
      notifyListeners();
      if (_autoReconnect) _scheduleReconnect(d);
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _discoverAndSubscribe(BluetoothDevice d) async {
    try {
      try {
        await d.requestMtu(247);
      } catch (_) {
        // not fatal, not all platforms support this
      }

      final services = await d.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == kServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Service UUID not found on device'),
      );
      final char = service.characteristics.firstWhere(
        (c) => c.uuid.str128.toLowerCase() == kCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Characteristic UUID not found'),
      );
      if (!char.properties.read && !char.properties.notify) {
        throw Exception('Step characteristic cannot be read or notified');
      }

      // Read the current value immediately so the UI isn't stuck at 0
      // until the next button press / step.
      if (char.properties.read) {
        final value = await char.read();
        _updateStepCountFromBytes(value);
      }

      // Enable notifications BEFORE subscribing to onValueReceived — this
      // ordering is what fixed the "connects but never receives data" bug.
      if (char.properties.notify) {
        await char.setNotifyValue(true);
        _notifySub?.cancel();
        _notifySub = char.onValueReceived.listen((value) {
          _updateStepCountFromBytes(value);
        });
      }

      // Android caches each device's GATT table. If the ESP32 reboots
      // while Android still thinks it's connected (common right after a
      // re-flash), Android can serve the *old* table/value. It signals a
      // change via the GAP "Service Changed" indication — when that fires,
      // we must re-discover services and re-subscribe or notifications
      // silently stop even though the app still shows "connected".
      _servicesResetSub?.cancel();
      _servicesResetSub = d.onServicesReset.listen((_) async {
        await _discoverAndSubscribe(d);
      });

      status = 'Connected — listening';
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Setup failed: $e';
      notifyListeners();
      return false;
    }
  }

  void _handleGaitEvent(GaitEvent event) {
    if (event is StepEvent) {
      stepCount = event.totalSteps;
      leftStepCount = event.leftSteps;
      rightStepCount = event.rightSteps;
    } else if (event is LoadStateChangedEvent) {
      pressureDetected = event.active;
      toeStandingActive = _gaitProcessor.toeStandingActive;
      singleLegLoad = switch (event.state) {
        LoadState.none => 'NONE',
        LoadState.leftOnly => 'L',
        LoadState.rightOnly => 'R',
        LoadState.both => 'NONE',
      };
    } else if (event is SymmetryComputedEvent) {
      symmetryScore = event.score;
      leftToRightMs = event.avgLToR.round();
      rightToLeftMs = event.avgRToL.round();
    } else if (event is PacketGapEvent) {
      // Sequence gaps are informational; they are not timing errors in the
      // raw BLE stream and should not be treated as a sensor fault here.
    }
    notifyListeners();
  }

  /// Parses raw sample payloads and forwards them to the gait processor.
  void _updateStepCountFromBytes(List<int> value) {
    final str = utf8.decode(value, allowMalformed: true).trim();
    if (str.isEmpty) {
      return;
    }
    _appendDebugLine(str);

    try {
      final packet = jsonDecode(str);
      if (packet is! Map) {
        return;
      }

      final type = packet['type'];
      if (type != 'sample') {
        return;
      }

      final sample = <String, dynamic>{};
      for (final entry in packet.entries) {
        if (entry.key is String) {
          sample[entry.key as String] = entry.value;
        }
      }

      final fsr = sample['fsr'];
      if (fsr is Map) {
        final leftFsr = fsr['l'];
        final rightFsr = fsr['r'];
        if (leftFsr is Map) {
          leftHeelPressure = _intValue(leftFsr['heel']);
          leftToePressure = _intValue(leftFsr['toe']);
        }
        if (rightFsr is Map) {
          rightHeelPressure = _intValue(rightFsr['heel']);
          rightToePressure = _intValue(rightFsr['toe']);
        }
        _recordPressureSample(sample);
      }

      _gaitProcessor.processSample(sample);
      toeStandingActive = _gaitProcessor.toeStandingActive;

      final imu = sample['imu'];
      if (imu is Map) {
        final imuMap = Map<String, dynamic>.from(imu);
        accelerationX = _numberValue(imuMap['ax']);
        accelerationY = _numberValue(imuMap['ay']);
        accelerationZ = _numberValue(imuMap['az']);
        gyroscopeX = _numberValue(imuMap['gx']);
        gyroscopeY = _numberValue(imuMap['gy']);
        gyroscopeZ = _numberValue(imuMap['gz']);
      }

      packetCount++;
      lastPacketAt = DateTime.now();
      notifyListeners();
    } on FormatException {
      // Ignore an incomplete or malformed BLE packet.
    }
  }

  void _recordPressureSample(Map<String, dynamic> sample) {
    final leftH = leftHeelPressure;
    final rightH = rightHeelPressure;
    final leftT = leftToePressure;
    final rightT = rightToePressure;
    if (leftH == null && rightH == null && leftT == null && rightT == null) return;

    pressureSamples.add(
      PressureSample(
        stepIndex: stepCount,
        timestampMs:
            _intValue(sample['t']) ?? DateTime.now().millisecondsSinceEpoch,
        leftHeelPressure: leftH?.toDouble() ?? 0,
        rightHeelPressure: rightH?.toDouble() ?? 0,
        leftToePressure: leftT?.toDouble() ?? 0,
        rightToePressure: rightT?.toDouble() ?? 0,
      ),
    );
    // Keep enough continuous samples for a 20-50 Hz stream without allowing
    // the chart history to grow without bound.
    while (pressureSamples.length > 600) {
      pressureSamples.removeAt(0);
    }
  }

  double? _numberValue(Object? value) {
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  int? _intValue(Object? value) {
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  bool? _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _hasEstablishedConnection = false;
    _reconnectTimer?.cancel();
    _servicesResetSub?.cancel();
    await device?.disconnect();
    status = 'Not connected';
    pressureDetected = false;
    toeStandingActive = false;
    singleLegLoad = null;
    exerciseElapsedMs = null;
    stepCount = 0;
    leftStepCount = 0;
    rightStepCount = 0;
    symmetryScore = null;
    leftToRightMs = null;
    rightToLeftMs = null;
    accelerationX = null;
    accelerationY = null;
    accelerationZ = null;
    gyroscopeX = null;
    gyroscopeY = null;
    gyroscopeZ = null;
    leftHeelPressure = null;
    leftToePressure = null;
    rightHeelPressure = null;
    rightToePressure = null;
    lastPacketAt = null;
    packetCount = 0;
    pressureSamples.clear();
    hasEverConnected = false;
    _gaitProcessor.dispose();
    _gaitProcessor = GaitProcessor();
    _gaitSub?.cancel();
    _gaitSub = _gaitProcessor.events.listen(_handleGaitEvent);
    notifyListeners();
  }

  @override
  void dispose() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _gamepadSub?.cancel();
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    _adapterSub?.cancel();
    _simLeftToeTimer?.cancel();
    _simRightToeTimer?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _servicesResetSub?.cancel();
    _gaitSub?.cancel();
    _gaitProcessor.dispose();
    super.dispose();
  }

  Timer? _simLeftToeTimer;
  Timer? _simRightToeTimer;

  /// Debugging method: Simulate sensor input via keyboard
  void debugSimulateSensorInput(String foot, String sensor, bool pressed) {
    final pressure = pressed ? 3500 : 0;

    if (foot == 'L') {
      if (sensor == 'heel') {
        leftHeelPressure = pressure;
        _simLeftToeTimer?.cancel();
        if (pressed) {
          _simLeftToeTimer = Timer(const Duration(milliseconds: 100), () {
            leftToePressure = 3400;
            _appendDebugSample();
          });
        } else {
          _simLeftToeTimer = Timer(const Duration(milliseconds: 100), () {
            leftToePressure = 0;
            _appendDebugSample();
          });
        }
      } else if (sensor == 'toe') {
        _simLeftToeTimer?.cancel();
        leftToePressure = pressure;
      }
    } else if (foot == 'R') {
      if (sensor == 'heel') {
        rightHeelPressure = pressure;
        _simRightToeTimer?.cancel();
        if (pressed) {
          _simRightToeTimer = Timer(const Duration(milliseconds: 100), () {
            rightToePressure = 3400;
            _appendDebugSample();
          });
        } else {
          _simRightToeTimer = Timer(const Duration(milliseconds: 100), () {
            rightToePressure = 0;
            _appendDebugSample();
          });
        }
      } else if (sensor == 'toe') {
        _simRightToeTimer?.cancel();
        rightToePressure = pressure;
      }
    }

    _appendDebugSample();
  }

  /// Debugging method: Simulate MPU6050 gyro input from a controller.
  void debugSimulateGyroInput(double gx, double gy) {
    _appendDebugSample(
      imu: {'ax': 0, 'ay': 0, 'az': 0, 'gx': gx, 'gy': gy, 'gz': 0},
    );
  }

  void _appendDebugSample({Map<String, dynamic>? imu}) {
    final sample = <String, dynamic>{
      'type': 'sample',
      'seq': _debugSampleSequence++,
      't': DateTime.now().millisecondsSinceEpoch,
      'fsr': {
        'l': {'heel': leftHeelPressure ?? 0, 'toe': leftToePressure ?? 0},
        'r': {'heel': rightHeelPressure ?? 0, 'toe': rightToePressure ?? 0},
      },
    };
    if (imu != null) sample['imu'] = imu;
    final encoded = jsonEncode(sample);
    _updateStepCountFromBytes(utf8.encode(encoded));
  }

  void _appendDebugLine(String line) {
    debugSerialLines.add(line);
    if (debugSerialLines.length > 200) {
      debugSerialLines.removeAt(0);
    }
    if (gaitAnalysisSerialLines.isNotEmpty || _gaitAnalysisCaptureActive) {
      gaitAnalysisSerialLines.add(line);
    }
    notifyListeners();
  }

  bool _gaitAnalysisCaptureActive = false;

  void clearDebugSerialLines() {
    debugSerialLines.clear();
    notifyListeners();
  }
}
