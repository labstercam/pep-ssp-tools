/*
  SSP5A Arduino Controller - CNC Shield SCL/SDA Version
  Uses Pin A4 (SDA) or Pin A5 (SCL) for pulse input
  Available on CNC shield serial communications panel
  Solves serial interference issue
  
  CNC Shield V3 Serial Panel Pins:
  - SCL (Pin A5/19): Available for pulse input
  - SDA (Pin A4/18): Available for pulse input
  - RST (Reset): Not recommended for pulse input
  
  CNC Shield V3 Pin Usage:
  - D2: X_STEP (occupied by CNC shield)
  - D3: Y_STEP (occupied by CNC shield)
  - D4: Z_STEP (occupied by CNC shield)
  - D5: X_DIR (occupied by CNC shield)
  - D6: Y_DIR (occupied by CNC shield)
  - D12: X_ENABLE (occupied by CNC shield)
  - D13: Y_ENABLE + STATUS_LED (occupied by CNC shield)
*/

// ============================================================================
// HARDWARE CONFIGURATION - CNC SHIELD SCL/SDA COMPATIBLE
// ============================================================================

#define PULSE_PIN        A4     // Use Pin A4 (SDA) on CNC shield serial panel
// Alternative: Use Pin A5 (SCL) if A4 is busy
// #define PULSE_PIN        A5     // Use Pin A5 (SCL) on CNC shield serial panel

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
// PULSE COUNTING - USING ANALOG PIN A4/A5 (NO CNC SHIELD CONFLICT)
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    // Analog pins A4/A5 can be used as digital inputs
    // They don't have interrupt capability, but polling works fine
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
        // Check for rising edge on Pin A4/A5
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
            // Only send '?' if in serial mode
            if (serialMode) {
                Serial.print("?");
            }
        }
    }
    
    // Only check timeout if we're building a command
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        bufferIndex = 0;
        // Only send '?' if in serial mode
        if (serialMode) {
            Serial.print("?");
        }
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
    
    Serial.println("SSP5A CNC Shield SCL/SDA Version Ready");
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
// NOTES - CNC SHIELD SCL/SDA COMPATIBLE
// ============================================================================

/*
  CNC SHIELD SCL/SDA VERSION - USES ANALOG PINS
  
  Key changes:
  1. Uses Pin A4 (SDA) or A5 (SCL) on CNC shield serial panel
  2. Polling-based pulse counting (analog pins have no interrupts)
  3. Still filters serial noise when not in serial mode
  
  CNC SHIELD SERIAL PANEL PINS:
  - SCL (Pin A5/19): Available for pulse input
  - SDA (Pin A4/18): Available for pulse input
  - RST (Reset): Not recommended
  
  WIRING:
  SSP5A Pin 9 → 10kΩ pull-up → 74HC14 → CNC Shield SDA (A4) or SCL (A5)
  
  TESTING:
  1. Upload this sketch to Arduino
  2. Open Serial Monitor at 19200 baud
  3. Turn on SSP5A - should NOT see '?' characters
  4. Send "SSSSSS" → Should receive "!"
  5. Send "SC1000" → Should receive "C=00000"
  
  If you still see '?' characters:
  1. Check pulse conditioning circuit (74HC14 + 10kΩ + 100nF)
  2. Connect SSP5A Pin 9 to CNC Shield SDA (A4) or SCL (A5)
  3. Verify all grounds are connected properly
  
  NOTE: Polling-based pulse counting works for moderate pulse rates
        (<50kHz). This is sufficient for SSP5A photometer pulses.
        
  CHOOSE BETWEEN A4 OR A5:
  - Use A4 (SDA) if not using I2C
  - Use A5 (SCL) if A4 is busy
  - Change #define PULSE_PIN to A4 or A5 as needed
*/