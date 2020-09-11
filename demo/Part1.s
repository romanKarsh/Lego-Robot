.section .exceptions, "ax"
interrupt_handler:
    addi sp, sp, -16
    stw r8, 0(sp)
    stw r9, 4(sp)
    stw r10, 8(sp)
    stw ra, 12(sp)
    
    # which device caused the interrupt?
    rdctl et, ctl4
    andi r8, et, 0x800 # sensors use IRQ 11
    bne r8, r0, sensor
    andi r8, et, 0x2 # buttons use IRQ 1
    bne r8, r0, button_press
    andi r8, et, 0x1
    bne r8, r0, clock0 # clock uses IRQ0
    andi r8, et, 0x80
    bne r8, r0, keyboard_press # keyboard uses IRQ 7
    br exit_interrupt_handler
    
    
    
keyboard_press:
    movia et, keyboard
    ldwio r8, 0(et)
    andi r8, r8, 0xff
    movi r9, 0xF0
    beq r9, r8, key_release
    movi r9, 0x1D
    beq r9, r8, w_press
    movi r9, 0x1B
    beq r9, r8, s_press
    movi r9, 0x1C
    beq r9, r8, a_press
    movi r9, 0x23
    beq r9, r8, d_press
    movi r9, 0x29
    beq r9, r8, space_press
    movi r9, 0x5A
    beq r9, r8, enter_press
    movi r9, 0x41
    beq r9, r8, comma_press
    movi r9, 0x49
    beq r9, r8, period_press
    movi r9, 0x2B
    beq r9, r8, f_press
    br exit_interrupt_handler
    
key_release:
    movia et, state
    movi r8, 1
    stw r8, 16(et)
    br exit_interrupt_handler
    
w_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    ldw r10, 8(et) # first check if forward motion is allowed
    bne r0, r10, exit_interrupt_handler
    movi r8, 1 # set track state to forward motion
    stw r8, 0(et)
    br exit_interrupt_handler
    
s_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    ldw r10, 12(et) # first check if backward motion is allowed
    bne r0, r10, exit_interrupt_handler
    movi r8, 2 # set track state to backward motion
    stw r8, 0(et)
    br exit_interrupt_handler
    
a_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    ldw r8, 8(et)
    ldw r9, 12(et)
    or r9, r9, r8
    bne r9, r0, exit_interrupt_handler # if one direction of motion is not allowed, cant turn
    movi r8, 3
    stw r8, 0(et)
    br exit_interrupt_handler
    
d_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    ldw r8, 8(et)
    ldw r9, 12(et)
    or r9, r9, r8
    bne r9, r0, exit_interrupt_handler # if one direction of motion is not allowed, cant turn
    movi r8, 4
    stw r8, 0(et)
    br exit_interrupt_handler
    
f_press:
    movia r9, JP2
    ldwio et, 0(r9)
    movia r10, 0xFFFFFFeF # turn motor 2 on (fire motor)
    and et, et, r10
    stwio et, 0(r9)
    br exit_interrupt_handler
    
space_press:
    movia et, state
    stw r0, 0(et)
    stw r0, 4(et)
    stw r0, 16(et)
    br exit_interrupt_handler
    
enter_press:
    movia et, state
    movia et, leds
    ldwio r9, 0(et)
    movi r10, 0b1111111
    bne r10, r9, exit_interrupt_handler
    # aim time is full
    stwio r0, 0(et)
    
    movia r9, JP2
    ldwio et, 0(r9)
    movia r10, 0xFFFFFFeF # turn motor 2 on (fire motor)
    and et, et, r10
    stwio et, 0(r9)
    br exit_interrupt_handler
    
comma_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    movi r8, 1
    stw r8, 4(et)
    br exit_interrupt_handler
    
period_press:
    movia et, state
    ldw r10, 16(et)
    bgt r10, r0, space_press
    movi r8, 2
    stw r8, 4(et)
    br exit_interrupt_handler
    
    
    
clock0:
    movia et, state
    ldw r9, 8(et)
    beq r0, r9, check_back # forward motion was clear
    # check if forward obstacle clear now
    movia r8, JP2
    ldwio r9, 0(r8)
    andhi r9, r9, 0x8000
    bne r0, r9, forward_cleared
    br check_back # foward motion was now allowed and still not allowed
forward_cleared:
    # clear forward motion not allowed flag
    stw r0, 8(et)
    
    # set HEX0 to O (leave HEX1 unchanged)
    movia r8, seg_display
    ldwio r9, 0(r8)
    andi r9, r9, 0b111111110111111
    ori r9, r9, 0b0111111
    stwio r9, 0(r8)
    
    # set track state to stationary
    stw r0, 0(et)
    
    # re - enable keyboard and button interrupts
    movi r9, 0x883
    # accept interrupts from IRQ1 (push buttons) IRQ7 (PS2), IRQ0 (timer 1) and IRQ11 (JP1)
    wrctl ctl3, r9
