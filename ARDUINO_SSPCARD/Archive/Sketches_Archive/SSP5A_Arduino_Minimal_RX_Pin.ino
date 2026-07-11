/*
  SSP5A Arduino Controller - Minimal Memory Version (RX Pin)
  Uses RX pin (Pin 0) for pulse input to avoid CNC shield conflicts
  
  Core Features Only:
  - SSP protocol implementation (19200 baud)
  - Interrupt-driven pulse counting on RX pin (Pin 0)
  - Basic stepper motor control
  - No debug, no EEPROM, no performance metrics
  
  Memory Optimizations:
  - No SoftwareSerial debug
  - Smaller buffers
  - Optimized data types
  - Minimal global variables
  
  Expected Memory Usage: ~1200-1400 bytes (60-70% of dynamic memory)
*/

#include <AccelStepper.h>

// ============================================================================
// HARDWARE CONFIGURATION - USING RX PIN (PIN 0)
// ============================================================================

// Pulse counting using RX pin (Pin 0) - clearly labeled on CNC shield
#define PULSE_PIN        0     // RX pin (Digital Pin 0) for pulse counting
#define X_STEP_PIN       2     // CNC Shield X-STEP (D2)
#define X_DIR_PIN        5     // CNC Shield X-DIR (D5)
#define X_EN_PIN         12    // CNC Shield X-ENABLE (D12)
#define Y_STEP_PIN       3     // CNC Shield Y-STEP (D3)
#define Y_DIR_PIN        6     // CNC Shield Y-DIR (D6)
#define Y_EN_PIN         13    // CNC Shield Y-ENABLE (D13)
#define STATUS_LED       13    // Built-in LED (shared with Y_ENABLE)

// ============================================================================
// SYSTEM CONSTANTS - MINIMAL
// ============================================================================

#define SSP_BAUD             19200
#define SERIAL_BUFFER_SIZE   16     // Reduced from 32
#define COMMAND_TIMEOUT_MS   100
#define INTEGRATION_MIN      1
#define INTEGRATION_MAX      9999
#define NUM_FILTERS          6

// Timing constants (ms)
#define FILTER_MOVE_TIME     100    // Time between adjacent filter positions

// ============================================================================
// CONFIGURATION - COMPILE-TIME ONLY (NO EEPROM)
// ============================================================================

// Default configuration stored in program memory
const struct {
    uint16_t filterPositions[6];        // Step counts for each filter position
    uint16_t defaultIntegrationTime;    // Default integration time (ms)
    uint8_t defaultGain;                // Default gain setting (1,2,3)
} config = {
    .filterPositions = {0, 200, 400, 600, 800, 1000},
    .defaultIntegrationTime = 1000,
    .defaultGain = 1
};

// ============================================================================
// SYSTEM STATE - OPTIMIZED
// ============================================================================

struct SystemState {
    uint8_t currentFilter : 3;    // 3 bits for 1-6
    uint8_t currentGain : 2;      // 2 bits for 1-3
    uint16_t integrationTime;     // Current integration time (ms)
    bool mirrorState : 1;
    bool serialMode : 1;
    bool integrationActive : 1;
    bool stepperMoving : 1;
    uint32_t totalPulses;
    uint16_t errorCode;
    uint32_t lastCommandTime;
};

// ============================================================================
// GLOBAL VARIABLES - MINIMAL
// ============================================================================

// Hardware objects
AccelStepper stepperX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN);
AccelStepper stepperY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN);

// Pulse counting
volatile uint32_t pulseCount = 0;
volatile bool countingActive = false;

// Integration timing
uint32_t integrationStartTime = 0;
uint32_t integrationDuration = 0;

// Serial communication
char serialBuffer[SERIAL_BUFFER_SIZE];
uint8_t bufferIndex = 0;
uint32_t lastCharTime = 0;

// System state
SystemState systemState;

// ============================================================================
// PULSE COUNTING MODULE - MINIMAL
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(PULSE_PIN), pulseISR, RISING);
}

// Interrupt Service Routine - ABSOLUTELY MINIMAL
void pulseISR() {
    if (countingActive) {
        pulseCount++;
        // Simple overflow protection (reset at 65535)
        if (pulseCount > 65535) {
            pulseCount = 0;
        }
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
    
    // Handle overflow for 16-bit reporting
    if (count > 65535) {
        count = 65535;
    }
    
    return (uint16_t)count;
}

uint16_t getCurrentCount() {
    noInterrupts();
    uint32_t count = pulseCount;
    interrupts();
    
    if (count > 65535) {
        count = 65535;
    }
    
    return (uint16_t)count;
}

// ============================================================================
// INTEGRATION TIMER MODULE - SIMPLIFIED
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
    
    // Handle millis() overflow (every ~50 days)
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
// STEPPER CONTROL MODULE - BASIC
// ============================================================================

void setupStepperControl() {
    // Enable pins
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    digitalWrite(X_EN_PIN, LOW);  // Enable X driver
    digitalWrite(Y_EN_PIN, LOW);  // Enable Y driver
    
    // Configure steppers - basic settings
    stepperX.setMaxSpeed(1000.0);
    stepperX.setSpeed(500.0);
    stepperY.setMaxSpeed(1000.0);
    stepperY.setSpeed(500.0);
    
    // Set current position as zero
    stepperX.setCurrentPosition(0);
    stepperY.setCurrentPosition(0);
    
    systemState.stepperMoving = false;
}

void moveToFilterPosition(uint8_t position) {
    if (position < 1 || position > NUM_FILTERS) {
        return;
    }
    
    uint16_t targetSteps = config.filterPositions[position - 1];
    
    // Calculate speed for 100ms movement time
    float speed = 200.0 / (FILTER_MOVE_TIME / 1000.0); // 200 steps in 100ms = 2000 steps/s
    
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
    // Move to home position (filter 1)
    moveToFilterPosition(1);
    
    // Wait for homing to complete (max 5 seconds)
    unsigned long homingStart = millis();
    while (systemState.stepperMoving && (millis() - homingStart) < 5000) {
        updateStepperMovement();
    }
    
    if (systemState.stepperMoving) {
        // Homing timeout - stop movement
        stepperX.stop();
        systemState.stepperMoving = false;
    }
}

// ============================================================================
// SERIAL COMMUNICATION MODULE - ESSENTIAL ONLY
// ============================================================================

void handleSerialCommunication() {
    // Read incoming serial data
    while (Serial.available()) {
        char c = Serial.read();
        lastCharTime = millis();
        
        if (c == '\r' || c == '\n') {
            // End of command
            if (bufferIndex > 0) {
                serialBuffer[bufferIndex] = '\0';
                processCommand(serialBuffer);
                bufferIndex = 0;
            }
        } else if (bufferIndex < SERIAL_BUFFER_SIZE - 1) {
            serialBuffer[bufferIndex++] = c;
        } else {
            // Buffer overflow
            bufferIndex = 0;
            Serial.print("?");
        }
    }
    
    // Command timeout handling
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        bufferIndex = 0;
        Serial.print("?");
    }
}

