/*
  SSP5A Arduino Controller - SSPCARD Emulation Version
  Enhanced to better emulate SSPCARD hardware for SSPDataq3 compatibility
  
  Uses RX pin (Pin 0) for pulse input
  
  Key Enhancements for SSPDataq3:
  1. Initial "SSPCARD" identification response
  2. Proper command/response timing
  3. SSPCARD-like error handling
  4. Hardware flow control emulation (if needed)
  
  Memory Optimizations:
  - No SoftwareSerial debug
  - Smaller buffers
  - Optimized data types
*/

#include <AccelStepper.h>

// ============================================================================
// HARDWARE CONFIGURATION - USING RX PIN (PIN 0)
// ============================================================================

#define PULSE_PIN        0     // RX pin (Digital Pin 0) for pulse counting
#define X_STEP_PIN       2     // CNC Shield X-STEP (D2)
#define X_DIR_PIN        5     // CNC Shield X-DIR (D5)
#define X_EN_PIN         12    // CNC Shield X-ENABLE (D12)
#define Y_STEP_PIN       3     // CNC Shield Y-STEP (D3)
#define Y_DIR_PIN        6     // CNC Shield Y-DIR (D6)
#define Y_EN_PIN         13    // CNC Shield Y-ENABLE (D13)
#define STATUS_LED       13    // Built-in LED (shared with Y_ENABLE)

// ============================================================================
// SYSTEM CONSTANTS
// ============================================================================

#define SSP_BAUD             19200
#define SERIAL_BUFFER_SIZE   16
#define COMMAND_TIMEOUT_MS   100
#define INTEGRATION_MIN      1
#define INTEGRATION_MAX      9999
#define NUM_FILTERS          6
#define FILTER_MOVE_TIME     100

// SSPCARD Identification
#define SSPCARD_ID           "SSPCARD"

// ============================================================================
// CONFIGURATION
// ============================================================================

const struct {
    uint16_t filterPositions[6];
    uint16_t defaultIntegrationTime;
    uint8_t defaultGain;
} config = {
    .filterPositions = {0, 200, 400, 600, 800, 1000},
    .defaultIntegrationTime = 1000,
    .defaultGain = 1
};

// ============================================================================
// SYSTEM STATE
// ============================================================================

struct SystemState {
    uint8_t currentFilter : 3;
    uint8_t currentGain : 2;
    uint16_t integrationTime;
    bool mirrorState : 1;
    bool serialMode : 1;
    bool integrationActive : 1;
    bool stepperMoving : 1;
    uint32_t totalPulses;
    uint16_t errorCode;
    uint32_t lastCommandTime;
    bool identified;  // SSPCARD identification sent flag
};

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

AccelStepper stepperX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN);
AccelStepper stepperY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN);

volatile uint32_t pulseCount = 0;
volatile bool countingActive = false;

uint32_t integrationStartTime = 0;
uint32_t integrationDuration = 0;

char serialBuffer[SERIAL_BUFFER_SIZE];
uint8_t bufferIndex = 0;
uint32_t lastCharTime = 0;

SystemState systemState;

// ============================================================================
// PULSE COUNTING
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(PULSE_PIN), pulseISR, RISING);
}

void pulseISR() {
    if (countingActive) {
        pulseCount++;
        if (pulseCount > 65535) pulseCount = 0;
    }
}

void startCounting() {
    noInterrupts();
    pulseCount = 0;
    countingActive = true;
    interrupts();
}

uint16_t stopCounting() {
    noInterrupts();
    countingActive = false;
    uint32_t count = pulseCount;
    interrupts();
    return (count > 65535) ? 65535 : (uint16_t)count;
}

uint16_t getCurrentCount() {
    noInterrupts();
    uint32_t count = pulseCount;
    interrupts();
    return (count > 65535) ? 65535 : (uint16_t)count;
}

// ============================================================================
// INTEGRATION TIMER
// ============================================================================

void startIntegration(uint16_t duration_ms) {
    systemState.integrationTime = duration_ms;
    integrationStartTime = millis();
    integrationDuration = duration_ms;
    systemState.integrationActive = true;
    startCounting();
}

bool checkIntegrationComplete() {
    if (!systemState.integrationActive) return false;
    
    uint32_t elapsed = millis() - integrationStartTime;
    if (elapsed > 0x7FFFFFFF) {
        integrationStartTime = millis();
        elapsed = 0;
    }
    
    if (elapsed >= integrationDuration) {
        systemState.integrationActive = false;
        stopCounting();
        return true;
    }
    
    return false;
}

// ============================================================================
// STEPPER CONTROL
// ============================================================================

void setupStepperControl() {
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    digitalWrite(X_EN_PIN, LOW);
    digitalWrite(Y_EN_PIN, LOW);
    
    stepperX.setMaxSpeed(1000.0);
    stepperX.setSpeed(500.0);
    stepperY.setMaxSpeed(1000.0);
    stepperY.setSpeed(500.0);
    
    stepperX.setCurrentPosition(0);
    stepperY.setCurrentPosition(0);
    
    systemState.stepperMoving = false;
}

