; ASEM-51 COMPATIBLE COIN COUNTER
; For 8051/8052 microcontroller
; Features:
; - 2-coin and 5-coin counting
; - 16-bit amount tracking (up to 9999)
; - 4-digit 7-segment display
; - LCD status display
; - Reset functionality

$NOMOD51
$INCLUDE (80C52.MCU)

;-----------------------------------------
; Hardware Definitions
;-----------------------------------------
; LCD Interface
DATA_LINE   EQU P2           ; Data Port (DB0-DB7 on Port 2)
RS          EQU P1.0         ; RS of LCD
RW          EQU P1.1         ; RW of LCD
EN          EQU P1.2         ; Enable signal for LCD

; Buttons (active low)
BTN_2COIN    BIT  P3.0       ; 2-coin button
BTN_5COIN    BIT  P3.1       ; 5-coin button
BTN_SUMMARY  BIT  P0.0
BTN_TOTAL    BIT  P0.1
RESET_BTN    BIT  P0.2       ; Reset button (INT0)

;-----------------------------------------
; Variable Definitions
;-----------------------------------------
; 16-bit counters (low byte first)
COIN2_AMT_LB DATA 30H
COIN2_AMT_HB DATA 31H
COIN5_AMT_LB DATA 32H
COIN5_AMT_HB DATA 33H
COUNT2_LB    DATA 34H        ; 2-coin count (low byte)
COUNT2_HB    DATA 35H        ; 2-coin count (high byte)
COUNT5_LB    DATA 36H        ; 5-coin count (low byte)
COUNT5_HB    DATA 37H        ; 5-coin count (high byte)
TOTAL_LB     DATA 38H
TOTAL_HB     DATA 39H

;----------------------------------------
; Data Variables
;----------------------------------------
DIGIT1      DATA 40H     ; Ten-thousands
DIGIT2      DATA 41H     ; Thousands
DIGIT3      DATA 42H     ; Hundreds
DIGIT4      DATA 43H     ; Tens
DIGIT5      DATA 44H     ; Units

; Display variables
ERROR_FLAG   BIT  20H.0      ; Error flag (bit-addressable)

;---------------------------------------------------
; ORG and Interrupt Vectors
;---------------------------------------------------
ORG 0000H
    JMP MAIN


;-----------------------------------------
; Main Program Initialization
;-----------------------------------------
MAIN:
    MOV  SP, #70H            ; Initialize stack pointer
    ACALL LCD_INIT
    ACALL CLEAR_DATA
    ACALL SHOW_WELCOME
    LJMP MAIN_LOOP


CLEAR_DATA:
    ; Initialize all counters to zero
    CLR  A
    MOV  COIN2_AMT_LB, #0
    MOV  COIN2_AMT_HB, #0
    MOV  COIN5_AMT_LB, #0
    MOV  COIN5_AMT_HB, #0
    MOV  COUNT2_LB, #0
    MOV  COUNT2_HB, #0
    MOV  COUNT5_LB, #0
    MOV  COUNT5_HB, #0
    CLR  ERROR_FLAG
    RET
    
    
   
;-----------------------------------------
; Main Program Loop
;-----------------------------------------
MAIN_LOOP:
    JB ERROR_FLAG, MAIN_LOOP      ; If error, halt here
    ACALL CHECK_BUTTON_2COIN
    ACALL CHECK_BUTTON_5COIN
    ACALL CHECK_BUTTON_SUMMARY
    ACALL CHECK_BUTTON_TOTAL
    ACALL CHECK_BUTTON_RESET
    SJMP MAIN_LOOP

;---------------------------------
; 2-Coin Button Handler
;---------------------------------
CHECK_BUTTON_2COIN:
    JNB BTN_2COIN, BUTTON2_DETECTED
    RET

BUTTON2_DETECTED:
    ACALL DEBOUNCE
    JNB BTN_2COIN, BUTTON2_CONFIRMED
    RET

