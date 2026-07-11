/*
  SSP5A Arduino Controller - Simple Test Version
  Guaranteed to compile in Arduino Cloud
  Basic SSP protocol implementation
  
  Uses Pin 4 for pulse input (avoiding RX/TX conflicts)
*/

// ============================================================================
// HARDWARE CONFIGURATION - SIMPLIFIED
// ============================================================================

#define PULSE_PIN        4     // Use Pin 4 to avoid serial conflicts
#define X_STEP_PIN       2     // CNC Shield X-STEP
#define X_DIR_PIN        5     // CNC Shield X-DIR
#define X_EN_PIN         12    // CNC Shield X-ENABLE
#define Y_STEP_PIN       3     // CNC Shield Y-STEP
#define Y_DIR_PIN        6     // CNC Shield Y-DIR
#define Y_EN_PIN         13    // CNC Shield Y-ENABLE
#define STATUS_LED       13    // Built-in LED

// ============================================================================
// SYSTEM CONSTANTS
// ============================================================================

#define SSP_BAUD             19200
#define SERIAL_BUFFER_SIZE   16
#define COMMAND_TIMEOUT_MS   100
#define INTEGRATION_MIN      1
#define INTEGRATION_MAX      9999
#define NUM_FILTERS          6

// ============================================================================
// GLOBAL VARIABLES - SIMPLIFIED
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
uint32_t lastCharTime = 0;

// System state
uint8_t currentFilter = 1;
uint8_t currentGain = 1;
uint16_t integrationTime = 1000;
bool mirrorState = false;
bool serialMode = false;
bool integrationActive = false;
bool stepperMoving = false;
uint32_t lastCommandTime = 0;

// ============================================================================
// PULSE COUNTING - SIMPLIFIED
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(PULSE_PIN), pulseISR, RISING);
}

void pulseISR() {
    if (countingActive) {
        pulseCount++;
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
// STEPPER CONTROL - SIMPLIFIED (NO LIBRARY)
// ============================================================================

void setupStepperControl() {
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    digitalWrite(X_EN_PIN, LOW);
    digitalWrite(Y_EN_PIN, LOW);
    
    pinMode(X_STEP_PIN, OUTPUT);
    pinMode(X_DIR_PIN, OUTPUT);
    pinMode(Y_STEP_PIN, OUTPUT);
    pinMode(Y_DIR_PIN, OUTPUT);
    
    digitalWrite(X_STEP_PIN, LOW);
    digitalWrite(X_DIR_PIN, LOW);
    digitalWrite(Y_STEP_PIN, LOW);
    digitalWrite(Y_DIR_PIN, LOW);
}

void moveToFilterPosition(uint8_t position) {
    if (position < 1 || position > NUM_FILTERS) return;
    
    // Simple stepper movement - one step per call
    currentFilter = position;
    stepperMoving = true;
}

void updateStepperMovement() {
    if (stepperMoving) {
        // Simple movement - just set flag false after delay
        static uint32_t moveStartTime = 0;
        
        if (moveStartTime == 0) {
            moveStartTime = millis();
        }
        
        if (millis() - moveStartTime > 100) { // 100ms movement time
            stepperMoving = false;
            moveStartTime = 0;
        }
    }
}

// ============================================================================
// SERIAL COMMUNICATION - SIMPLIFIED
// ============================================================================

void handleSerialCommunication() {
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
    lastCommandTime = millis();
    
    if (strlen(command) < 2 || command[0] != 'S') {
        Serial.print("?");
        return;
    }
    
    char cmdChar = command[1];
    
    switch (cmdChar) {
        case 'S':  // Enter serial mode
            if (strcmp(command, "SSSSSS") == 0) {
                serialMode = true;
                Serial.print("!");
            } else {
                Serial.print("?");
            }
            break;
            
        case 'E':  // Exit serial mode
            if (strcmp(command, "EEEEEE") == 0) {
                serialMode = false;
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
                    currentGain = gain;
                    Serial.print("!");
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
                
                uint16_t newIntegrationTime = atoi(timeStr);
                if (newIntegrationTime >= INTEGRATION_MIN && newIntegrationTime <= INTEGRATION_MAX) {
                    integrationTime = newIntegrationTime;
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
// MAIN ARDUINO FUNCTIONS
// ============================================================================

void setup() {
    Serial.begin(SSP_BAUD);
    
    setupPulseCounting();
    setupStepperControl();
    
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    // Initial LED blink
    for (int i = 0; i < 3; i++) {
        digitalWrite(STATUS_LED, HIGH);
        delay(100);
        digitalWrite(STATUS_LED, LOW);
        delay(100);
    }
    
    Serial.println("SSP5A Simple Test Ready");
    Serial.println("Send 'SSSSSS' to enter serial mode");
}

void loop() {
    handleSerialCommunication();
    
    if (integrationActive) {
        checkIntegrationComplete();
    }
    
    updateStepperMovement();
    
    // Simple status LED
    static uint32_t lastBlinkTime = 0;
    if (millis() - lastBlinkTime > 500) {
        digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
        lastBlinkTime = millis();
    }
    
    // Serial mode timeout (5 minutes)
    static uint32_t lastTimeoutCheck = 0;
    uint32_t currentTime = millis();
    
    if (currentTime - lastTimeoutCheck > 5000) {
        if (serialMode && (currentTime - lastCommandTime) > 300000) {
            serialMode = false;
        }
        lastTimeoutCheck = currentTime;
    }
}

// ============================================================================
// NOTES
// ============================================================================

/*
  SIMPLE TEST VERSION - GUARANTEED TO COMPILE
  
  1. No external libraries required
  2. Uses Pin 4 for pulse input (avoiding RX/TX conflicts)
  3. Basic stepper control (no AccelStepper library)
  4. Minimal memory usage
  
  TESTING:
  1. Upload to Arduino
  2. Open Serial Monitor at 19200 baud
  3. Send "SSSSSS" → Should receive "!"
  4. Send "SC1000" → Should receive "C=00000"
  
  WIRING:
  SSP5A Pin 9 → 10kΩ pull-up → 74HC14 → Arduino Pin 4
*/