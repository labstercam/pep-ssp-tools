/*
  SSP5A Stepper Diagnostic Sketch
  Directly tests X and Y stepper drivers on CNC shield
  Helps diagnose why stepper motor isn't moving
  
  Test Procedure:
  1. Upload this sketch
  2. Open Serial Monitor at 19200 baud
  3. Follow prompts to test each stepper driver
*/

// CNC Shield Stepper Pins
#define X_STEP_PIN       2     // CNC Shield X-STEP (D2)
#define X_DIR_PIN        5     // CNC Shield X-DIR (D5)
#define X_EN_PIN         12    // CNC Shield X-ENABLE (D12)
#define Y_STEP_PIN       3     // CNC Shield Y-STEP (D3)
#define Y_DIR_PIN        6     // CNC Shield Y-DIR (D6)
#define Y_EN_PIN         13    // CNC Shield Y-ENABLE (D13)
#define STATUS_LED       13    // Built-in LED (shared with Y_ENABLE)

// Test constants
#define STEP_DELAY_MS    10    // 10ms between steps for easy observation
#define NUM_STEPS_TEST   20    // 20 steps per test

void setup() {
    Serial.begin(19200);
    delay(1000);
    
    Serial.println("========================================");
    Serial.println("SSP5A Stepper Diagnostic Test");
    Serial.println("========================================");
    Serial.println();
    
    // Initialize stepper pins
    pinMode(X_EN_PIN, OUTPUT);
    pinMode(Y_EN_PIN, OUTPUT);
    pinMode(X_STEP_PIN, OUTPUT);
    pinMode(X_DIR_PIN, OUTPUT);
    pinMode(Y_STEP_PIN, OUTPUT);
    pinMode(Y_DIR_PIN, OUTPUT);
    pinMode(STATUS_LED, OUTPUT);
    
    // Start with drivers DISABLED (HIGH)
    digitalWrite(X_EN_PIN, HIGH);
    digitalWrite(Y_EN_PIN, HIGH);
    digitalWrite(X_STEP_PIN, LOW);
    digitalWrite(X_DIR_PIN, LOW);
    digitalWrite(Y_STEP_PIN, LOW);
    digitalWrite(Y_DIR_PIN, LOW);
    digitalWrite(STATUS_LED, LOW);
    
    Serial.println("Stepper drivers DISABLED (ENABLE pins HIGH)");
    Serial.println("Press any key to begin tests...");
    Serial.println();
}

void loop() {
    // Wait for user input
    if (Serial.available()) {
        Serial.read(); // Clear the input
        
        runDiagnosticTests();
        
        Serial.println();
        Serial.println("Tests complete. Press any key to run again.");
        Serial.println("Or upload a different sketch.");
    }
    
    // Blink LED slowly
    static uint32_t lastBlink = 0;
    if (millis() - lastBlink > 500) {
        digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
        lastBlink = millis();
    }
}

void runDiagnosticTests() {
    Serial.println();
    Serial.println("=== Starting Diagnostic Tests ===");
    Serial.println();
    
    // Test 1: Check if drivers are getting power
    Serial.println("Test 1: Power Check");
    Serial.println("-------------------");
    Serial.println("1. Check 12V power is connected to CNC shield");
    Serial.println("2. Check DRV8825 chips are getting warm (not hot!)");
    Serial.println("3. Check VREF voltage (~0.1V for 1A current)");
    Serial.println("Press any key to continue...");
    waitForInput();
    
    // Test 2: Enable drivers
    Serial.println();
    Serial.println("Test 2: Enable Drivers");
    Serial.println("----------------------");
    Serial.println("Enabling X and Y drivers (ENABLE pins LOW)...");
    digitalWrite(X_EN_PIN, LOW);
    digitalWrite(Y_EN_PIN, LOW);
    Serial.println("Drivers ENABLED.");
    Serial.println("You should hear a faint buzzing from stepper motors.");
    Serial.println("Press any key to continue...");
    waitForInput();
    
    // Test 3: Test X-axis stepper
    Serial.println();
    Serial.println("Test 3: X-Axis Stepper Test");
    Serial.println("---------------------------");
    Serial.println("Testing X-axis (pins 7 & 4 on SSP5A)...");
    Serial.println("Moving FORWARD 20 steps...");
    
    digitalWrite(X_DIR_PIN, HIGH); // Forward direction
    moveStepper(X_STEP_PIN, NUM_STEPS_TEST, "X-axis");
    
    Serial.println("Moving BACKWARD 20 steps...");
    digitalWrite(X_DIR_PIN, LOW); // Backward direction
    moveStepper(X_STEP_PIN, NUM_STEPS_TEST, "X-axis");
    
    Serial.println("X-axis test complete.");
    Serial.println("Press any key to continue...");
    waitForInput();
    
    // Test 4: Test Y-axis stepper
    Serial.println();
    Serial.println("Test 4: Y-Axis Stepper Test");
    Serial.println("---------------------------");
    Serial.println("Testing Y-axis (pins 3 & 2 on SSP5A)...");
    Serial.println("Moving FORWARD 20 steps...");
    
    digitalWrite(Y_DIR_PIN, HIGH); // Forward direction
    moveStepper(Y_STEP_PIN, NUM_STEPS_TEST, "Y-axis");
    
    Serial.println("Moving BACKWARD 20 steps...");
    digitalWrite(Y_DIR_PIN, LOW); // Backward direction
    moveStepper(Y_STEP_PIN, NUM_STEPS_TEST, "Y-axis");
    
    Serial.println("Y-axis test complete.");
    Serial.println("Press any key to continue...");
    waitForInput();
    
    // Test 5: Test both axes together
    Serial.println();
    Serial.println("Test 5: Both Axes Together");
    Serial.println("--------------------------");
    Serial.println("Testing X and Y axes together...");
    Serial.println("Moving FORWARD 20 steps...");
    
    digitalWrite(X_DIR_PIN, HIGH);
    digitalWrite(Y_DIR_PIN, HIGH);
    moveBothSteppers(NUM_STEPS_TEST);
    
    Serial.println("Both axes test complete.");
    
    // Disable drivers
    digitalWrite(X_EN_PIN, HIGH);
    digitalWrite(Y_EN_PIN, HIGH);
    Serial.println("Drivers DISABLED.");
    
    Serial.println();
    Serial.println("=== Diagnostic Results ===");
    Serial.println("1. If NO movement/sound: Check 12V power, VREF, enable pins");
    Serial.println("2. If ONE axis works: Check wiring for non-working axis");
    Serial.println("3. If BOTH work: Stepper control in main sketch has issue");
    Serial.println("4. If wrong direction: Swap motor connections (+/-)");
}