BUTTON2_CONFIRMED:
    ACALL COIN2_COUNTER
    ACALL WAIT_RELEASE_2
    RET

WAIT_RELEASE_2:
    JB BTN_2COIN, RELEASED_2
    SJMP WAIT_RELEASE_2
RELEASED_2:
    ACALL DEBOUNCE
    RET

;---------------------------------
; 5-Coin Button Handler
;---------------------------------
CHECK_BUTTON_5COIN:
    JNB BTN_5COIN, BUTTON5_DETECTED
    RET

BUTTON5_DETECTED:
    ACALL DEBOUNCE
    JNB BTN_5COIN, BUTTON5_CONFIRMED
    RET

BUTTON5_CONFIRMED:
    ACALL COIN5_COUNTER
    ACALL WAIT_RELEASE_5
    RET

WAIT_RELEASE_5:
    JB BTN_5COIN, RELEASED_5
    SJMP WAIT_RELEASE_5
RELEASED_5:
    ACALL DEBOUNCE
    RET

;---------------------------------
; Summary Button Handler
;---------------------------------
CHECK_BUTTON_SUMMARY:
    JNB BTN_SUMMARY, BUTTON_SUM_DETECTED
    RET

BUTTON_SUM_DETECTED:
    ACALL DEBOUNCE
    JNB BTN_SUMMARY, BUTTON_SUM_CONFIRMED
    RET

BUTTON_SUM_CONFIRMED:
    ACALL UPDATE_SUMMARY
    ACALL WAIT_RELEASE_SUM
    RET

WAIT_RELEASE_SUM:
    JB BTN_SUMMARY, RELEASED_SUM
    SJMP WAIT_RELEASE_SUM
RELEASED_SUM:
    ACALL DEBOUNCE
    RET

;---------------------------------
; Total Button Handler
;---------------------------------
CHECK_BUTTON_TOTAL:
    JNB BTN_TOTAL, BUTTON_TOTAL_DETECTED
    RET

BUTTON_TOTAL_DETECTED:
    ACALL DEBOUNCE
    JNB BTN_TOTAL, BUTTON_TOTAL_CONFIRMED
    RET

BUTTON_TOTAL_CONFIRMED:
    ACALL UPDATE_TOTAL
    ACALL WAIT_RELEASE_TOTAL
    RET

WAIT_RELEASE_TOTAL:
    JB BTN_TOTAL, RELEASED_TOTAL
    SJMP WAIT_RELEASE_TOTAL
RELEASED_TOTAL:
    ACALL DEBOUNCE
    RET
;---------------------------------
; RESET Button Handler
;---------------------------------
CHECK_BUTTON_RESET:
    JNB RESET_BTN, RESET_BTN_DETECTED
    RET

RESET_BTN_DETECTED:
    ACALL DEBOUNCE
    JNB RESET_BTN, RESET_BTN_CONFIRMED
    RET

RESET_BTN_CONFIRMED:
    ACALL RESET_ISR
    ACALL WAIT_RELEASE_RESET
    RET

WAIT_RELEASE_RESET:
    JB RESET_BTN, RELEASED_RESET
    SJMP WAIT_RELEASE_RESET
RELEASED_RESET:
    ACALL DEBOUNCE
    RET
;-----------------------------------------
; Interrupt Service Routines
;-----------------------------------------
RESET_ISR:
    ACALL CLEAR_DATA
    ACALL UPDATE_DISPLAY
    RET

;-----------------------------------------
; Coin Processing Functions
;-----------------------------------------
;-----------------------------
; Coin 2 COUNTER Routine
;-----------------------------
COIN2_COUNTER:
    ; Increment 2-coin counter (16-bit)
    INC  COUNT2_LB
    MOV  A, COUNT2_LB
    JNZ  CALCULATE_AMT_COIN2
    INC  COUNT2_HB

