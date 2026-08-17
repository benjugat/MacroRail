#include <SoftwareSerial.h>
#include <IRremote.hpp>
#include <AccelStepper.h>

// Hardware
constexpr uint8_t BT_RX_PIN = 3;
constexpr uint8_t BT_TX_PIN = 2;
constexpr uint8_t IR_SEND_PIN = 4;
constexpr uint8_t HOME_SWITCH_PIN = 8;
constexpr uint8_t END_SWITCH_PIN = 7;
constexpr uint8_t MOTOR_DIR_PIN = 9;
constexpr uint8_t MOTOR_STEP_PIN = 10;

// Mechanics: 200 step/rev * 32 microsteps / 2 mm per revolution.
constexpr float STEPS_PER_MM = 3200.0f;
constexpr float STEPS_PER_UM = STEPS_PER_MM / 1000.0f;
// Values expressed as 1/32 microsteps. These are equivalent to the previous
// 400 full-steps/s, 200 full-steps/s^2 and 200 full-steps/s homing speed.
constexpr float MAX_SPEED_STEPS_S = 12800.0f;
constexpr float ACCELERATION_STEPS_S2 = 6400.0f;
constexpr float HOME_SPEED_STEPS_S = 6400.0f;
constexpr long SWITCH_RELEASE_STEPS = 3200;  // 1 mm at 3200 microsteps/mm

SoftwareSerial BT(BT_RX_PIN, BT_TX_PIN);
AccelStepper stepper(AccelStepper::DRIVER, MOTOR_STEP_PIN, MOTOR_DIR_PIN);

enum State {
  IDLE,
  MANUAL_MOVE,
  HOMING,
  HOME_BACKOFF,
  END_BACKOFF,
  AUTO_DELAY,
  AUTO_EXPOSURE,
  AUTO_MOVE
};

State state = IDLE;
String inputBuffer;

uint32_t delayMs = 0;
uint32_t exposureMs = 0;
uint32_t stateStartedMs = 0;

long autoSpacingSteps = 0;
int autoPhotoCount = 0;
int autoPhotosTaken = 0;
bool autoPendingAfterHome = false;

void sendMessage(const String &message) {
  BT.println(message);
  Serial.println(message);
}

bool elapsedMs(uint32_t durationMs) {
  return (uint32_t)(millis() - stateStartedMs) >= durationMs;
}

long micrometersToSteps(long um) {
  return lround((float)um * STEPS_PER_UM);
}

bool motorIsMoving() {
  return state == MANUAL_MOVE || state == HOMING ||
         state == HOME_BACKOFF || state == END_BACKOFF ||
         state == AUTO_MOVE;
}

void stopMotor() {
  // setCurrentPosition also makes target == current and resets speed to zero.
  stepper.setCurrentPosition(stepper.currentPosition());
  digitalWrite(MOTOR_STEP_PIN, LOW);
  state = IDLE;
  autoPhotoCount = 0;
  autoPhotosTaken = 0;
  autoPendingAfterHome = false;
}

void sendPhotoIR() {
  uint16_t rawData[] = {
    2400, 600,
    1200, 600,
    600, 600,
    1200, 600,
    1200, 600,
    600, 600,
    1200, 600,
    600, 600,
    600, 600,
    1200, 600,
    600, 600,
    1200, 600,
    1200, 600,
    1200, 600,
    600, 600,
    600, 600,
    600, 600,
    1200, 600,
    1200, 600,
    1200, 600,
    1200, 600
  };

  IrSender.sendRaw(rawData, sizeof(rawData) / sizeof(rawData[0]), 40);
  sendMessage("PHOTO");
}

void startMoveUm(long um) {
  long steps = micrometersToSteps(um);

  // Every MOVE replaces the previous movement. Resetting the current target
  // and speed makes a negative command change direction immediately instead
  // of first completing or decelerating from an earlier command.
  stopMotor();

  if (steps == 0) {
    sendMessage("MOVE DONE");
    return;
  }

  stepper.move(steps);
  state = MANUAL_MOVE;
  sendMessage("MOVE " + String(um) + " UM");
}

void startHome() {
  stopMotor();
  stepper.setSpeed(-HOME_SPEED_STEPS_S);
  state = HOMING;
  sendMessage("HOME");
}

void startAutomatic(long spacingUm, int photoCount) {
  if (photoCount <= 0) {
    sendMessage("ERROR AUTO QUANTITY");
    return;
  }

  stopMotor();
  autoSpacingSteps = micrometersToSteps(spacingUm);
  autoPhotoCount = photoCount;
  autoPhotosTaken = 0;
  autoPendingAfterHome = true;
  stepper.setSpeed(-HOME_SPEED_STEPS_S);
  state = HOMING;
  sendMessage("AUTO START " + String(photoCount) + " PHOTOS");
  sendMessage("HOME");
}

