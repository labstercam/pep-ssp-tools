/*
  SSP5A Arduino Controller - Serial Communications Only
  
  Simplified version that ONLY handles serial communications and pulse counting.
  NO stepper motor control - for manual filter operation.
  
  Compatible with SSPDataq3 and SharpCap-SSP software
*/

// Hardware Configuration
#define PULSE_PIN        A4     // Pulse input pin
#define STATUS_LED       13     // Built-in LED

// Debug mode (set to 1 to enable serial debug output)
#define DEBUG_MODE       0

// System Constants
#define SSP_BAUD             19200
#define SERIAL_BUFFER_SIZE   16
#define COMMAND_TIMEOUT_MS   100
#define INTEGRATION_MIN      1
#define INTEGRATION_MAX      9999

// Global Variables
volatile uint32_t pulseCount = 0;
volatile bool countingActive = false;
uint32_t integrationStartTime = 0;
uint32_t integrationDuration = 0;
char serialBuffer[SERIAL_BUFFER_SIZE];
uint8_t bufferIndex = 0;
uint32_t lastCharTime = -1000;
uint8_t currentGain = 1;
uint16_t integrationTime = 1000;
bool serialMode = false;
bool integrationActive = false;
uint32_t lastCommandTime = 0;

// Boot timing tracking
uint32_t bootStartTime = 0;
uint32_t firstCommandReceivedTime = 0;
bool bootComplete = false;
char earlyCommandBuffer[32] = {0};
bool earlyCommandReceived = false;

// Pulse Counting Functions
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

// Integration Timer Functions
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

// Serial Communication Functions
void handleSerialCommunication() {
    while (Serial.available()) {
        char c = Serial.read();
        #if DEBUG_MODE
        Serial.print("[DBG] Rx char: ");
        Serial.print(c);
        Serial.print(" (");
        Serial.print((int)c);
        Serial.println(")");
        #endif
        
        if (bufferIndex > 0 || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
            lastCharTime = millis();
            
            // Check for command termination first
            if (c == '\r' || c == '\n') {
                if (bufferIndex > 0) { // At least 1 character before terminator
                    // Null-terminate and process command
                    serialBuffer[bufferIndex] = '\0';
                    processCommand(serialBuffer);
                    bufferIndex = 0;
                }
                continue; // Don't store terminator
            }
            
            // Store character
            if (bufferIndex < SERIAL_BUFFER_SIZE - 1) {
                serialBuffer[bufferIndex++] = c;
                serialBuffer[bufferIndex] = '\0'; // Keep string terminated
            } else {
                bufferIndex = 0;
                if (serialMode) Serial.print("?");
                continue;
            }
            
            // Check for potentially complete command (5 or 6 chars starting with 'S')
            if (bufferIndex >= 5 && serialBuffer[0] == 'S') {
                // SSP commands: SHNNN (5 chars) or SSSSSS, SEEEEE, SFNNN1 (6 chars)
                // Check if this looks like a complete command
                if (bufferIndex == 6) {
                    // 6-character commands
                    #if DEBUG_MODE
                    Serial.print("[DBG] Detected 6-char cmd: ");
                    Serial.println(serialBuffer);
                    #endif
                    processCommand(serialBuffer);
                    bufferIndex = 0;
                } else if (bufferIndex == 5) {
                    // Check for 5-character command SHNNN
                    if (serialBuffer[1] == 'H' && serialBuffer[2] == 'N' && 
                        serialBuffer[3] == 'N' && serialBuffer[4] == 'N') {
                        #if DEBUG_MODE
                        Serial.print("[DBG] Detected SHNNN cmd: ");
                        Serial.println(serialBuffer);
                        #endif
                        processCommand(serialBuffer);
                        bufferIndex = 0;
                    }
                }
            }
        }
    }
    
    // Handle timeout - if we have a buffer and timeout expired
    if (bufferIndex > 0 && (millis() - lastCharTime) > COMMAND_TIMEOUT_MS) {
        #if DEBUG_MODE
        Serial.print("[DBG] Timeout with buffer: ");
        Serial.println(serialBuffer);
        #endif
        
        // Process any incomplete SSP command on timeout (SSP software might not send CR/LF)
        if (serialBuffer[0] == 'S' && bufferIndex >= 5) {
            // Null-terminate and process the command
            serialBuffer[bufferIndex] = '\0';
            processCommand(serialBuffer);
        }
        bufferIndex = 0;
    }
}