CALCULATE_AMT_COIN2:
    ; Add ?2 to amount
    MOV  A, COIN2_AMT_LB
    ADD  A, #2
    MOV  COIN2_AMT_LB, A
    JNC  SKIP_INC_HB2
    INC  COIN2_AMT_HB

SKIP_INC_HB2:
    ; Overflow check
    ACALL CHECK_OVERFLOW_COIN2
    RET

;-----------------------------
; Coin 5 COUNTER Routine
;-----------------------------
COIN5_COUNTER:
    ; Increment 5-coin counter (16-bit)
    INC  COUNT5_LB
    MOV  A, COUNT5_LB
    JNZ  CALCULATE_AMT_COIN5
    INC  COUNT5_HB

CALCULATE_AMT_COIN5:
    ; Add ?5 to amount
    MOV  A, COIN5_AMT_LB
    ADD  A, #5
    MOV  COIN5_AMT_LB, A
    JNC  SKIP_INC_HB5
    INC  COIN5_AMT_HB

SKIP_INC_HB5:
    ; Overflow check
    ACALL CHECK_OVERFLOW_COIN5
    RET

;-----------------------------
; Overflow Check for ?9999 (0x270F)
;-----------------------------
CHECK_OVERFLOW_COIN2:
    MOV  A, COIN2_AMT_HB
    CJNE A, #27H, CHECK_HIGH_OK
    MOV  A, COIN2_AMT_LB
    CJNE A, #0FH, CHECK_LOW_OK
    SJMP SET_ERROR  ; Equals 9999 ? set error
    
CHECK_OVERFLOW_COIN5:
    MOV  A, COIN5_AMT_HB
    CJNE A, #27H, CHECK_HIGH_OK
    MOV  A, COIN5_AMT_LB
    CJNE A, #0FH, CHECK_LOW_OK
    SJMP SET_ERROR  ; Equals 9999 ? set error

CHECK_HIGH_OK:
    JC   UPDATE_OK  ; AMOUNT_HB < 27H
    SJMP SET_ERROR  ; AMOUNT_HB > 27H

CHECK_LOW_OK:
    JC   UPDATE_OK  ; AMOUNT_LB < 0FH
    SJMP SET_ERROR  ; AMOUNT_LB > 0FH

;-----------------------------
; Error Handling Routine
;-----------------------------
SET_ERROR:
    SETB ERROR_FLAG
    ACALL SHOW_ERROR
    RET

;-----------------------------
; Display Update Routine
;-----------------------------
UPDATE_OK:
    ACALL UPDATE_DISPLAY
    RET

UPDATE_DISPLAY:
    ACALL DISPLAY_COUNTS_LABELS
    ACALL DISPLAY_COIN_COUNT
    RET

UPDATE_SUMMARY:
    ACALL DISPLAY_AMTS_LABELS
    ACALL DISPLAY_AMT_SUMMARY
    ACALL DELAY_1SEC
    ACALL UPDATE_DISPLAY
    RET

UPDATE_TOTAL:
    ACALL DISPLAY_TOTAL_AMT_LABELS
    ACALL DISPLAY_TOTAL_AMT
    ACALL DELAY_1SEC
    ACALL UPDATE_DISPLAY
    RET   

DISPLAY_COIN_COUNT:
    ; DISPLAY COIN 2 COUNT
    MOV R1, #0AH
    ACALL LCD_GOTO
    MOV R1, COUNT2_HB
    MOV R2, COUNT2_LB
    ACALL DISPLAY
    
    ; DISPLAY COIN 5 COUNT
    MOV R1, #4AH
    ACALL LCD_GOTO
    MOV R1, COUNT5_HB
    MOV R2, COUNT5_LB
    ACALL DISPLAY
    RET

