/*
  SSP5A Arduino Controller - Both Axes Version
  Moves both X and Y axes together for unusual stepper motor wiring
  Uses Pin A4 (SDA) for pulse input on CNC shield serial panel
  
  IMPORTANT: This sketch ALWAYS moves both X and Y axes together
  Required for stepper motors with interconnected windings
*/

// ============================================================================
// HARDWARE CONFIGURATION
// ============================================================================

#define PULSE_PIN        A4     // Use Pin A4 (SDA) on CNC shield serial panel

// CNC Shield Stepper Pins
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

// Stepper movement constants
#define STEPS_PER_FILTER     200    // 200 steps between filter positions
#define STEP_DELAY_US        1000   // 1ms between steps (1000Hz step rate)
#define STEP_PULSE_US        10     // 10µs STEP pulse width

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

// Pulse counting
volatile uint32_t pulseCount = 0;
volatile bool countingActive = false;

// Integration timing
uint32_t integrationStartTime = 0;
uint32_t integrationDuration = 0;

// Serial communication
char serialBuffer[SERIAL_BUFFER_SIZE];
uint8_t bufferIndex = 0;
uint32_t lastCharTime = -1000;  // Start with timeout expired

// System state
uint8_t currentFilter = 1;
uint8_t targetFilter = 1;
uint8_t currentGain = 1;
uint16_t integrationTime = 1000;
bool mirrorState = false;
bool serialMode = false;
bool integrationActive = false;
bool stepperMoving = false;
uint32_t lastCommandTime = 0;

// Stepper movement tracking
uint16_t stepsRemaining = 0;
uint32_t lastStepTime = 0;
bool movingToTarget = false;

// ============================================================================
// PULSE COUNTING
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
}

void startCounting() {
    pulseCount = 0;
    countingActive = true;
}

uint16_t stopCounting() {
    countingActive = false;
    uint32_t count = pulseCount;
    return (count > 65535) ? 65535 : (uint16_t)count;
}

void updatePulseCounting() {
    if (countingActive) {
        static bool lastState = false;
        bool currentState = digitalRead(PULSE_PIN);
        
        if (currentState && !lastState) {
            pulseCount++;
        }
        lastState = currentState;
    }
}

// ============================================================================
// INTEGRATION TIMER
// ============================================================================

void startIntegration(uint16_t duration_ms) {
    integrationTime = duration_ms;
    integrationStartTime = millis();
    integrationDuration = duration_ms;
    integrationActive = true;
    startCounting();
}

bool checkIntegrationComplete() {
    if (!integrationActive) return false;
    
    uint32_t elapsed = millis() - integrationStartTime;
    
    if (elapsed >= integrationDuration) {
        integrationActive = false;
        stopCounting();
        return true;
    }
    
    return false;
}

// ============================================================================
// STEPPER CONTROL - BOTH AXES TOGETHER
// ============================================================================

void setupStepperControl() {
    // Enable pins - set LOW to enable drivers
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    digitalWrite(X_EN_PIN, LOW);  // Enable X-axis driver
    digitalWrite(Y_EN_PIN, LOW);  // Enable Y-axis driver
    
    // STEP and DIR pins
    pinMode(X_STEP_PIN, OUTPUT);
    pinMode(X_DIR_PIN, OUTPUT);
    pinMode(Y_STEP_PIN, OUTPUT);
    pinMode(Y_DIR_PIN, OUTPUT);
    
    // Initialize all pins LOW
    digitalWrite(X_STEP_PIN, LOW);
    digitalWrite(X_DIR_PIN, LOW);
    digitalWrite(Y_STEP_PIN, LOW);
    digitalWrite(Y_DIR_PIN, LOW);
}

void moveToFilterPosition(uint8_t position) {
    if (position < 1 || position > NUM_FILTERS) return;
    
    targetFilter = position;
    movingToTarget = true;
    
    // Calculate steps needed
    int8_t filterDiff = position - currentFilter;
    stepsRemaining = abs(filterDiff) * STEPS_PER_FILTER;
    
    // Set direction for BOTH axes
    if (filterDiff > 0) {
        // Moving forward (filter 1→2→3→4→5→6)
        digitalWrite(X_DIR_PIN, HIGH);
        digitalWrite(Y_DIR_PIN, HIGH);
    } else {
        // Moving backward (filter 6→5→4→3→2→1)
        digitalWrite(X_DIR_PIN, LOW);
        digitalWrite(Y_DIR_PIN, LOW);
    }
    
    stepperMoving = true;
    lastStepTime = micros();
}

void updateStepperMovement() {
    if (!stepperMoving || !movingToTarget) return;
    
    uint32_t currentTime = micros();
    
    if (currentTime - lastStepTime >= STEP_DELAY_US) {
        if (stepsRemaining > 0) {
            // Generate STEP pulse for BOTH axes
            digitalWrite(X_STEP_PIN, HIGH);
            digitalWrite(Y_STEP_PIN, HIGH);
            delayMicroseconds(STEP_PULSE_US);
            digitalWrite(X_STEP_PIN, LOW);
            digitalWrite(Y_STEP_PIN, LOW);
            
            stepsRemaining--;
            lastStepTime = currentTime;
        } else {
            // Movement complete
            stepperMoving = false;
            movingToTarget = false;
            currentFilter = targetFilter;
            
            digitalWrite(X_STEP_PIN, LOW);
            digitalWrite(Y_STEP_PIN, LOW);
        }
    }
}