void processCommand(const char* command) {
    lastCommandTime = millis();
    
    // Track when first command is received relative to boot
    if (firstCommandReceivedTime == 0) {
        firstCommandReceivedTime = millis() - bootStartTime;
        #if DEBUG_MODE
        Serial.print("[DBG] First command received at: ");
        Serial.print(firstCommandReceivedTime);
        Serial.println("ms after boot");
        #endif
    }
    
    #if DEBUG_MODE
    Serial.print("[DBG] Cmd: '");
    Serial.print(command);
    Serial.print("' Len: ");
    Serial.println(strlen(command));
    #endif
    
    if (strlen(command) < 2 || command[0] != 'S') {
        if (serialMode) Serial.print("?");
        return;
    }
    
    char cmdChar = command[1];
    switch (cmdChar) {
        case 'S':  // Enter serial mode
            if (strcmp(command, "SSSSSS") == 0) {
                serialMode = true;
                Serial.print("!");
            } else if (serialMode) Serial.print("?");
            break;
            
        case 'E':  // Exit serial mode
            if (strcmp(command, "SEEEEE") == 0) {
                serialMode = false;
                Serial.print("!");
            } else if (serialMode) Serial.print("?");
            break;
            
        case 'F':  // Filter position (response only)
            if (strlen(command) == 6) Serial.print("!");
            else if (serialMode) Serial.print("?");
            break;
            
        case 'C':  // Get count
            if (strlen(command) == 6) {
                char timeStr[5];
                strncpy(timeStr, command + 2, 4);
                timeStr[4] = '\0';
                uint16_t requestedIntegrationTime = atoi(timeStr);
                if (requestedIntegrationTime >= INTEGRATION_MIN && requestedIntegrationTime <= INTEGRATION_MAX) {
                    startIntegration(requestedIntegrationTime);
                    unsigned long startTime = millis();
                    unsigned long waitTime = requestedIntegrationTime;
                    if (requestedIntegrationTime == 1000) waitTime = 1150;
                    else if (requestedIntegrationTime <= 1000) waitTime = requestedIntegrationTime * 1.15;
                    else if (requestedIntegrationTime <= 5000) waitTime = requestedIntegrationTime * 1.03;
                    else waitTime = requestedIntegrationTime * 1.015;
                    
                    unsigned long endTime = startTime + waitTime;
                    while (millis() < endTime) {
                        checkIntegrationComplete();
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
                } else if (serialMode) Serial.print("?");
            } else if (serialMode) Serial.print("?");
            break;
            
        case 'G':  // Set gain
            if (strlen(command) == 6) {
                char gainChar = command[5];
                uint8_t gain = gainChar - '0';
                if (gain >= 1 && gain <= 3) {
                    currentGain = gain;
                    Serial.print("!");
                } else if (serialMode) Serial.print("?");
            } else if (serialMode) Serial.print("?");
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
                } else if (serialMode) Serial.print("?");
            } else if (serialMode) Serial.print("?");
            break;
            
        case 'H':  // Home position query
            if (strlen(command) == 6) Serial.print("!");
            else if (serialMode) Serial.print("?");
            break;
            
        case 'M':  // Mirror flip query
            if (strlen(command) == 6) Serial.print("!");
            else if (serialMode) Serial.print("?");
            break;
            
        default:
            if (serialMode) Serial.print("?");
            break;
    }
}

// Main Arduino Functions
void setup() {
    bootStartTime = millis();
    Serial.begin(SSP_BAUD);
    
    #if DEBUG_MODE
    Serial.print("[DBG] SSP5A Arduino Starting - Boot time: ");
    Serial.println(bootStartTime);
    Serial.println("[DBG] DEBUG_MODE enabled");
    #endif
    
    // Initialize STATUS_LED early for boot indicator
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);
    
    // Check for incoming data IMMEDIATELY after Serial.begin
    // SSPData3 might send commands during our boot
    uint32_t serialReadyTime = millis();
    while (millis() - serialReadyTime < 2000) { // Check for 2 seconds
        if (Serial.available()) {
            #if DEBUG_MODE
            Serial.print("[DBG] Data available during boot at ");
            Serial.print(millis() - bootStartTime);
            Serial.println("ms");
            #endif
            // Process incoming data during boot
            handleSerialCommunication();
        }
        // Quick LED blink to show we're alive
        static uint32_t lastBlink = 0;
        if (millis() - lastBlink > 100) {
            digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
            lastBlink = millis();
        }
    }
    
    // Minimal initialization - be ready ASAP
    setupPulseCounting();
    
    // Quick status LED blink
    digitalWrite(STATUS_LED, HIGH);
    delay(30);
    digitalWrite(STATUS_LED, LOW);
    
    // Mark boot as complete early
    bootComplete = true;
    
    #if DEBUG_MODE
    uint32_t setupCompleteTime = millis() - bootStartTime;
    Serial.print("[DBG] Setup complete in ");
    Serial.print(setupCompleteTime);
    Serial.println("ms - waiting for commands");
    #endif
    
    lastCommandTime = millis();
}

void loop() {
    handleSerialCommunication();
    if (integrationActive) {
        checkIntegrationComplete();
        updatePulseCounting();
    }
    static uint32_t lastBlinkTime = 0;
    if (millis() - lastBlinkTime > 1000) {
        digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
        lastBlinkTime = millis();
    }
    static uint32_t lastTimeoutCheck = 0;
    uint32_t currentTime = millis();
    if (currentTime - lastTimeoutCheck > 5000) {
        if (serialMode && (currentTime - lastCommandTime) > 120000) {
            serialMode = false;
        }
        lastTimeoutCheck = currentTime;
    }
}

// Documentation
/*
  SSP5A ARDUINO CONTROLLER - SERIAL COMMUNICATIONS ONLY
  
  This version ONLY handles serial communications and pulse counting.
  NO stepper motor control is included.
  
  Commands supported:
  - SSSSSS: Enter serial mode (returns "!")
  - SEEEEE: Exit serial mode (returns "!")
  - SF00xx: Filter position query (returns "!" - no movement)
  - SCxxxx: Get count (xxxx = integration time 1-9999ms)
  - SG00xx: Set gain (xx = 1-3)
  - SIxxxx: Set integration time (xxxx = 1-9999ms)
  - SH0000: Home position query (returns "!")
  - SM0000: Mirror flip query (returns "!")
  
  Wiring:
  SSP5A Pin 8 (Green)  → Arduino A4 (Pulse input)
  SSP5A Pin 6 (Red)    → Arduino 5V
  SSP5A GND           → Arduino GND
  
  For use with SSPDataq3 and SharpCap-SSP software.
*/