DISPLAY_AMT_SUMMARY:
    ; DISPLAY COIN 2 AMT
    MOV R1, #0AH
    ACALL LCD_GOTO
    MOV R1, COIN2_AMT_HB
    MOV R2, COIN2_AMT_LB
    ACALL DISPLAY
    
    ; DISPLAY COIN 5 AMT
    MOV R1, #4AH
    ACALL LCD_GOTO
    MOV R1, COIN5_AMT_HB
    MOV R2, COIN5_AMT_LB
    ACALL DISPLAY
    RET
 
DISPLAY_TOTAL_AMT:
    ACALL CALCULATE_TOTAL_AMT
    MOV R1, #0AH
    ACALL LCD_GOTO
    MOV R1, TOTAL_HB
    MOV R2, TOTAL_LB
    ACALL DISPLAY
    RET

CALCULATE_TOTAL_AMT:
    MOV R0, COIN2_AMT_LB
    MOV R1, COIN2_AMT_HB
    MOV R2, COIN5_AMT_LB
    MOV R3, COIN5_AMT_HB
    ACALL ADD_TWO_16BIT_NUM
    MOV TOTAL_LB, R4
    MOV TOTAL_HB, R5
    RET

SHOW_ERROR:
    MOV  A, #01H         ; Clear display
    ACALL LCD_CMD
    MOV  DPTR, #MSG_ERROR_LINE1  ; Error message 1
    ACALL LCD_PRINT
    MOV  A, #0C0H        ; Second line
    ACALL LCD_CMD
    MOV  DPTR, #MSG_ERROR_LINE2  ; Error message 2
    ACALL LCD_PRINT
    RET

SHOW_WELCOME:
    MOV  A, #01H         ; Clear display
    ACALL LCD_CMD
    MOV  DPTR, #MSG_WELCOME_LINE1  ; Welcome line 1
    ACALL LCD_PRINT
    ACALL DELAY_50MS
    
    MOV  A, #0C0H        ; Second line
    ACALL LCD_CMD
    MOV  DPTR, #MSG_START  ; Welcome line 2
    ACALL LCD_PRINT
    ACALL DELAY_50MS
    RET

DISPLAY_COUNTS_LABELS:
    ; Show welcome message
    MOV A, #01H       ; Clear display
    ACALL LCD_CMD
    MOV  DPTR, #MSG_COUNT_COIN2
    ACALL LCD_PRINT
    
    MOV  A, #0C0H     ; Line 2 position
    ACALL LCD_CMD
    MOV  DPTR, #MSG_COUNT_COIN5
    ACALL LCD_PRINT
    ACALL DELAY_50MS
    RET

DISPLAY_TOTAL_AMT_LABELS:
    MOV A, #01H       ; Clear display
    ACALL LCD_CMD
    MOV  DPTR, #MSG_TOTAL_AMT
    ACALL LCD_PRINT
    RET

DISPLAY_AMTS_LABELS:
    ; Show welcome message
    MOV A, #01H       ; Clear display
    ACALL LCD_CMD
    MOV  DPTR, #MSG_AMT_COIN2
    ACALL LCD_PRINT
    
    MOV  A, #0C0H     ; Line 2 position
    ACALL LCD_CMD
    MOV  DPTR, #MSG_AMT_COIN5
    ACALL LCD_PRINT
    ACALL DELAY_50MS
    RET

DISPLAY_INSERT:
    MOV DPTR, #MSG_INSERT
    ACALL LCD_PRINT
    RET
DISPLAY:
    ACALL CONVERT_BIN_TO_DEC
    ACALL DISPLAY_DECIMAL
    RET

;-------------------------
; Converts 16-bit binary (COUNT_HB:COUNT_LB)
; to 5 ASCII digits (DIGIT1 to DIGIT5)
;-------------------------
DISPLAY_DECIMAL:
    ; Convert to ASCII and show DIGIT1
    MOV A, DIGIT1
    ADD A, #30H
    ACALL LCD_DATA

    MOV A, DIGIT2
    ADD A, #30H
    ACALL LCD_DATA

    MOV A, DIGIT3
    ADD A, #30H
    ACALL LCD_DATA

    MOV A, DIGIT4
    ADD A, #30H
    ACALL LCD_DATA

    MOV A, DIGIT5
    ADD A, #30H
    ACALL LCD_DATA
    RET