void moveToFilterPosition(uint8_t position) {
    if (position < 1 || position > NUM_FILTERS) return;
    
    uint16_t targetSteps = config.filterPositions[position - 1];
    float speed = 200.0 / (FILTER_MOVE_TIME / 1000.0);
    
    stepperX.setSpeed(speed);
    stepperX.moveTo(targetSteps);
    systemState.stepperMoving = true;
    systemState.currentFilter = position;
}

void updateStepperMovement() {
    if (systemState.stepperMoving) {
        stepperX.runSpeedToPosition();
        stepperY.runSpeedToPosition();
        
        if (stepperX.distanceToGo() == 0 && stepperY.distanceToGo() == 0) {
            systemState.stepperMoving = false;
        }
    }
}

void startHomingRoutine() {
    moveToFilterPosition(1);
    
    unsigned long homingStart = millis();
    while (systemState.stepperMoving && (millis() - homingStart) < 5000) {
        updateStepperMovement();
    }
    
    if (systemState.stepperMoving) {
        stepperX.stop();
        systemState.stepperMoving = false;
    }
}

// ============================================================================
// SERIAL COMMUNICATION - SSPCARD EMULATION
// ============================================================================

void handleSerialCommunication() {
    // Send SSPCARD identification on first connection
    if (!systemState.identified && Serial) {
        delay(100); // Wait for connection to stabilize
        Serial.print(SSPCARD_ID);
        Serial.print("\r\n");
        systemState.identified = true;
    }
    
    // Read incoming serial data
    while (Serial.available()) {
        char c = Serial.read();
        lastCharTime = millis();
        
        if (c == '\r' || c == '\n') {
            if (bufferIndex > 0) {
                serialBuffer[bufferIndex] = '\0';
                processCommand(serialBuffer);
                bufferIndex = 0;
            }
        } else if (bufferIndex < SERIAL_BUFFER_SIZE - 1) {
            serialBuffer[bufferIndex++] = c;
        } else {
            bufferIndex = 0;
            Serial.print("?");
        }
    }
    
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        bufferIndex = 0;
        Serial.print("?");
    }
}

void processCommand(const char* command) {
    systemState.lastCommandTime = millis();
    
    if (strlen(command) < 2 || command[0] != 'S') {
        Serial.print("?");
        return;
    }
    
    char cmdChar = command[1];
    
    switch (cmdChar) {
        case 'S':  // Enter serial mode
            if (strcmp(command, "SSSSSS") == 0) {
                systemState.serialMode = true;
                Serial.print("!");
            } else {
                Serial.print("?");
            }
            break;
            
        case 'E':  // Exit serial mode
            if (strcmp(command, "EEEEEE") == 0) {
                systemState.serialMode = false;
                Serial.print("!");
            } else {
                Serial.print("?");
            }
            break;
            
        case 'H':  // Home filter
            if (strlen(command) == 5) {
                startHomingRoutine();
                Serial.print("!");
            } else {
                Serial.print("?");
            }
            break;
            
        case 'F':  // Select filter position
            if (strlen(command) == 6) {
                char positionChar = command[5];
                uint8_t position = positionChar - '0';
                
                if (position >= 1 && position <= 6) {
                    moveToFilterPosition(position);
                    Serial.print("!");
                } else {
                    Serial.print("?");
                }
            } else {
                Serial.print("?");
            }
            break;
            
        case 'C':  // Get count
            if (strlen(command) == 6) {
                char timeStr[5];
                strncpy(timeStr, command + 2, 4);
                timeStr[4] = '\0';
                
                uint16_t integrationTime = atoi(timeStr);
                if (integrationTime >= INTEGRATION_MIN && integrationTime <= INTEGRATION_MAX) {
                    startIntegration(integrationTime);
                    
                    unsigned long startTime = millis();
                    unsigned long waitTime = integrationTime;
                    
                    // SSPDataq3 timing overhead
                    if (integrationTime == 1000) {
                        waitTime = 1150;
                    } else if (integrationTime <= 1000) {
                        waitTime = integrationTime * 1.15;
                    } else if (integrationTime <= 5000) {
                        waitTime = integrationTime * 1.03;
                    } else {
                        waitTime = integrationTime * 1.015;
                    }
                    
                    unsigned long endTime = startTime + waitTime;
                    while (millis() < endTime) {
                        checkIntegrationComplete();
                        updateStepperMovement();
                    }
                    
                    if (systemState.integrationActive) {
                        systemState.integrationActive = false;
                        stopCounting();
                    }
                    
                    uint16_t count = getCurrentCount();
                    char response[12];
                    sprintf(response, "C=%05d\r\n", count);
                    Serial.print(response);
                } else {
                    Serial.print("?");
                }
            } else {
                Serial.print("?");
            }
            break;
            
        case 'G':  // Set gain
            if (strlen(command) == 6) {
                char gainChar = command[5];
                uint8_t gain = gainChar - '0';
                
                if (gain >= 1 && gain <= 3) {
                    systemState.currentGain = gain;
                    Serial.print("!");
                } else {
                    Serial.print("?");
                }
            } else {
                Serial.print("?");
            }
            break;
            
        case 'V':  // Mirror control
            if (strlen(command) == 6) {
                char stateChar = command[5];
                uint8_t state = stateChar - '0';
                
                if (state <= 1) {
                    bool newMirrorState = (state == 1);
                    
                    if (newMirrorState != systemState.mirrorState) {
                        systemState.mirrorState = newMirrorState;
                        
                        long targetPosition = newMirrorState ? 200 : 0;
                        stepperY.moveTo(targetPosition);
                        systemState.stepperMoving = true;
                        
                        unsigned long mirrorStart = millis();
                        while (systemState.stepperMoving && (millis() - mirrorStart) < 2000) {
                            updateStepperMovement();
                        }
                        
                        if (systemState.stepperMoving) {
                            stepperY.stop();
                            systemState.stepperMoving = false;
                            Serial.print("?");
                            return;
                        }
                    }
                    
                    Serial.print("!");
                    delay(2000);
                } else {
                    Serial.print("?");
                }
            } else {
                Serial.print("?");
            }
            break;
            
        case 'I':  // Set integration time
            if (strlen(command) == 6) {
                char timeStr[5];
                strncpy(timeStr, command + 2, 4);
                timeStr[4] = '\0';
                
                uint16_t integrationTime = atoi(timeStr);
                if (integrationTime >= INTEGRATION_MIN && integrationTime <= INTEGRATION_MAX) {
                    systemState.integrationTime = integrationTime;
                    Serial.print("!");
                } else {
                    Serial.print("?");
                }
            } else {
                Serial.print("?");
            }
            break;
            
        default:
            Serial.print("?");
            break;
    }
}

