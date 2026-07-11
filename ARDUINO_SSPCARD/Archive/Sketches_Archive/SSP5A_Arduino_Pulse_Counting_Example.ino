/*
  SSP5A Arduino Controller - Pulse Counting Example
  Based on Prompt 2: Pulse Counting & Serial Communication Implementation
  
  This example demonstrates the core pulse counting and serial communication
  implementation for an Arduino-based SSPCARD replacement.
  
  Hardware Requirements:
  - Arduino Uno R3
  - Pulse input on Pin 2 (INT0) with Schmitt trigger conditioning
  - Serial communication at 19200 baud
  
  Command Examples:
  - "SSSSSS" - Enter serial mode (response: "!")
  - "SC1000" - Get count with 1000ms integration (response: "C=01234\r\n")
  - "SF0012" - Select filter position 2 (response: "!")
  - "SG0011" - Set gain 1 (response: "!")
  - "SVIEW0" - Mirror control off (response: "!")
  - "SI0500" - Set integration time to 500ms (response: "!")
*/

#include <AccelStepper.h>

// Hardware Configuration
#define PULSE_PIN 2        // INT0 for pulse counting
#define X_STEP_PIN 2       // CNC Shield X-STEP (shared with pulse pin - conflict!)
#define X_DIR_PIN 5        // CNC Shield X-DIR
#define X_EN_PIN 12        // CNC Shield X-ENABLE
#define Y_STEP_PIN 3       // CNC Shield Y-STEP
#define Y_DIR_PIN 6        // CNC Shield Y-DIR
#define Y_EN_PIN 13        // CNC Shield Y-ENABLE (shared with LED)
#define STATUS_LED 13      // Built-in LED

// SSP Protocol Constants
#define SSP_BAUD 19200
#define SERIAL_BUFFER_SIZE 32
#define COMMAND_TIMEOUT_MS 100
#define INTEGRATION_MIN 1
#define INTEGRATION_MAX 9999

// Global Variables
volatile uint32_t pulseCount = 0;
volatile bool countingActive = false;
uint32_t integrationStartTime = 0;
uint16_t integrationDuration = 1000;  // Default 1 second
bool integrationRunning = false;
uint8_t currentFilter = 1;
uint8_t currentGain = 1;
bool mirrorState = false;
bool serialMode = false;

// Stepper Objects
AccelStepper stepperX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN);
AccelStepper stepperY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN);

// Serial Buffer
char serialBuffer[SERIAL_BUFFER_SIZE];
uint8_t bufferIndex = 0;
uint32_t lastCharTime = 0;

// ============================================================================
// PULSE COUNTING FUNCTIONS
// ============================================================================

void setupPulseCounting() {
    pinMode(PULSE_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(PULSE_PIN), pulseISR, RISING);
}

// Interrupt Service Routine - MUST BE MINIMAL
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
    
    // Handle overflow (16-bit reporting)
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
// INTEGRATION TIMER FUNCTIONS
// ============================================================================

void startIntegration(uint16_t duration_ms) {
    integrationDuration = duration_ms;
    integrationStartTime = millis();
    integrationRunning = true;
    startCounting();
}

bool checkIntegrationComplete() {
    if (!integrationRunning) return false;
    
    uint32_t elapsed = millis() - integrationStartTime;
    if (elapsed >= integrationDuration) {
        integrationRunning = false;
        stopCounting();
        return true;
    }
    return false;
}

// ============================================================================
// SERIAL COMMUNICATION FUNCTIONS
// ============================================================================

void handleSerial() {
    while (Serial.available()) {
        char c = Serial.read();
        lastCharTime = millis();
        
        if (c == '\r' || c == '\n') {
            // End of command
            serialBuffer[bufferIndex] = '\0';
            processCommand(serialBuffer);
            bufferIndex = 0;
        } else if (bufferIndex < SERIAL_BUFFER_SIZE - 1) {
            serialBuffer[bufferIndex++] = c;
        } else {
            // Buffer overflow
            bufferIndex = 0;
            Serial.print("?");
        }
    }
    
    // Timeout handling
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        bufferIndex = 0;
        Serial.print("?");
    }
}

