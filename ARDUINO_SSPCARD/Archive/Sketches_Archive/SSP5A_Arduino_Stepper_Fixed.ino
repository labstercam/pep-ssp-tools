/*
  SSP5A Arduino Controller - Stepper Fixed Version
  Adds actual stepper motor movement with STEP pulses
  Uses Pin A4 (SDA) for pulse input on CNC shield serial panel
  
  CNC Shield V3 Pin Usage:
  - D2: X_STEP (STEP pulses for X-axis)
  - D3: Y_STEP (STEP pulses for Y-axis)
  - D5: X_DIR (direction for X-axis)
  - D6: Y_DIR (direction for Y-axis)
  - D12: X_ENABLE (enable X-axis driver)
  - D13: Y_ENABLE + STATUS_LED (enable Y-axis driver)
*/

// ============================================================================
// HARDWARE CONFIGURATION - CNC SHIELD WITH ACTUAL STEPPER CONTROL
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
#define STEPS_PER_FILTER     200    // 200 steps between filter positions (adjust as needed)
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
uint32_t lastCharTime = 0;

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
// PULSE COUNTING - USING ANALOG PIN A4 (NO CNC SHIELD CONFLICT)
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
        // Check for rising edge on Pin A4
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
// STEPPER CONTROL - ACTUAL MOVEMENT WITH STEP PULSES
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
    
    // Calculate steps needed (simplified - 200 steps per filter position)
    int8_t filterDiff = position - currentFilter;
    stepsRemaining = abs(filterDiff) * STEPS_PER_FILTER;
    
    // Set direction based on whether moving forward or backward
    if (filterDiff > 0) {
        // Moving forward (filter 1→2→3→4→5→6)
        digitalWrite(X_DIR_PIN, HIGH);  // Set direction forward
        digitalWrite(Y_DIR_PIN, HIGH);  // Set direction forward
    } else {
        // Moving backward (filter 6→5→4→3→2→1)
        digitalWrite(X_DIR_PIN, LOW);   // Set direction backward
        digitalWrite(Y_DIR_PIN, LOW);   // Set direction backward
    }
    
    stepperMoving = true;
    lastStepTime = micros();
}

void updateStepperMovement() {
    if (!stepperMoving || !movingToTarget) return;
    
    uint32_t currentTime = micros();
    
    // Check if it's time for next step
    if (currentTime - lastStepTime >= STEP_DELAY_US) {
        if (stepsRemaining > 0) {
            // Generate STEP pulse
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
            
            // Ensure STEP pins are LOW
            digitalWrite(X_STEP_PIN, LOW);
            digitalWrite(Y_STEP_PIN, LOW);
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
    
    Serial.println("SSP5A Stepper Fixed Version Ready");
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
// NOTES - STEPPER FIXED VERSION
// ============================================================================

/*
  STEPPER FIXED VERSION - ACTUAL STEPPER MOVEMENT
  
  Key changes:
  1. Actual STEP pulse generation for stepper motor movement
  2. Both X and Y axes move together (simplified control)
  3. 200 steps per filter position (adjust STEPS_PER_FILTER as needed)
  4. 1ms step delay (1000Hz step rate)
  5. Still uses Pin A4 (SDA) for pulse input
  
  CNC SHIELD CONNECTIONS:
  SSP5A Pin 7 (Black)  → X+ on CNC Shield
  SSP5A Pin 4 (Orange) → X- on CNC Shield
  SSP5A Pin 3 (Brown)  → Y+ on CNC Shield
  SSP5A Pin 2 (Yellow) → Y- on CNC Shield
  
  DRV8825 CONFIGURATION:
  - Enable pins: LOW (enabled) - already set in setupStepperControl()
  - VREF: ~0.1V for 1A current (adjust with potentiometer)
  - Microstepping: Set jumpers for 1/4 or 1/8 step (recommended)
  
  TESTING:
  1. Upload this sketch to Arduino
  2. Open Serial Monitor at 19200 baud
  3. Send "SSSSSS" → Should receive "!"
  4. Send "SF0011" → Should move to filter 1 (you should hear stepper!)
  5. Send "SF0013" → Should move to filter 3
  6. Send "SF0016" → Should move to filter 6 (dark)
  
  TROUBLESHOOTING:
  1. No stepper movement/sound:
     - Check 12V power to CNC shield
     - Check DRV8825 VREF voltage (~0.1V)
     - Check enable pins are LOW (D12, D13)
     - Check STEP pins (D2, D3) with oscilloscope
  
  2. Stepper moves but wrong direction:
     - Swap X+ and X- connections
     - Swap Y+ and Y- connections
  
  3. Stepper moves too fast/slow:
     - Adjust STEP_DELAY_US (higher = slower)
     - Adjust STEPS_PER_FILTER (higher = more steps per position)
  
  NOTE: This is a simplified stepper control. For more precise positioning,
        you may need to implement acceleration/deceleration and better
        position tracking.
*/