// ============================================================================
// SERIAL COMMUNICATION - AGGRESSIVE NOISE FILTERING
// ============================================================================

void handleSerialCommunication() {
    // Clear any stray characters immediately
    while (Serial.available()) {
        char c = Serial.read();
        
        // Only process if we're building a command
        if (bufferIndex > 0 || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
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
                if (serialMode) {
                    Serial.print("?");
                }
            }
        }
    }
    
    // Timeout handling
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        bufferIndex = 0;
        if (serialMode) {
            Serial.print("?");
        }
    }
}

void processCommand(const char* command) {
    lastCommandTime = millis();
    
    if (strlen(command) < 2 || command[0] != 'S') {
        if (serialMode) {
            Serial.print("?");
        }
        return;
    }
    
    char cmdChar = command[1];
    
    switch (cmdChar) {
        case 'S':  // Enter serial mode
            if (strcmp(command, "SSSSSS") == 0) {
                serialMode = true;
                Serial.print("!");
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
            }
            break;
            
        case 'E':  // Exit serial mode
            if (strcmp(command, "EEEEEE") == 0) {
                serialMode = false;
                Serial.print("!");
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
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
                    if (serialMode) {
                        Serial.print("?");
                    }
                }
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
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
                    
                    // Wait for integration
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
                        updatePulseCounting();
                    }
                    
                    if (integrationActive) {
                        integrationActive = false;
                        stopCounting();
                    }
                    
                    uint16_t count = stopCounting();
                    char response[12];
                    sprintf(response, "C=%05d\r\n", count);
                    Serial.print(response);
                } else {
                    if (serialMode) {
                        Serial.print("?");
                    }
                }
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
            }
            break;
            
        case 'G':  // Set gain
            if (strlen(command) == 6) {
                char gainChar = command[5];
                uint8_t gain = gainChar - '0';
                
                if (gain >= 1 && gain <= 3) {
                    currentGain = gain;
                    Serial.print("!");
                } else {
                    if (serialMode) {
                        Serial.print("?");
                    }
                }
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
            }
            break;
            
        case 'I':  // Set integration time
            if (strlen(command) == 6) {
                char timeStr[5];
                strncpy(timeStr, command + 2, 4);
                timeStr[4] = '\0';
                
                uint16_t newIntegrationTime = atoi(timeStr);
                if (newIntegrationTime >= INTEGRATION_MIN && newIntegrationTime <= INTEGRATION_MAX) {
                    integrationTime = newIntegrationTime;
                    Serial.print("!");
                } else {
                    if (serialMode) {
                        Serial.print("?");
                    }
                }
            } else {
                if (serialMode) {
                    Serial.print("?");
                }
            }
            break;
            
        default:
            if (serialMode) {
                Serial.print("?");
            }
            break;
    }
}

// ============================================================================
// MAIN ARDUINO FUNCTIONS
// ============================================================================

void setup() {
    Serial.begin(SSP_BAUD);
    
    // Wait for serial to stabilize
    delay(100);
    
    // Clear serial buffer aggressively
    while (Serial.available()) {
        Serial.read();
    }
    
    setupPulseCounting();
    setupStepperControl();
    
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    // Quick LED blink (no serial output)
    for (int i = 0; i < 3; i++) {
        digitalWrite(STATUS_LED, HIGH);
        delay(50);
        digitalWrite(STATUS_LED, LOW);
        delay(50);
    }
    
    // NO startup messages - completely silent
}

void loop() {
    handleSerialCommunication();
    
    if (integrationActive) {
        checkIntegrationComplete();
        updatePulseCounting();
    }
    
    updateStepperMovement();
    
    // Status LED (slow blink when idle)
    static uint32_t lastBlinkTime = 0;
    if (millis() - lastBlinkTime > 1000) {
        digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
        lastBlinkTime = millis();
    }
    
    // Serial mode timeout (2 minutes)
    static uint32_t lastTimeoutCheck = 0;
    uint32_t currentTime = millis();
    
    if (currentTime - lastTimeoutCheck > 5000) {
        if (serialMode && (currentTime - lastCommandTime) > 120000) {
            serialMode = false;
        }
        lastTimeoutCheck = currentTime;
    }
}

// ============================================================================
// NOTES - BOTH AXES VERSION
// ============================================================================

/*
  BOTH AXES VERSION - FOR UNUSUAL STEPPER MOTOR WIRING
  
  Key features:
  1. ALWAYS moves both X and Y axes together
  2. Required for stepper motors with interconnected windings
  3. Uses Option 2 wiring from diagnostic tests
  4. NO startup messages - completely silent
  
  WIRING (Option 2):
  SSP5A Pin 7 (Black)  → Motor Pin B2
  SSP5A Pin 4 (Orange) → Motor Pin B1
  SSP5A Pin 3 (Brown)  → Motor Pin A2
  SSP5A Pin 2 (Yellow) → Motor Pin A1
  
  TESTING:
  1. Upload this sketch to Arduino
  2. Open Serial Monitor at 19200 baud, "Newline" line ending
  3. Send "SSSSSS" → Should receive "!" (no other output)
  4. Send "SF0011" → Should move to filter 1 (series of clicks!)
  5. Send "SF0013" → Should move to filter 3
  6. Send "SF0016" → Should move to filter 6 (dark)
  7. Send "SC1000" → Should receive "C=00000"
  
  This sketch should now work properly with your unusual stepper motor wiring.
*/