void processCommand(const char* command) {
    systemState.lastCommandTime = millis();
    
    // Minimum command length is 2 characters (S + command letter)
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
                // Extract integration time (nnnn)
                char timeStr[5];
                strncpy(timeStr, command + 2, 4);
                timeStr[4] = '\0';
                
                uint16_t integrationTime = atoi(timeStr);
                if (integrationTime >= INTEGRATION_MIN && integrationTime <= INTEGRATION_MAX) {
                    // Start integration
                    startIntegration(integrationTime);
                    
                    // Wait for integration to complete
                    unsigned long startTime = millis();
                    unsigned long waitTime = integrationTime;
                    
                    // Add overhead like SSPDataq3
                    if (integrationTime == 1000) {
                        waitTime = 1150;
                    } else if (integrationTime <= 1000) {
                        waitTime = integrationTime * 1.15;
                    } else if (integrationTime <= 5000) {
                        waitTime = integrationTime * 1.03;
                    } else {
                        waitTime = integrationTime * 1.015;
                    }
                    
                    // Wait the full time
                    unsigned long endTime = startTime + waitTime;
                    while (millis() < endTime) {
                        checkIntegrationComplete();
                        updateStepperMovement();
                    }
                    
                    // Make sure integration is stopped
                    if (systemState.integrationActive) {
                        systemState.integrationActive = false;
                        stopCounting();
                    }
                    
                    // Get and report count
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
                        
                        // Move mirror stepper (Y-axis)
                        long targetPosition = newMirrorState ? 200 : 0;
                        stepperY.moveTo(targetPosition);
                        systemState.stepperMoving = true;
                        
                        // Wait for mirror movement (max 2 seconds)
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
                    delay(2000); // SSPDataq3 waits 2000ms after SVIEW
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
// SYSTEM MANAGEMENT - MINIMAL
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
}

void updateStatusLED() {
    static uint32_t lastBlinkTime = 0;
    static bool ledState = false;
    
    uint32_t currentTime = millis();
    uint32_t blinkInterval = 0;
    
    if (systemState.errorCode != 0) {
        blinkInterval = 100;  // Error: rapid blink
    } else if (systemState.integrationActive) {
        blinkInterval = 250;  // Integrating: medium blink
    } else if (systemState.serialMode) {
        blinkInterval = 500;  // Serial mode: slow blink
    } else {
        digitalWrite(STATUS_LED, HIGH);  // Normal: solid on
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
    // Initialize main serial for SSP protocol
    Serial.begin(SSP_BAUD);
    
    // Initialize hardware
    setupPulseCounting();
    setupStepperControl();
    
    // Initialize status LED
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    // Initialize system state
    initializeSystemState();
    
    // Initial status indication
    for (int i = 0; i < 3; i++) {
        digitalWrite(STATUS_LED, HIGH);
        delay(100);
        digitalWrite(STATUS_LED, LOW);
        delay(100);
    }
    
    Serial.println("SSP5A Minimal Controller Ready (RX Pin)");
    Serial.println("Send 'SSSSSS' to enter serial mode");
}

void loop() {
    // Handle incoming serial commands
    handleSerialCommunication();
    
    // Manage integration timer
    if (systemState.integrationActive) {
        checkIntegrationComplete();
    }
    
    // Update stepper movement
    updateStepperMovement();
    
    // Update status LED
    updateStatusLED();
    
    // Check for serial mode timeout (5 minutes)
    static uint32_t lastTimeoutCheck = 0;
    uint32_t currentTime = millis();
    
    if (currentTime - lastTimeoutCheck > 5000) { // Check every 5 seconds
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
  IMPORTANT WIRING CHANGE:
  SSP5A Pin 9 (Gray) → CNC Shield RX pin (clearly labeled in serial block)
  
  This version uses RX pin (Pin 0) for pulse input because:
  1. RX pin is clearly labeled on CNC shield serial block
  2. Avoids conflict with X_STEP pin (Pin 2)
  3. No need to find unlabeled D2/D4 pins
  
  Memory savings expected: 500-700 bytes
  
  To use:
  1. Upload this sketch
  2. Connect SSP5A Pin 9 to CNC Shield RX pin
  3. Test basic functionality
*/