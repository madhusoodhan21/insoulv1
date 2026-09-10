#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// ---- FSR pins — 4 total now: heel + toe per foot. Raw ADC only, no
// thresholds/edge detection here — all interpretation lives in the app.
// Kept to ESP32's ADC1 pins (32-39) since ADC2 conflicts with WiFi/BT.
const int FSR_PIN_L_HEEL = 32;
const int FSR_PIN_L_TOE  = 34;
const int FSR_PIN_R_HEEL = 33;
const int FSR_PIN_R_TOE  = 35;

// ---- IMU ----
const uint8_t MPU6050_ADDRESS = 0x68;
const int MPU_SDA_PIN = 21;
const int MPU_SCL_PIN = 22;
bool imuReady = false;

// ---- Sample loop ----
const unsigned long SAMPLE_INTERVAL_MS = 20; // 50Hz
unsigned long lastSampleMs = 0;
uint32_t sampleSeq = 0;

// ---- Calibration offsets (computed automatically at startup or on 'c' command) ----
float gxOffset = 0.0, gyOffset = 0.0, gzOffset = 0.0;
float axOffset = 0.0, ayOffset = 0.0, azOffset = 0.0;
bool isCalibrated = false;

// Forward declarations
bool initMpu6050();
void calibrateMpu6050(int sampleCount = 500);
int16_t readMpuWord();
bool readImuRaw(float &ax, float &ay, float &az, float &gx, float &gy, float &gz);
void publishSample();
void sendJson(String json);

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    pServer->startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);

  Wire.begin(MPU_SDA_PIN, MPU_SCL_PIN);
  Wire.setClock(400000);
  imuReady = initMpu6050();
  if (imuReady) {
    Serial.println("MPU6050 detected on 0x68");
    Serial.println("Starting automatic MPU6050 calibration... Keep insole FLAT!");
    calibrateMpu6050(500);
  } else {
    Serial.println("MPU6050 not detected: check 3V3, GND, SDA=21, SCL=22");
  }

  BLEDevice::init("InSoul - V 0.04");
  BLEDevice::setMTU(185);

  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setValue("{}");

  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("BLE advertising started");
  Serial.println("Streaming raw samples at 50Hz (send 'c' over Serial to recalibrate MPU)...");
}

void loop() {
  // Allow manual recalibration trigger via Serial console
  if (Serial.available() > 0) {
    char ch = Serial.read();
    if ((ch == 'c' || ch == 'C') && imuReady) {
      calibrateMpu6050(500);
    }
  }

  if (millis() - lastSampleMs >= SAMPLE_INTERVAL_MS) {
    lastSampleMs = millis();
    publishSample();
  }
}

bool writeMpuRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool initMpu6050() {
  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(0x75); // WHO_AM_I
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(MPU6050_ADDRESS, (uint8_t)1) != 1) {
    return false;
  }
  uint8_t whoAmI = Wire.read();
  if (whoAmI != 0x68 && whoAmI != 0x69 && whoAmI != 0x70) {
    Serial.print("Unexpected MPU6050 WHO_AM_I: 0x");
    Serial.println(whoAmI, HEX);
    return false;
  }

  return writeMpuRegister(0x6B, 0x00) &&
         writeMpuRegister(0x1C, 0x00) &&
         writeMpuRegister(0x1B, 0x00);
}

