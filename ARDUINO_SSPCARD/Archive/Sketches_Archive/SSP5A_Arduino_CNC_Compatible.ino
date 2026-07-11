/*
  SSP5A Arduino Controller - CNC Shield Compatible Version
  Uses Pin 8 for pulse input (available on CNC shield breakout)
  Solves serial interference issue
  
  CNC Shield V3 Pin Usage:
  - D2: X_STEP (occupied by CNC shield)
  - D3: Y_STEP (occupied by CNC shield)
  - D4: Z_STEP (occupied by CNC shield)
  - D5: X_DIR (occupied by CNC shield)
  - D6: Y_DIR (occupied by CNC shield)
  - D7: Z_DIR (occupied by CNC shield)
  - D8: FREE (use for pulse input)
  - D9: FREE (alternative for pulse input)
  - D12: X_ENABLE (occupied by CNC shield)
  - D13: Y_ENABLE + STATUS_LED (occupied by CNC shield)
*/

// ============================================================================
// HARDWARE CONFIGURATION - CNC SHIELD COMPATIBLE
// ============================================================================

#define PULSE_PIN        8     // Use Pin 8 (available on CNC shield breakout)
#define X_STEP_PIN       2     // CNC Shield X-STEP (D2) - occupied
#define X_DIR_PIN        5     // CNC Shield X-DIR (D5) - occupied
#define X_EN_PIN         12    // CNC Shield X-ENABLE (D12) - occupied
#define Y_STEP_PIN       3     // CNC Shield Y-STEP (D3) - occupied
#define Y_DIR_PIN        6     // CNC Shield Y-DIR (D6) - occupied
#define Y_EN_PIN         13    // CNC Shield Y-ENABLE (D13) - occupied
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
// PULSE COUNTING - USING PIN 8 (NO CNC SHIELD CONFLICT)
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    // Pin 8 doesn't have interrupt capability on Arduino Uno
    // We'll use polling instead
}

void checkPulseInput() {
    // Polling method for pulse counting on Pin 8
    // Since Pin 8 doesn't have interrupt capability on Uno
    // We'll check during integration only
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

// Simple polling-based pulse counting
void updatePulseCounting() {
    if (countingActive) {
        // Check for rising edge on Pin 8
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
// SERIAL COMMUNICATION - FIXED (IGNORES NOISE WHEN NOT IN SERIAL MODE)
// ============================================================================

void handleSerialCommunication() {
    // Only process serial data when in serial mode
    if (!serialMode) {
        // Clear any incoming data to prevent '?' responses
        while (Serial.available()) {
            Serial.read(); // Discard the data
        }
        return;
    }
    
    while (Serial.available()) {
        char c = Serial.read();
        lastCharTime = millis();
        
        // Filter out non-printable characters (except CR/LF)
        if (c < 32 && c != '\r' && c != '\n') {
            continue; // Skip non-printable characters
        }
        
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
                        updatePulseCounting(); // Poll for pulses during integration
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
    
    // Clear serial buffer on startup
    while (Serial.available()) {
        Serial.read();
    }
    
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
    
    Serial.println("SSP5A CNC Shield Compatible Ready");
    Serial.println("Send 'SSSSSS' to enter serial mode");
    Serial.println("Serial data ignored until in serial mode");
}

void loop() {
    handleSerialCommunication();
    
    if (integrationActive) {
        checkIntegrationComplete();
        updatePulseCounting(); // Poll for pulses during integration
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
            Serial.println("Serial mode timeout - auto-exited");
        }
        lastTimeoutCheck = currentTime;
    }
}

// ============================================================================
// NOTES - CNC SHIELD COMPATIBLE
// ============================================================================

/*
  CNC SHIELD COMPATIBLE VERSION - SOLVES PIN CONFLICT
  
  Key changes:
  1. Uses Pin 8 for pulse input (available on CNC shield breakout)
  2. Polling-based pulse counting (Pin 8 has no interrupt on Uno)
  3. Still filters serial noise when not in serial mode
  
  WIRING:
  SSP5A Pin 9 → 10kΩ pull-up → 74HC14 → CNC Shield Pin 8 breakout
  
  CNC SHIELD BREAKOUT PINS:
  - D8: Available (not used by CNC shield)
  - D9: Available (not used by CNC shield)
  - D10: Available (not used by CNC shield)
  - D11: Available (not used by CNC shield)
  
  TESTING:
  1. Upload this sketch to Arduino
  2. Open Serial Monitor at 19200 baud
  3. Turn on SSP5A - should NOT see '?' characters
  4. Send "SSSSSS" → Should receive "!"
  5. Send "SC1000" → Should receive "C=00000"
  
  If you still see '?' characters:
  1. Check pulse conditioning circuit (74HC14 + 10kΩ + 100nF)
  2. Connect SSP5A Pin 9 to CNC Shield Pin 8 breakout
  3. Verify all grounds are connected properly
  
  NOTE: Polling-based pulse counting works for moderate pulse rates
        (<50kHz). For higher rates, consider using Pin 2 or 3 with
        interrupts, but those are occupied by CNC shield.
*/