check_back:
    ldw r9, 12(et)
    beq r0, r9, both_checked # backward motion was clear
    # check if backward obstacle clear now
    movia r8, JP2
    ldwio r9, 0(r8)
    andhi r9, r9, 0x4000
    bne r0, r9, backward_cleared
    br both_checked # backward motion was now allowed and still not allowed
backward_cleared:
    # clear backward motion not allowed flag
    stw r0, 12(et)
    
    # set HEX1 to O (leave HEX0 unchanged)
    movia r8, seg_display
    ldwio r9, 0(r8)
    andi r9, r9, 0b011111111111111
    ori r9, r9, 0b011111100000000
    stwio r9, 0(r8)
    
    # set track state to stationary
    stw r0, 0(et)
    
    # re - enable keyboard and button interrupts
    movi r9, 0x883
    # accept interrupts from IRQ1 (push buttons) IRQ7 (PS2), IRQ0 (timer 1) and IRQ11 (JP1)
    wrctl ctl3, r9
both_checked:
    movia r9, JP2
    ldwio et, 0(r9) # turn motor 2 off (shooting motor)
    ori et, et, 0b10000
    stwio et, 0(r9)
    
    movia et, state
    ldw r8, 0(et)
    bne r0, r8, doneClock
    ldw r8, 4(et)
    bne r0, r8, doneClock
    movia et, leds
    ldwio r9, 0(et)
    movi r10, 0b1111111
    beq r10, r9, doneClock
    slli r9, r9, 1
    addi r9, r9, 1
    stwio r9, 0(et)
doneClock:
    movia et, TIMER0_BASE
    sthio r0, TIMER0_STATUS(et) # acknowledge interrupt
    call start_timer_once
    br exit_interrupt_handler
    
    
    
    
sensor:
    movia r8, JP2 # check edge capture register from GPIO JP2
    ldwio et, 12(r8)
    andhi r9, et, 0x8000
    bne r0, r9, front_sensor4
    andhi r9, et, 0x4000
    bne r0, r9, back_sensor3
    br exit_interrupt_handler
    
front_sensor4: # there is an obstacle infront
    movia r9, state
    movi et, 1
    stw et, 8(r9) # set the flag that indicates foward motion is not allowed
    
    # set HEX0 to X (leave HEX1 unchanged)
    movia r10, seg_display
    ldwio et, 0(r10)
    andi et, et, 0b111111111110110
    ori et, et, 0b1110110
    stwio et, 0(r10)
    
    # check if backward motion is allowed
    ldw et, 12(r9)
    bne r0, et, boxed_in4 # backward motion might also not be allowed already
    movi et, 2
    stw et, 0(r9) # set motion to reverse
    
    # disable interrupts for keyboard, buttons
    movi et, 0x801
    # accept interrupts only from IRQ0 (timer 1) and IRQ11 (JP1)
    wrctl ctl3, et
    br clear_sensor4
boxed_in4:
    stw r0, 0(r9) # set motion to stationary
clear_sensor4:
    movia et, 0xBFFFFFFF # clear sensor 4
    stwio et, 12(r8)
    
    br exit_interrupt_handler
    
back_sensor3: # there is an obstacle behind
    movia r9, state
    movi et, 1
    stw et, 12(r9) # set the flag that indicates back motion is not allowed
    
    # set HEX1 to X (leave HEX0 unchanged)
    movia r10, seg_display
    ldwio et, 0(r10)
    andi et, et, 0b111011011111111
    ori et, et, 0b111011000000000
    stwio et, 0(r10)
    
    # check if forward motion is allowed
    ldw et, 8(r9)
    bne r0, et, boxed_in3 # forward motion might also not be allowed already
    movi et, 1
    stw et, 0(r9) # set motion to forward
    
    # disable interrupts for keyboard, buttons
    movi et, 0x801
    # accept interrupts only from IRQ0 (timer 1) and IRQ11 (JP1)
    wrctl ctl3, et
    br clear_sensor3
boxed_in3:
    stw r0, 0(r9) # set motion to stationary
clear_sensor3:
    movia et, 0x7FFFFFFF # clear sensor 3
    stwio et, 12(r8)
    br exit_interrupt_handler
    
    
    
    
button_press:
    # which button caused interrupt?
    movia r9, JP2
    movia et, buttons
    ldwio r8, 12(et)
    movi et, 0x1
    and et, et, r8
    bne r0, et, button0
    movi et, 0x2
    and et, et, r8
    bne r0, et, button1
    movi et, 0x4
    and et, et, r8
    bne r0, et, button2
    movi et, 0x8
    and et, et, r8
    bne r0, et, button3
    
    # handle interrupt from that device.