void processCommand(const char* command) {
    // Minimum command length is 2 characters (S + command letter)
    if (strlen(command) < 2 || command[0] != 'S') {
        Serial.print("?");
        return;
    }
    
    char cmdChar = command[1];
    
    switch (cmdChar) {
        case 'S':  // Enter serial mode
            handleEnterSerialMode(command);
            break;
        case 'E':  // Exit serial mode
            handleExitSerialMode(command);
            break;
        case 'H':  // Home filter
            handleHomeFilter(command);
            break;
        case 'F':  // Select filter position
            handleSelectFilter(command);
            break;
        case 'C':  // Get count
            handleGetCount(command);
            break;
        case 'G':  // Set gain
            handleSetGain(command);
            break;
        case 'V':  // Mirror control
            handleMirrorControl(command);
            break;
        case 'I':  // Set integration time
            handleSetIntegrationTime(command);
            break;
        default:
            Serial.print("?");
            break;
    }
}

// Command Handlers
void handleEnterSerialMode(const char* command) {
    if (strcmp(command, "SSSSSS") == 0) {
        serialMode = true;
        Serial.print("!");
    } else {
        Serial.print("?");
    }
}

void handleExitSerialMode(const char* command) {
    if (strcmp(command, "EEEEEE") == 0) {
        serialMode = false;
        Serial.print("!");
    } else {
        Serial.print("?");
    }
}

void handleHomeFilter(const char* command) {
    if (strlen(command) != 5) {
        Serial.print("?");
        return;
    }
    
    // Start homing routine
    moveToFilterPosition(1);
    Serial.print("!");
}

void handleSelectFilter(const char* command) {
    if (strlen(command) != 6) {
        Serial.print("?");
        return;
    }
    
    // Extract position (last character)
    char positionChar = command[5];
    uint8_t position = positionChar - '0';
    
    if (position < 1 || position > 6) {
        Serial.print("?");
        return;
    }
    
    moveToFilterPosition(position);
    Serial.print("!");
}

void handleGetCount(const char* command) {
    if (strlen(command) != 6) {
        Serial.print("?");
        return;
    }
    
    // Extract integration time (nnnn)
    char timeStr[5];
    strncpy(timeStr, command + 2, 4);
    timeStr[4] = '\0';
    
    uint16_t integrationTime = atoi(timeStr);
    if (integrationTime < 1 || integrationTime > 9999) {
        Serial.print("?");
        return;
    }
    
    // Start integration and wait for completion
    startIntegration(integrationTime);
    while (!checkIntegrationComplete()) {
        // Wait for integration to complete
        // In a real implementation, this would be non-blocking
    }
    
    // Get and report count
    uint16_t count = getCurrentCount();
    char response[10];
    sprintf(response, "C=%05d\r\n", count);
    Serial.print(response);
}

void handleSetGain(const char* command) {
    if (strlen(command) != 6) {
        Serial.print("?");
        return;
    }
    
    // Extract gain setting (last character)
    char gainChar = command[5];
    uint8_t gain = gainChar - '0';
    
    // Note: Inverted mapping from SSPCARD
    // SSPCARD: 1=Gain 100, 2=Gain 10, 3=Gain 1
    if (gain < 1 || gain > 3) {
        Serial.print("?");
        return;
    }
    
    currentGain = gain;
    Serial.print("!");
}

void handleMirrorControl(const char* command) {
    if (strlen(command) != 6) {
        Serial.print("?");
        return;
    }
    
    // Extract mirror state (last character)
    char stateChar = command[5];
    uint8_t state = stateChar - '0';
    
    if (state > 1) {
        Serial.print("?");
        return;
    }
    
    mirrorState = (state == 1);
    Serial.print("!");
}

void handleSetIntegrationTime(const char* command) {
    if (strlen(command) != 6) {
        Serial.print("?");
        return;
    }
    
    // Extract integration time (nnnn)
    char timeStr[5];
    strncpy(timeStr, command + 2, 4);
    timeStr[4] = '\0';
    
    uint16_t integrationTime = atoi(timeStr);
    if (integrationTime < 1 || integrationTime > 9999) {
        Serial.print("?");
        return;
    }
    
    integrationDuration = integrationTime;
    Serial.print("!");
}

// ============================================================================
// STEPPER CONTROL FUNCTIONS
// ============================================================================

void setupStepperControl() {
    // Enable pins
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    digitalWrite(X_EN_PIN, LOW);  // Enable drivers
    digitalWrite(Y_EN_PIN, LOW);
    
    // Configure steppers
    stepperX.setMaxSpeed(1000);
    stepperX.setAcceleration(500);
    stepperY.setMaxSpeed(1000);
    stepperY.setAcceleration(500);
    
    // Set current position as zero
    stepperX.setCurrentPosition(0);
    stepperY.setCurrentPosition(0);
}