void calibrateMpu6050(int sampleCount) {
  if (!imuReady) return;

  Serial.println("\n>>> CALIBRATING MPU6050... Keep insole flat & stationary! <<<");

  long sumRawAx = 0, sumRawAy = 0, sumRawAz = 0;
  long sumRawGx = 0, sumRawGy = 0, sumRawGz = 0;
  int validSamples = 0;

  for (int i = 0; i < sampleCount; i++) {
    Wire.beginTransmission(MPU6050_ADDRESS);
    Wire.write(0x3B);
    if (Wire.endTransmission(false) == 0 && Wire.requestFrom(MPU6050_ADDRESS, (uint8_t)14) == 14) {
      int16_t rAx = readMpuWord();
      int16_t rAy = readMpuWord();
      int16_t rAz = readMpuWord();
      readMpuWord(); // Skip temperature
      int16_t rGx = readMpuWord();
      int16_t rGy = readMpuWord();
      int16_t rGz = readMpuWord();

      sumRawAx += rAx;
      sumRawAy += rAy;
      sumRawAz += rAz;
      sumRawGx += rGx;
      sumRawGy += rGy;
      sumRawGz += rGz;
      validSamples++;
    }
    delay(2);
  }

  if (validSamples > 0) {
    // Gyro offsets (deg/s) at 131 LSB / (deg/s)
    gxOffset = ((float)sumRawGx / validSamples) / 131.0f;
    gyOffset = ((float)sumRawGy / validSamples) / 131.0f;
    gzOffset = ((float)sumRawGz / validSamples) / 131.0f;

    // Accel offsets (g) at 16384 LSB / g (expected 1g on Z axis when flat)
    axOffset = ((float)sumRawAx / validSamples) / 16384.0f;
    ayOffset = ((float)sumRawAy / validSamples) / 16384.0f;
    azOffset = (((float)sumRawAz / validSamples) / 16384.0f) - 1.0f;

    isCalibrated = true;
    Serial.println("=== MPU6050 CALIBRATION COMPLETE ===");
    Serial.printf("Gyro Offsets (deg/s):  Gx=%.3f, Gy=%.3f, Gz=%.3f\n", gxOffset, gyOffset, gzOffset);
    Serial.printf("Accel Offsets (g):      Ax=%.3f, Ay=%.3f, Az=%.3f\n", axOffset, ayOffset, azOffset);
  } else {
    Serial.println("Calibration failed: Could not read I2C samples.");
  }
}

int16_t readMpuWord() {
  return (int16_t)((Wire.read() << 8) | Wire.read());
}

bool readImuRaw(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  if (!imuReady) return false;

  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(MPU6050_ADDRESS, (uint8_t)14) != 14) {
    return false;
  }

  int16_t rawAx = readMpuWord();
  int16_t rawAy = readMpuWord();
  int16_t rawAz = readMpuWord();
  readMpuWord(); // temperature, unused
  int16_t rawGx = readMpuWord();
  int16_t rawGy = readMpuWord();
  int16_t rawGz = readMpuWord();

  // Convert raw values and subtract zero-calibration offsets
  ax = (rawAx / 16384.0f) - axOffset;
  ay = (rawAy / 16384.0f) - ayOffset;
  az = (rawAz / 16384.0f) - azOffset;
  gx = (rawGx / 131.0f) - gxOffset;
  gy = (rawGy / 131.0f) - gyOffset;
  gz = (rawGz / 131.0f) - gzOffset;
  return true;
}

// One message, everything raw: 4 FSR ADC counts (heel+toe per foot) +
// IMU floats + a sample clock (t) and sequence number (seq). No
// thresholds, no step detection, no symmetry — all app-side.
void publishSample() {
  int fsrLHeel = analogRead(FSR_PIN_L_HEEL);
  int fsrLToe  = analogRead(FSR_PIN_L_TOE);
  int fsrRHeel = analogRead(FSR_PIN_R_HEEL);
  int fsrRToe  = analogRead(FSR_PIN_R_TOE);

  float ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0;
  bool imuOk = readImuRaw(ax, ay, az, gx, gy, gz);

  String json = "{\"type\":\"sample\"";
  json += ",\"seq\":" + String(sampleSeq++);
  json += ",\"t\":" + String(millis());
  json += ",\"fsr\":{";
  json += "\"l\":{\"heel\":" + String(fsrLHeel) + ",\"toe\":" + String(fsrLToe) + "}";
  json += ",\"r\":{\"heel\":" + String(fsrRHeel) + ",\"toe\":" + String(fsrRToe) + "}";
  json += "}";

  if (imuOk) {
    json += ",\"imu\":{\"ax\":" + String(ax, 3) +
            ",\"ay\":" + String(ay, 3) +
            ",\"az\":" + String(az, 3) +
            ",\"gx\":" + String(gx, 2) +
            ",\"gy\":" + String(gy, 2) +
            ",\"gz\":" + String(gz, 2) + "}";
  }
  // imu omitted entirely when the read failed or the sensor never
  // initialized — app should treat a missing "imu" key as "no data
  // this sample," not "zeroed out."

  json += "}";

  sendJson(json);
}

void sendJson(String json) {
  Serial.println(json);
  if (deviceConnected) {
    pCharacteristic->setValue(json.c_str());
    pCharacteristic->notify();
  }
}