button0: # forward
    movia et, state
    ldw r10, 8(et) # first check if forward motion is allowed
    bne r0, r10, doneButtons
    movi r8, 1 # set track state to forward motion
    stw r8, 0(et)
    
    movi r8, 0x1 # holds input to clear the button interrupt
    br doneButtons
button1: # reverse
    movia et, state
    ldw r10, 12(et) # first check if backward motion is allowed
    bne r0, r10, doneButtons
    movi r8, 2 # set track state to backward motion
    stw r8, 0(et)
    
    movi r8, 0x2 # holds input to clear the button interrupt
    br doneButtons
button2: # stop
    movia et, state
    stw r0, 0(et)
    stw r0, 4(et)
    
    movi r8, 0x4
    br doneButtons
button3: # shoot
    movi r8, 0x8
    movia et, state
    ldw r9, 0(et)
    bne r0, r9, doneButtons # state is 0 (stationary)
    movia et, leds
    ldwio r9, 0(et)
    movi r10, 0b1111111
    bne r10, r9, doneButtons
    # aim time is full
    stwio r0, 0(et)
    
    movia r9, JP2
    ldwio et, 0(r9)
    movia r10, 0xFFFFFFeF # turn motor 2 on (fire motor)
    and et, et, r10
    stwio et, 0(r9)
    
    br doneButtons
    
doneButtons:
    # acknowledge interrupt is handled.
    movia et, buttons # r8 has corresponding button bit high
    stwio r8, 12(et)
    br exit_interrupt_handler
    
exit_interrupt_handler:
    ldw r8, 0(sp)
    ldw r9, 4(sp)
    ldw r10, 8(sp)
    ldw ra, 12(sp)
    addi sp, sp, 16
    subi ea, ea, 4
    eret
    
.equ seg_display, 0xFF200020
.equ leds, 0xFF200000
.equ buttons, 0xFF200050
.equ JP2, 0xFF200060
.equ keyboard, 0xFF200100
.equ motor_off_time, 0x7FFF
.equ TIMER0_BASE, 0xFF202000
.equ TIMER0_STATUS, 0
.equ TIMER0_CONTROL, 4
.equ TIMER0_PERIODL, 8
.equ TIMER0_PERIODH, 12
.equ TIMER0_SNAPL, 16
.equ TIMER0_SNAPH, 20
.equ TICKS_PER_SEC, 100000000

.global _start
_start:
    movia sp, 0x0007FFFC
    movia r17, buttons
    movi r16, 0xF
    stwio r16, 8(r17) # enable interrupts on button 0, 1, 2 and 3
    stwio r16, 12(r17) # clear register (so theres no unexpected interrupts)
    
    movia r17, leds
    stwio r0, 0(r17)
    
    movia r17, seg_display
    movi r16, 0b11111100111111 # set HEX0 and HEX1 to O O
    #movi r16, 0b111011001110110 # set HEX0 and HEX1 to X X
    stwio r16, 0(r17)
    
    movia r17, keyboard # enable interuppts on keyboard
    movi r16, 0x1
    stwio r16, 4(r17)
    
    movia r17, JP2
    movia r16, 0x07F557FF # set direction for motors and sensors to output and sensor data register to inputs
    stwio r16, 4(r17)
    # load sensor3 threshold value 4 and enable sensor3
    movia r16, 0xFd3eFFFF # set motors off enable threshold load sensor 3
    stwio r16, 0(r17) # store value into threshold register
    movia r16, 0xFa7FFFFF # disable sensors for loading
    stwio r16, 0(r17)
    # load sensor4 threshold value 4 and enable sensor4
    movia r16, 0xFd3bFFFF # set motors off enable threshold load sensor 4
    stwio r16, 0(r17) # store value into threshold register
    movia r16, 0xFa5FFFFF # keep threshold value same in case update occurs before state mode is enabled
    stwio r16, 0(r17)
    movia r16, 0xC0000000 # enable interrupts on sensor 3 and 4
    stwio r16, 8(r17)
    movia r16, 0xFFFFFFFF
    stwio r16, 12(r17)
    
    call initialize_timer
    call start_timer_once
    
    movi r16, 0x883
    # accept interrupts from IRQ1 (push buttons) IRQ7 (PS2), IRQ0 (timer 1) and IRQ11 (JP1)
    wrctl ctl3, r16
    movi r16, 0x1
    wrctl ctl0, r16 # enable interrupts globaly
    