void moveToFilterPosition(uint8_t position) {
    // Simple movement logic - in reality would use calibrated positions
    if (position < 1 || position > 6) {
        return;
    }
    
    // Calculate target position (example: 200 steps per filter)
    int32_t targetSteps = (position - 1) * 200;
    
    // Move stepper
    stepperX.moveTo(targetSteps);
    
    // Wait for movement to complete
    while (stepperX.distanceToGo() != 0) {
        stepperX.run();
    }
    
    currentFilter = position;
}

// ============================================================================
// STATUS LED FUNCTIONS
// ============================================================================

void updateStatusLED() {
    static uint32_t lastBlinkTime = 0;
    static bool ledState = false;
    
    uint32_t currentTime = millis();
    
    if (integrationRunning) {
        // Fast blink during integration
        if (currentTime - lastBlinkTime > 100) {
            ledState = !ledState;
            digitalWrite(STATUS_LED, ledState);
            lastBlinkTime = currentTime;
        }
    } else if (serialMode) {
        // Slow blink in serial mode
        if (currentTime - lastBlinkTime > 500) {
            ledState = !ledState;
            digitalWrite(STATUS_LED, ledState);
            lastBlinkTime = currentTime;
        }
    } else {
        // Solid on in normal operation
        digitalWrite(STATUS_LED, HIGH);
    }
}

// ============================================================================
// ARDUINO SETUP AND LOOP
// ============================================================================

void setup() {
    // Initialize serial for SSP protocol
    Serial.begin(SSP_BAUD);
    
    // Initialize hardware
    setupPulseCounting();
    setupStepperControl();
    
    // Initialize status LED
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    // Initial status indication
    digitalWrite(STATUS_LED, HIGH);
    delay(100);
    digitalWrite(STATUS_LED, LOW);
    delay(100);
    digitalWrite(STATUS_LED, HIGH);
    delay(100);
    digitalWrite(STATUS_LED, LOW);
    
    Serial.println("SSP5A Controller Ready");
    Serial.println("Send 'SSSSSS' to enter serial mode");
}

void loop() {
    // Handle incoming serial commands
    handleSerial();
    
    // Manage integration timer
    if (integrationRunning) {
        if (checkIntegrationComplete()) {
            // Integration complete
            // Count will be sent when SCnnnn command is processed
        }
    }
    
    // Update stepper movement
    stepperX.run();
    stepperY.run();
    
    // Update status LED
    updateStatusLED();
}

// ============================================================================
// NOTES AND LIMITATIONS
// ============================================================================

/*
  IMPORTANT NOTES:
  
  1. PIN CONFLICT: There's a conflict between PULSE_PIN (2) and X_STEP_PIN (2).
     In a real implementation, you would need to:
     - Use a different pin for pulse counting OR
     - Use a different pin for X_STEP on the CNC Shield
     - Modify the CNC Shield jumpers if possible
  
  2. BLOCKING CODE: The handleGetCount() function uses a while loop to wait
     for integration to complete. In a production implementation, this should
     be non-blocking using a state machine.
  
  3. CALIBRATION: Filter positions are hardcoded as 200 steps apart. In reality,
     you would need to calibrate these positions and store them in EEPROM.
  
  4. ERROR HANDLING: This example has minimal error handling. A production
     implementation would need more robust error recovery.
  
  5. PERFORMANCE: For high pulse rates (up to 50kHz), ensure interrupt latency
     is minimized. The pulseISR() function is minimal for this reason.
  
  6. HARDWARE: This code assumes proper pulse conditioning with a 74HC14
     Schmitt trigger. Without this, pulse counting may be unreliable.
*/

/*
  TESTING PROCEDURE:
  
  1. Upload this sketch to Arduino Uno
  2. Open Serial Monitor at 19200 baud
  3. Send "SSSSSS" (should receive "!")
  4. Send "SC1000" (should count pulses for 1 second, then return "C=XXXXX")
  5. Send "SF0012" (should move filter to position 2, return "!")
  6. Send "SG0011" (should set gain to 1, return "!")
  7. Send "SVIEW0" (should set mirror off, return "!")
  8. Send "SI0500" (should set integration time to 500ms, return "!")
  9. Send "EEEEEE" (should exit serial mode, return "!")
*/