void updateMotorAndSequence() {
  const bool homeSwitchPressed = digitalRead(HOME_SWITCH_PIN) == LOW;
  const bool endSwitchPressed = digitalRead(END_SWITCH_PIN) == LOW;

  // D8 defines HOME and therefore starts the release movement when homing.
  if (homeSwitchPressed) {
    if (state == HOMING) {
      stepper.setCurrentPosition(stepper.currentPosition());
      stepper.move(SWITCH_RELEASE_STEPS);
      state = HOME_BACKOFF;
      sendMessage("LIMIT HOME");
      return;
    }

    if (state == MANUAL_MOVE || state == AUTO_MOVE) {
      stopMotor();
      stepper.move(SWITCH_RELEASE_STEPS);
      state = HOME_BACKOFF;
      sendMessage("LIMIT HOME RELEASE");
      return;
    }
  }

  // D7 is the opposite end stop. It cancels every kind of active movement,
  // including HOME, because a HOME search should never reach this end.
  if (endSwitchPressed &&
      (state == MANUAL_MOVE || state == HOMING ||
       state == AUTO_MOVE)) {
    stopMotor();
    stepper.move(-SWITCH_RELEASE_STEPS);
    state = END_BACKOFF;
    sendMessage("LIMIT END RELEASE");
    return;
  }

  switch (state) {
    case IDLE:
      break;

    case MANUAL_MOVE:
      stepper.run();
      if (stepper.distanceToGo() == 0) {
        state = IDLE;
        digitalWrite(MOTOR_STEP_PIN, LOW);
        sendMessage("MOVE DONE");
      }
      break;

    case HOMING:
      stepper.runSpeed();
      break;

    case HOME_BACKOFF:
      stepper.run();
      if (stepper.distanceToGo() == 0) {
        stepper.setCurrentPosition(0);
        digitalWrite(MOTOR_STEP_PIN, LOW);
        sendMessage("HOME OK");
        if (autoPendingAfterHome) {
          autoPendingAfterHome = false;
          stateStartedMs = millis();
          state = AUTO_DELAY;
          sendMessage("AUTO READY");
        } else {
          state = IDLE;
        }
      }
      break;

    case END_BACKOFF:
      stepper.run();
      if (stepper.distanceToGo() == 0) {
        state = IDLE;
        digitalWrite(MOTOR_STEP_PIN, LOW);
        sendMessage("LIMIT RELEASED");
      }
      break;

    case AUTO_DELAY:
      if (elapsedMs(delayMs)) {
        sendPhotoIR();
        autoPhotosTaken++;
        stateStartedMs = millis();
        state = AUTO_EXPOSURE;
      }
      break;

    case AUTO_EXPOSURE:
      if (elapsedMs(exposureMs)) {
        if (autoPhotosTaken >= autoPhotoCount) {
          state = IDLE;
          sendMessage("AUTO DONE");
        } else if (autoSpacingSteps == 0) {
          stateStartedMs = millis();
          state = AUTO_DELAY;
        } else {
          stepper.move(autoSpacingSteps);
          state = AUTO_MOVE;
        }
      }
      break;

    case AUTO_MOVE:
      stepper.run();
      if (stepper.distanceToGo() == 0) {
        digitalWrite(MOTOR_STEP_PIN, LOW);
        stateStartedMs = millis();
        state = AUTO_DELAY;
      }
      break;
  }
}

void processCommand(String command) {
  command.trim();
  command.toUpperCase();

  if (command == "PING") {
    sendMessage("PONG");
  } else if (command == "HOME") {
    startHome();
  } else if (command == "PHOTO") {
    sendPhotoIR();
  } else if (command == "STOP") {
    stopMotor();
    sendMessage("STOP");
  } else if (command == "STATUS") {
    sendMessage(motorIsMoving() ? "STATUS MOVING" : "STATUS STOPPED");
  } else if (command.startsWith("CONFIG DELAY ")) {
    delayMs = (uint32_t)command.substring(13).toInt();
    sendMessage("OK CONFIG DELAY " + String(delayMs));
  } else if (command.startsWith("CONFIG EXPOSURE ")) {
    exposureMs = (uint32_t)command.substring(16).toInt();
    sendMessage("OK CONFIG EXPOSURE " + String(exposureMs));
  } else if (command.startsWith("MOVE ")) {
    startMoveUm(command.substring(5).toInt());
  } else if (command.startsWith("AUTO ")) {
    String arguments = command.substring(5);
    int separator = arguments.indexOf(' ');
    if (separator < 1) {
      sendMessage("ERROR AUTO FORMAT");
      return;
    }

    long spacingUm = arguments.substring(0, separator).toInt();
    int photoCount = arguments.substring(separator + 1).toInt();
    startAutomatic(spacingUm, photoCount);
  } else {
    sendMessage("UNKNOWN");
  }
}

void readBluetooth() {
  while (BT.available()) {
    char received = BT.read();
    if (received == '\n' || received == '\r') {
      if (inputBuffer.length() > 0) {
        processCommand(inputBuffer);
        inputBuffer = "";
      }
    } else if (inputBuffer.length() < 64) {
      inputBuffer += received;
    } else {
      inputBuffer = "";
      sendMessage("ERROR COMMAND TOO LONG");
    }
  }
}

void setup() {
  pinMode(MOTOR_STEP_PIN, OUTPUT);
  digitalWrite(MOTOR_STEP_PIN, LOW);
  pinMode(MOTOR_DIR_PIN, OUTPUT);
  digitalWrite(MOTOR_DIR_PIN, LOW);
  pinMode(HOME_SWITCH_PIN, INPUT_PULLUP);
  pinMode(END_SWITCH_PIN, INPUT_PULLUP);

  Serial.begin(9600);
  BT.begin(9600);
  IrSender.begin(IR_SEND_PIN);

  stepper.setMaxSpeed(MAX_SPEED_STEPS_S);
  stepper.setAcceleration(ACCELERATION_STEPS_S2);
  // Positive positions move clockwise, away from HOME. Negative positions and
  // the HOME search move counter-clockwise, towards position zero.
  stepper.setPinsInverted(false, false, false);
  stepper.setCurrentPosition(0);

  sendMessage("READY");
}

void loop() {
  readBluetooth();
  updateMotorAndSequence();
}
