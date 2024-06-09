
/***************
* Dice machine for the Dungeon and Dragons (DnD) fantasy role play game
design for the De1SoC. 

* The User has switches and push buttons to use the program and the result will
be displayed in the 7 segment display
* Has multiple switches to roll different faced dices. One (1) switch has to be cohsen
for the program to work as intended, otherwise user will be warned with error.
* The user can use any push buttons.
* After some time passed, the random result will be shown in decimal number.

* Switches are mapped to the dice_sides_array directive.
* Seven Segment values are mapped to the seven_seg_table directive.

***************/


// By: Bogdan Itsam Dorantes-Nikolaev, Onur Keles, Omer Mert Yildiz

.global _start
_start:
	//Initilazing our base addresses.
    LDR R0, =0xFF200050         // Base address for push button.
    LDR R1, =0xFF200040         // Base address for switches.
    LDR R2, =0xFF200020         // Base address for HEX displays.
    LDR R3, =0xFFFEC600         // Base address for private timer.
    LDR R4, =dice_sides_array   // Base address of sides array.
    LDR R5, =seven_seg_table   // Base address of 7-segment lookup table.
	LDR R12, =variable_x
	
	LDR R6, =2000000			// A number that will help us to work with the timer.
	STR R6, [R3]				// Store the timers Load value into the timer.
    MOV R6, #0x0003             // Move the auto reload and enable values to a register.
    STR R6, [R3, #8]            // Activate auto reload and enable with shifting to control address of timer.
	
	BL display_start			// Display the start up screen.
	
loop:
    LDR R6, [R0, #0xC]          //  Read push button state.
    CMP R6, #0					//  If 0:
    BEQ loop					//  No button pushed yet, wait until button is pressed.
    							//If pressed, continue.

    STR R6, [R0, #0xC]			// Acknowledge that button is pressed.
    
	LDR R7, [R1]                // Read switch state.
    CMP R7, #0                  // Check if no switch is flipped.
    BEQ display_SL              // If no switch flipped, display SL and restart the loop.
    
	MOV R6, R7                  // Copy switch state to R6 for counting.
    BL is_switch_error          // Check if switch error occured.
    

    BL which_switch             // Understanding which switched turned by the user.
	BL random_number			// Get a random number and save it to our variable_x address.
    BL delay_result             // To have a little bit more realistic result, delay the result.
	B display_result            // Display the result of rolling a dice with determined limit.



display_start: 
	PUSH {R6}		// Save register(s) to stack
	
	LDR R6, =0x50DEEE			// Load "rdY" pattern for HEX displays
	STR R6, [R2]				// Displaying "rdY" pattern
	POP {R6}					// Restore register(s) from stack
	BX LR						// Branch to linked branch

display_error: 
	PUSH {R6}		// Save register(s) to stack
    
	LDR R6, =0x7950             // Load "Er" pattern for HEX displays
    STR R6, [R2]				// Displaying "ER" pattern
    POP {R6}					// Restore register(s) from stack
	B loop						

display_SL: 
	PUSH {R6}			// Save register(s) to stack
    
	LDR R6, =0x6D38             // Load "SL" pattern for HEX displays
    STR R6, [R2]				// Displaying "SL" pattern
    POP {R6}					// Restore register(s) from stack
	B loop						// Branch to loop

clear_HEX: 
	PUSH {R6}			// Save register(s) to stack
    
	MOV R6, #0                  // Initilaze 0 value to write nothing in HEX display
    STR R6, [R2]                // Clear HEX display
    POP {R6}
    BX LR                       // Branch to linked branch
	
/********** 
We will display the dice result in Seven-Segment-Display (SSD).
To do it before, we seperate our values into two.

If it is bigger than 9, 
It will be considered as two digit number and resume it's display from there.

If it is not,
Than it will just continue with simpler display for only one digit.
**********/ 
	
display_result: 
	PUSH {R6}		// Save register(s) to stack.
    
    LDR R7, [R12]				// Load our random value to a register.
    CMP R7, #10                 // Check if the number is a single digit or two digits.
    BGE display_two_digits		// Seperate function to display more than one digit.

// Single Digit Display
    BL clear_HEX                // Clear HEX from previous display.
    LDR R6, [R5, R7, LSL #2]    // Load corresponding 7-segment code
    STR R6, [R2]                // Store it in SSD
    POP {R6}					// Restore register(s) from stack
    B loop						// Branch to loop.

// Two Digit Display
display_two_digits:
	
	PUSH {R2, R4}			    // Save register(s) to stack
	MOV R6, #1					// Initilaze the counter with 1
	//
	loopDigits: SUB R7, R7, #10	// Remove 10 from the random number
	CMP R7, #10					//
	ADDGE R6 ,R6, #1			// If the random number is 20, 30 etc. then R6++
	BGE loopDigits				//
	
	LDR R7, [R5, R7, LSL #2]	// Load corresponding 7-segment code for 0th HEX
	
	LDR R4, [R5, R6, LSL #2]	// Load corresponding 7-segment code for 1st HEX
	LSL R4, R4, #8				// Adjustment for to display in 1st HEX
	
	ORR R4, R7, R4				// Combine both first and second digit of the number applicable for 
								// SSD.
								
	STR R4, [R2]				// Store it in the SSD
	POP {R2, R4, R6}			// Restore register(s) from stack.
	B loop						// Branch to loop.
/******

A small subroutine just to have more realistic dice rolling feeling.

******/
delay_result: 
	PUSH {R6}					// Save register(s) to stack.
	
	LDR R6, =0x080808			// Load the display-loading pattern.
	STR R6, [R2]				// Display loading pattern on HEX Displays.
	
    // A simple delay counter with subtraction
	LDR R6, =0x00300000			
	wait_loop: SUBS R6, R6, #1	// 
	BNE wait_loop				// Return to linked branch.
	POP {R6}					// Restore register(s) from stack.
	BX LR						// Branch to linked branch.

/********** 

Brian Kernighans Algorithm to count bits for checking multiple switches.	
If there are more than one switch flipped, give an error display and return
to original loop.

**********/

is_switch_error:	
	PUSH {R6, R8, R10}					
	MOV R8, #0					// R8 will store the count of bits.
	
count_loop:						//
    CMP R6, #0					// If R6 is 0.
    BEQ end_count				// Finish counting.
    MOV R10, R6					// If not: move it to R10.
    AND R10, R10, #1			// Mask R10 with 1 to get the LSB.
    ADD R8, R8, R10				// Add it to our counter register (R8).
    LSR R6, R6, #1				// LSR to get the next bit.
    B count_loop				// Branch back to count_loop.
	
end_count:						
    CMP R8, #1                  // Check if more than one switch is activated.
    POP {R6, R8, R10}			// Restore register(s) from stack.
    
    BGT display_error           // Display error if more than one switch is toggled.
	BX LR						// Return to linked branch.

/********** 

Dice will only be rolled if one switch is turned. Therefore,
We check which exact switch is turned on by Comparing with each switch addresses.

The correct switch will be hold in predetermined address to be used in random number. 

**********/ 

which_switch: 
	PUSH {R7}					// Save register(s) to stack.
   

    CMP R7, #0x1				// Is it 0th switch.
    MOVEQ R7, #1				// If so assign 1.
    CMP R7, #0x2				// Is it 1th switch.
    MOVEQ R7, #2				// If so assign 2.
    CMP R7, #0x4				//...
    MOVEQ R7, #3
    CMP R7, #0x8
    MOVEQ R7, #4
    CMP R7, #0x10
    MOVEQ R7, #5
    CMP R7, #0x20
    MOVEQ R7, #6
    CMP R7, #0x40
    MOVEQ R7, #7
    CMP R7, #0x80
    MOVEQ R7, #8
    CMP R7, #0x100
    MOVEQ R7, #9
    CMP R7, #0x200
    MOVEQ R7, #10
    
    STR R7, [R12]				// Load the switch value in predetermined address.
	POP {R7}					// Restore register(s) from stack.
	BX LR                       // Return to linked branch.


/********** 

Dice will need a random number with predetermined value. Therefore,
We use switch value to choose which type of dice has been used, to calculate our upper
limit in our dice. After getting the random number,

It will be hold in predetermined address to be used in display the number. 

**********/ 
random_number: 
	PUSH {R6, R7}	// Save register(s) to stack.

	LDR R7, [R12]				// Load from our predetermined address.
    LDR R6, [R3, #4]            // Get current value from the timer.
    LDR R7, [R4, R7, LSL #2]    // Aligned it to have the number for sides.
    AND R7, R6, R7              // Module Operation to have the correct upper limit.
    ADD R7, R7, #1              // We add one (1) to exclude 0 option from the dice.
    STR R7, [R12]				// We store random value to the predetermined address.
	
	POP {R6, R7}				// Restore register(s) from stack.
	BX LR                       // Return to linked branch.

seven_seg_table:				// 7-Segment HEX Display "Translation" Table
    .word 0x3F                  // 0
    .word 0x06                  // 1
    .word 0x5B                  // 2
    .word 0x4F                  // 3
    .word 0x66                  // 4
    .word 0x6D                  // 5
    .word 0x7D                  // 6
    .word 0x07                  // 7
    .word 0x7F                  // 8
    .word 0x6F                  // 9

	
dice_sides_array:               // "Array" storing the dice values mapped to the toggle switches
    .word 0                     // Dummy value DO NOT REMOVE
    .word 1                     // 2-sided (coin)
    .word 3                     // 4-sided
    .word 5                     // 6-sided
    .word 7                     // 8-sided
    .word 9                     // 10-sided
    .word 11                    // 12-sided
    .word 19                    // 20-sided
    .word 31                    // 32-sided
    .word 63                    // 64-sided
    .word 98                    // 99-sided
	
variable_x: .word 0