// ============================================================================
// SYSTEM MANAGEMENT
// ============================================================================

void initializeSystemState() {
    systemState.currentFilter = 1;
    systemState.currentGain = config.defaultGain;
    systemState.integrationTime = config.defaultIntegrationTime;
    systemState.mirrorState = false;
    systemState.serialMode = false;
    systemState.integrationActive = false;
    systemState.stepperMoving = false;
    systemState.totalPulses = 0;
    systemState.errorCode = 0;
    systemState.lastCommandTime = millis();
    systemState.identified = false;
}

void updateStatusLED() {
    static uint32_t lastBlinkTime = 0;
    static bool ledState = false;
    
    uint32_t currentTime = millis();
    uint32_t blinkInterval = 0;
    
    if (systemState.errorCode != 0) {
        blinkInterval = 100;
    } else if (systemState.integrationActive) {
        blinkInterval = 250;
    } else if (systemState.serialMode) {
        blinkInterval = 500;
    } else {
        digitalWrite(STATUS_LED, HIGH);
        return;
    }
    
    if (currentTime - lastBlinkTime > blinkInterval) {
        ledState = !ledState;
        digitalWrite(STATUS_LED, ledState);
        lastBlinkTime = currentTime;
    }
}

// ============================================================================
// MAIN ARDUINO FUNCTIONS
// ============================================================================

void setup() {
    Serial.begin(SSP_BAUD);
    
    setupPulseCounting();
    setupStepperControl();
    
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    initializeSystemState();
    
    // Initial LED indication only
    for (int i = 0; i < 3; i++) {
        digitalWrite(STATUS_LED, HIGH);
        delay(100);
        digitalWrite(STATUS_LED, LOW);
        delay(100);
    }
}

void loop() {
    handleSerialCommunication();
    
    if (systemState.integrationActive) {
        checkIntegrationComplete();
    }
    
    updateStepperMovement();
    updateStatusLED();
    
    static uint32_t lastTimeoutCheck = 0;
    uint32_t currentTime = millis();
    
    if (currentTime - lastTimeoutCheck > 5000) {
        if (systemState.serialMode && (currentTime - systemState.lastCommandTime) > 300000) {
            systemState.serialMode = false;
        }
        lastTimeoutCheck = currentTime;
    }
}

// ============================================================================
// NOTES
// ============================================================================

/*
  SSPDataq3 CONNECTION TROUBLESHOOTING:
  
  1. ERROR: "The device identifier is invalid or unsupported"
     - SSPDataq3 checks for SSPCARD hardware ID
     - This sketch sends "SSPCARD\r\n" on connection
     - May need specific timing or handshake
  
  2. TESTING PROCEDURE:
     a. Upload this sketch
     b. Open Arduino Serial Monitor at 19200 baud
     c. Should see "SSPCARD" appear
     d. Send "SSSSSS" → Should receive "!"
     e. If this works, SSPDataq3 should connect
  
  3. ALTERNATIVE SOLUTIONS:
     - Try different COM ports (COM3, COM4, etc.)
     - Check SSPDataq3 port settings (8-N-1, no flow control)
     - Use COM0COM virtual serial port if hardware ID is critical
  
  4. WIRING:
     SSP5A Pin 9 → 10kΩ pull-up → 74HC14 → CNC Shield RX pin (Pin 0)
*/