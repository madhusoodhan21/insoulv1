#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// How many CROSS-FOOT intervals (L->R and R->L) to collect before
// computing symmetry. SAMPLE_STEPS total step events = SAMPLE_STEPS/2
// of each transition.
const int SAMPLE_STEPS = 10;

const uint8_t MPU6050_ADDRESS = 0x68;
const int MPU_SDA_PIN = 21;
const int MPU_SCL_PIN = 22;
const unsigned long IMU_INTERVAL_MS = 100;
unsigned long lastImuRead = 0;
bool imuReady = false;

// One of these per foot — keeps the two sensors' edge-detection state
// completely separate. Timing/interval data now lives outside this
// struct since we're measuring the gap BETWEEN feet, not within one.
struct FootSensor {
  const char* label;
  int pin;
  int pressThreshold;
  int releaseThreshold;

  bool isPressed = false;
  int pressCount = 0;
};

// Tune thresholds per sensor after watching raw values — two FSRs rarely
// read identically even under the same pressure.
FootSensor footL = {"L", 34, 2800, 1500};
FootSensor footR = {"R", 35, 2800, 1500};

// Cross-foot timing: gap from an L step to the next R step, and from
// an R step to the next L step. This is what actually reveals a limp —
// each foot's OWN stride time stays roughly equal even when limping,
// because L and R are mechanically locked to the same overall cadence.
// What differs is how long you linger on one foot before pushing off
// to the other.
unsigned long lastStepTime = 0;
char lastStepFoot = 0; // 'L' or 'R', whichever stepped most recently

unsigned long transitionsLtoR[SAMPLE_STEPS / 2];
unsigned long transitionsRtoL[SAMPLE_STEPS / 2];
int countLtoR = 0;
int countRtoL = 0;

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
  } else {
    Serial.println("MPU6050 not detected: check 3V3, GND, SDA=21, SCL=22");
  }

  BLEDevice::init("GaitSymmetryAnalyzer");

  // Default BLE MTU is 23 bytes (20 usable) — too small for JSON once
  // it grows. Request a bigger one; the phone side will negotiate down
  // to whatever it supports, but this avoids truncated notifies on iOS/
  // Android which both allow larger MTUs.
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
  Serial.println("Walk normally — collecting steps...");
}

void loop() {
  pollFoot(footL);
  pollFoot(footR);
  publishImu();
  delay(20);
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

  // Wake the device, +/-2g accelerometer, and +/-250 degrees/sec gyro.
  return writeMpuRegister(0x6B, 0x00) &&
         writeMpuRegister(0x1C, 0x00) &&
         writeMpuRegister(0x1B, 0x00);
}

int16_t readMpuWord() {
  return (int16_t)((Wire.read() << 8) | Wire.read());
}

void publishImu() {
  if (!imuReady || millis() - lastImuRead < IMU_INTERVAL_MS) return;
  lastImuRead = millis();

  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(0x3B); // ACCEL_XOUT_H; read accel, temperature, and gyro together
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(MPU6050_ADDRESS, (uint8_t)14) != 14) {
    Serial.println("MPU6050 read failed");
    return;
  }

  int16_t rawAx = readMpuWord();
  int16_t rawAy = readMpuWord();
  int16_t rawAz = readMpuWord();
  readMpuWord(); // temperature
  int16_t rawGx = readMpuWord();
  int16_t rawGy = readMpuWord();
  int16_t rawGz = readMpuWord();

  float ax = rawAx / 16384.0;
  float ay = rawAy / 16384.0;
  float az = rawAz / 16384.0;
  float gx = rawGx / 131.0;
  float gy = rawGy / 131.0;
  float gz = rawGz / 131.0;

  String imuJson = "{\"type\":\"imu\",\"imu\":{\"ax\":" + String(ax, 3) +
                   ",\"ay\":" + String(ay, 3) +
                   ",\"az\":" + String(az, 3) +
                   ",\"gx\":" + String(gx, 2) +
                   ",\"gy\":" + String(gy, 2) +
                   ",\"gz\":" + String(gz, 2) + "}}";
  sendJson(imuJson);
}