ADD_TWO_16BIT_NUM:       ; Input:  R0:R1 (low:high), R2:R3 (low:high)
                         ; Output: R4:R5 (low:high)
    ; Add lower bytes: R0 + R2
    MOV A, R0
    ADD A, R2
    MOV R4, A            ; Store lower byte result in R4

    ; Add upper bytes with carry: R1 + R3 + CY
    MOV A, R1
    ADDC A, R3
    MOV R5, A            ; Store upper byte result in R5
    RET
     
;-----------------------------------------
; Convert binary to decimal digits (R1 HB, R2 LB)
;-----------------------------------------
CONVERT_BIN_TO_DEC:
    ACALL Hex2BCD
    MOV DIGIT5, R3      ; BCD digit 1 (least significant digit)
    MOV DIGIT4, R4      ; BCD digit 2
    MOV DIGIT3, R5      ; BCD digit 3
    MOV DIGIT2, R6      ; BCD digit 4
    MOV DIGIT1, R7      ; BCD digit 5 (most significant digit)
    RET
    
Hex2BCD:
    ; Initialize registers
    MOV R3, #0         ; BCD digit 1 (least significant digit)
    MOV R4, #0         ; BCD digit 2
    MOV R5, #0         ; BCD digit 3
    MOV R6, #0         ; BCD digit 4
    MOV R7, #0         ; BCD digit 5 (most significant digit)

    MOV B, #10         ; Divider 10 for DIV AB

    MOV A, R2          ; Load low byte into A
    DIV AB             ; Divide A by B (10)
    MOV R3, B          ; R3 = remainder (units digit)
    
    MOV B, #10
    DIV AB             ; Divide quotient by 10 again
    MOV R4, B          ; R4 = next digit (tens)
    MOV R5, A          ; R5 = quotient (hundreds and above)

    CJNE R1, #0, HIGH_BYTE_CHECK
    SJMP DONE

HIGH_BYTE_CHECK:
    MOV A, #6          ; Prepare to add corrections for high byte
    ADD A, R3
    MOV B, #10
    DIV AB             ; Divide by 10
    MOV R3, B          ; Store updated remainder in R3

    ADD A, R4
    ADD A, #5          ; Add 5 for BCD correction
    MOV B, #10
    DIV AB
    MOV R4, B

    ADD A, R5
    ADD A, #2
    MOV B, #10
    DIV AB
    MOV R5, B

    CJNE R6, #0, ADD_IT
    SJMP CONTINUE

ADD_IT:
    ADD A, R6

CONTINUE:
    MOV R6, A

    DJNZ R1, HIGH_BYTE_CHECK

    MOV B, #10
    MOV A, R6
    DIV AB
    MOV R6, B
    MOV R7, A

DONE:
    ; End of conversion - R7 to R3 now holds BCD digits (MSD to LSD)
    RET
;-----------------------------------------
; LCD Control Functions
;-----------------------------------------
LCD_CMD:
    ; Send a command to the LCD
    ACALL LCD_busy
    MOV DATA_LINE, A
    CLR RS            ; RS=0 (Command mode)
    CLR RW            ; RW=0 (Write mode)
    SETB EN           ; Generate enable pulse
    CLR EN
    RET

LCD_DATA:
    ; Send data to the LCD
    ACALL LCD_busy
    MOV DATA_LINE, A
    SETB RS           ; RS=1 (Data mode)
    CLR RW            ; RW=0 (Write mode)
    SETB EN           ; Generate enable pulse
    CLR EN
    RET