void moveStepper(int stepPin, int steps, String axisName) {
    for (int i = 0; i < steps; i++) {
        digitalWrite(stepPin, HIGH);
        delay(STEP_DELAY_MS);
        digitalWrite(stepPin, LOW);
        delay(STEP_DELAY_MS);
        
        if (i % 5 == 0) {
            Serial.print(".");
        }
    }
    Serial.println();
    Serial.println(axisName + " moved " + String(steps) + " steps.");
}

void moveBothSteppers(int steps) {
    for (int i = 0; i < steps; i++) {
        digitalWrite(X_STEP_PIN, HIGH);
        digitalWrite(Y_STEP_PIN, HIGH);
        delay(STEP_DELAY_MS);
        digitalWrite(X_STEP_PIN, LOW);
        digitalWrite(Y_STEP_PIN, LOW);
        delay(STEP_DELAY_MS);
        
        if (i % 5 == 0) {
            Serial.print(".");
        }
    }
    Serial.println();
    Serial.println("Both axes moved " + String(steps) + " steps.");
}

void waitForInput() {
    while (!Serial.available()) {
        delay(100);
    }
    Serial.read(); // Clear the input
}

/*
  TROUBLESHOOTING GUIDE:
  
  1. NO MOVEMENT OR SOUND:
     - Check 12V power supply is connected to CNC shield
     - Check DRV8825 VREF voltage (~0.1V for 1A current)
     - Check enable pins (D12, D13) are LOW when enabled
     - Check microstepping jumpers are installed
     - Check motor connections are secure
  
  2. ONE AXIS WORKS, OTHER DOESN'T:
     - Check wiring for non-working axis
     - Swap DRV8825 chips between X and Y
     - Check STEP/DIR/ENABLE pins for that axis
  
  3. MOTOR BUZZES BUT DOESN'T MOVE:
     - VREF voltage too low (increase slightly)
     - Motor current too low for holding torque
     - Try different microstepping setting
  
  4. MOTOR MOVES WRONG DIRECTION:
     - Swap the two motor wires for that axis
     - Change DIR pin logic in code
  
  5. MOTOR MOVES TOO FAST/SLOW:
     - Adjust STEP_DELAY_MS in code
     - Check microstepping jumper settings
  
  DRV8825 VREF CALCULATION:
  VREF = (Desired Current × 0.2) ÷ 2
  Example: For 1A current → VREF = (1.0 × 0.2) ÷ 2 = 0.1V
  
  MICROSTEPPING SETTINGS:
  Full Step:     MS1=OFF, MS2=OFF, MS3=OFF
  1/2 Step:      MS1=ON,  MS2=OFF, MS3=OFF  
  1/4 Step:      MS1=OFF, MS2=ON,  MS3=OFF  (Recommended)
  1/8 Step:      MS1=ON,  MS2=ON,  MS3=OFF
  1/16 Step:     MS1=ON,  MS2=ON,  MS3=ON
*/