main_loop:
    movia r20, state
    ldw r21, 0(r20) # the state of the track motors
    ldw r22, 4(r20) # the state of the turret motor
    movia r16, motor_off_time
    call turnoff_track
    call turnoff_turret
delay:
    subi r16, r16, 1
    ldw r17, 0(r20)
    bne r21, r17, change_montion # exit early if state of track motors changed while in the off period of motion
    ldw r17, 4(r20)
    bne r22, r17, change_montion # exit early if state of turret motor changed while in the off period of this motion
    bne r0, r16, delay
change_montion:
    ldw r21, 0(r20)
    ldw r22, 4(r20)
    beq r22, r0, turr_off
    # current state is not 0, moving turret
    movia r17, leds
    stwio r0, 0(r17)
    movi r16, 1
    beq r22, r16, turr_left
turr_right: # we know turret state is not 0 or 1, so must be 2
    call turn_turr_right
    br done_turr
turr_left:
    call turn_turr_left
    br done_turr
turr_off:
    beq r0, r21, main_loop # if both turr and track are off, go back to main off loop
    call turnoff_turret
    
done_turr:
    
    beq r0, r21, track_off
    # current state is not 0, moving tracks
    movia r17, leds
    stwio r0, 0(r17)
    movi r16, 1
    beq r21, r16, track_forw
    movi r16, 2
    beq r21, r16, track_rev
    movi r16, 3
    beq r21, r16, track_left
    movi r16, 4
    beq r21, r16, track_right
    
track_forw:
    call turnon_forward
    br done_track
track_rev:
    call turnon_reverse
    br done_track
track_left:
    call turnon_left
    br done_track
track_right:
    call turnon_right
    br done_track
track_off:
    call turnoff_track
    
done_track:
    movia r18, motor_off_time
delay2: # loop to wait as motor is on
    ldw r17, 0(r20)
    bne r21, r17, change_montion # exit early if state of track motors changed while in this motion
    ldw r17, 4(r20)
    bne r22, r17, change_montion # exit early if state of turret motor changed while in this motion
    subi r18, r18, 1
    bne r0, r18, delay2
    br main_loop
    ret
    
    
/* - - - - - - - - - - - - USEFUL FUNCTIONS - - - - - - - - - - - - */ 
    
turnon_forward:
    movia r9, JP2
    # must turn both motors on and set motor 0 to reverse and motor 1 to forward
    ldwio r8, 0(r9)
    ori r8, r8, 0b10 # set motor 0 to reverse
    movia r10, 0xFFFFFFF2# turn both motors on and set motor 1 to forward
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
turnon_reverse:
    movia r9, JP2
    # must turn both motors on and set motor 0 to forward and motor 1 to reverse
    ldwio r8, 0(r9)
    ori r8, r8, 0b1000 # set motor 1 to reverse
    movia r10, 0xFFFFFFF8# turn both motors on and set motor 0 to forward
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
turnon_right:
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b1010 # set both motors on
    movia r10, 0xFFFFFFFA # turn both motors on and set both in reverse
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
turnon_left:
    movia r9, JP2
    ldwio r8, 0(r9)
    movia r10, 0xFFFFFFF0 # set both motors on and set to forward
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
turnoff_track:
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b101 # turn off motor 0 and 1 (track)
    stwio r8, 0(r9)
    ret
    
turnoff_turret:
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b1000000 # turn off motor 3 (turret)
    stwio r8, 0(r9)
    ret
    
turn_turr_left:
    movia r9, JP2
    ldwio r8, 0(r9)
    movia r10, 0xFFFFFF3F # set motor 3 on and set to forward
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
turn_turr_right:
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b10000000
    movia r10, 0xFFFFFFBF # set motor 3 on and set to reverse
    and r8, r8, r10
    stwio r8, 0(r9)
    ret
    
initialize_timer:
    movia r8, TIMER0_BASE
    
    # Lower 16 bits
    addi r9, r0, %lo(TICKS_PER_SEC)
    stwio r9, TIMER0_PERIODL(r8)
    
    # Upper 16 bits
    addi r9, r0, %hi(TICKS_PER_SEC)
    stwio r9, TIMER0_PERIODH(r8)
    ret
    
start_timer_once:
    movia r8, TIMER0_BASE
    # 5 means bit 2 and bit 0 is high
    movi r9, 0x5
    # Bit 2 is the control register's "start" bit.
    # By writing 1 at Bit 2, we start the timer.
    # This also sets Bit 1 to 0, which means the timer will run once.
    # Bit 0 is interrupt enable for timeouts
    stwio r9, TIMER0_CONTROL(r8)
    ret
    
.data
state:
.word 0 # state of the tracks motion
.word 0 # state of the turret motion
.word 0 # forward motion collision
.word 0 # backward motion collision
    
    
    
    