void pollFoot(FootSensor &foot) {
  int val = analogRead(foot.pin);

  // Uncomment while calibrating each sensor:
  // Serial.print(foot.label); Serial.print(": "); Serial.println(val);

  if (!foot.isPressed && val > foot.pressThreshold) {
    foot.isPressed = true;
    registerStep(foot);
  }
  else if (foot.isPressed && val < foot.releaseThreshold) {
    foot.isPressed = false;
  }
}

// Sends one JSON object per BLE notify, always with a "type" field so
// the Flutter side can switch on it:
//   {"type":"count","total":128,"l":65,"r":63}
//   {"type":"symmetry","score":91.2,"ltrMs":610,"rtlMs":600}
void sendJson(String json) {
  Serial.println(json);
  if (deviceConnected) {
    pCharacteristic->setValue(json.c_str());
    pCharacteristic->notify();
  }
}

void registerStep(FootSensor &foot) {
  unsigned long now = millis();

  foot.pressCount++;
  int totalSteps = footL.pressCount + footR.pressCount;

  String countJson = "{\"type\":\"count\",\"total\":" + String(totalSteps) +
                      ",\"l\":" + String(footL.pressCount) +
                      ",\"r\":" + String(footR.pressCount) + "}";
  sendJson(countJson);

  // Record the transition INTO this foot from whichever foot stepped last.
  // Ignore same-foot repeats (foot.label == lastStepFoot) — those mean a
  // step got missed on the other side or this is the very first step.
  char thisFoot = foot.label[0];
  if (lastStepFoot == 0) {
    lastStepTime = now;
    lastStepFoot = thisFoot;
  } else if (lastStepFoot != thisFoot) {
    unsigned long gap = now - lastStepTime;

    if (lastStepFoot == 'L' && thisFoot == 'R' && countLtoR < SAMPLE_STEPS / 2) {
      transitionsLtoR[countLtoR++] = gap;
    } else if (lastStepFoot == 'R' && thisFoot == 'L' && countRtoL < SAMPLE_STEPS / 2) {
      transitionsRtoL[countRtoL++] = gap;
    }

    // Advance the transition clock only for a genuine opposite-foot step.
    lastStepTime = now;
    lastStepFoot = thisFoot;
  }

  // Once we have a full batch of both transition types, compare them
  if (countLtoR == SAMPLE_STEPS / 2 && countRtoL == SAMPLE_STEPS / 2) {
    reportSymmetry();
    countLtoR = 0;
    countRtoL = 0;
  }
}

float averageOf(unsigned long *arr, int n) {
  unsigned long sum = 0;
  for (int i = 0; i < n; i++) sum += arr[i];
  return (float)sum / n;
}

// Real limp-detecting symmetry: how long you spend going from a left
// step to the next right step, versus right-to-left. A limp shows up
// here because you push off the sore foot faster (or slower) than the
// healthy one — same-foot stride time alone hides this.
void reportSymmetry() {
  float avgLtoR = averageOf(transitionsLtoR, SAMPLE_STEPS / 2);
  float avgRtoL = averageOf(transitionsRtoL, SAMPLE_STEPS / 2);
  float avgAll = (avgLtoR + avgRtoL) / 2.0;

  // 0% = perfectly symmetric, higher = bigger timing gap between sides
  float symmetryIndex = (abs(avgLtoR - avgRtoL) / avgAll) * 100.0;
  float symmetryScore = 100.0 - symmetryIndex; // 100% = perfectly symmetric
  symmetryScore = constrain(symmetryScore, 0.0, 100.0);

  String symJson = "{\"type\":\"symmetry\",\"score\":" + String(symmetryScore, 1) +
                    ",\"ltrMs\":" + String((int)avgLtoR) +
                    ",\"rtlMs\":" + String((int)avgRtoL) + "}";
  sendJson(symJson);
}