LCD_INIT:
    ; Initialize the LCD in 8-bit mode with cursor settings
    MOV A, #38H       ; 8-bit data, 2 lines, 5x7 font
    ACALL LCD_CMD
    MOV A, #0EH       ; Display ON, cursor ON
    ACALL LCD_CMD
    MOV A, #01H       ; Clear the display
    ACALL LCD_CMD
    MOV A, #06H       ; Increment cursor, no shift
    ACALL LCD_CMD
    MOV A, #80H       ; Move cursor to the first position
    ACALL LCD_CMD
    RET

LCD_busy:
    ; Check if the LCD is busy (wait until not busy)
    SETB P2.7         ; Set DB7 as input (busy flag)
    SETB EN           ; Enable LCD for read
    CLR RS            ; RS=0 (Command mode)
    SETB RW           ; RW=1 (Read mode)
    
Check_Busy:
    CLR EN            ; Clear enable to latch data
    SETB EN           ; Set enable again
    JB P2.7, Check_Busy ; Repeat if DB7 is high (busy)
    RET
    
LCD_GOTO:
    ; Move cursor to the specified position
    MOV A, R1         ; Load desired position
    ORL A, #80H       ; Convert to LCD address
    ACALL LCD_CMD
    RET

LCD_PRINT:
    ; Display null-terminated string from DPTR
    PUSH ACC
    
NEXT_CHAR:
    CLR  A
    MOVC A, @A+DPTR
    JZ   END_STRING
    ACALL LCD_DATA
    INC  DPTR
    SJMP NEXT_CHAR
    
END_STRING:
    POP  ACC
    RET

LCD_CLEAR:
    MOV A, #01H
    ACALL LCD_CMD
    RET

;-----------------------------------------
; Utility Functions
;-----------------------------------------
DEBOUNCE:
    MOV  R6, #20           ; Increased debounce time
DEBOUNCE_LOOP:
    DJNZ R6, DEBOUNCE_LOOP
    RET

DELAY_20MS:
    MOV  R5, #40
DELAY_20MS_LOOP:
    ACALL DELAY_500US
    DJNZ R5, DELAY_20MS_LOOP
    RET

DELAY_1SEC:
    MOV  R4, #20
DELAY_1SEC_LOOP:
    ACALL DELAY_50MS
    DJNZ R4, DELAY_1SEC_LOOP
    RET

DELAY_50MS:
    MOV  R5, #100
DELAY_50MS_LOOP:
    ACALL DELAY_500US
    DJNZ R5, DELAY_50MS_LOOP
    RET

DELAY_500US:
    MOV  R6, #250
    DJNZ R6, $
    RET

DELAY: 
    ; Generates a delay loop
    ; R5 controls the number of outer loops
    ; R4 controls the number of inner loops
    MOV R5, #100         ; Set the outer loop counter (adjust for delay tuning)
    
Outer:
    MOV R4, #255         ; Set the inner loop counter
    
Inner:
    DJNZ R4, Inner       ; Decrement R4 until it reaches zero
    DJNZ R5, Outer       ; Decrement R5 and repeat the outer loop
    RET 


;---------------------------------------------------
; Messages
;---------------------------------------------------
MSG_COUNT_COIN2:     DB '2 COUNT: ', 0
MSG_COUNT_COIN5:     DB '5 COUNT: ', 0
MSG_AMT_COIN2:       DB '2 AMT:   ', 0
MSG_AMT_COIN5:       DB '5 AMT:   ', 0
MSG_TOTAL_AMT:       DB 'TOTAL AMT:', 0
MSG_ERROR_LINE1:     DB 'MAX REACHED! ', 0
MSG_ERROR_LINE2:     DB 'PRESS RESET  ', 0
MSG_WELCOME_LINE1:   DB '  Coin Counter ', 0
MSG_START:           DB '     START     ', 0
MSG_INSERT:          DB ' Insert Coins ', 0

;=========================
; End of Code
;=========================
END