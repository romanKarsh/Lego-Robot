.section .exceptions,"ax"
interrupt_handler:
    addi sp, sp, -16
    stw r8, 0(sp)
    stw r9, 4(sp)
    stw r10, 8(sp)
    stw ra, 12(sp)
    
    # which device caused the interrupt?
    rdctl et, ctl4
    andi r8, et, 0x2 # Buttons use IRQ 1
    bne r8, r0, button_press
    andi r8, et, 0x1 
    bne r8, r0, clock0 # clock uses IRQ1
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
    br exit_interrupt_handler
    
key_release:
	# key release, so guranteed there is another byte to read
	ldwio r8, 0(et)
    andi r8, r8, 0xff
    movi r9, 0x1D
    beq r9, r8, wORs_release
    movi r9, 0x1B
    beq r9, r8, wORs_release
    br exit_interrupt_handler
    
wORs_release:
	movia et, state
    stw r0, 0(et)
    
    # must turn mottor 0 and 1 off, also not change anything else
    movia r9, JP2
    ldwio  r8, 0(r9) 
    ori r8, r8, 0b101
    stwio  r8, 0(r9) 
    br exit_interrupt_handler

w_press:
	movia et, state
    movi r8, 1
    stw r8, 0(et)
   	call turnon_forward
    br exit_interrupt_handler

s_press:
	movia et, state
    movi r8, 2
    stw r8, 0(et)
	call turnon_reverse
    br exit_interrupt_handler
      
a_press:
	movia et, state
    movi r8, 3
    stw r8, 0(et)
    
    # must turn both motors on and set motor 0 to forward and motor 1 to reverse
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b0000 	# set both motors forward
    movia et, 0xFFFFFFF0 # turn both motors on and set both forward
    and r8, r8, et
    stwio  r8, 0(r9) 
    br exit_interrupt_handler
    
d_press:
	movia et, state
    movi r8, 4
    stw r8, 0(et)
    
    # must turn both motors on and set motor 0 to forward and motor 1 to reverse
    movia r9, JP2
    ldwio r8, 0(r9)
    ori r8, r8, 0b1010 	# set both motors forward
    movia et, 0xFFFFFFFA # turn both motors on and set both in reverse
    and r8, r8, et
    stwio  r8, 0(r9) 
    br exit_interrupt_handler
  
space_press:
    movia et, state
    movi r8, 2
    stw r8, 0(et)
    
    # must turn both motors on and set motor 0 to forward and motor 1 to reverse
    movia r9, JP2    
    ldwio  r8, 0(r9) 
    ori r8, r8, 0b101
    stwio  r8, 0(r9) 
    br exit_interrupt_handler
    
    
clock0:
	movia et, state
    ldw r8, 0(et)
    bne r0, r8, reset_aim
	movia et, leds
    ldwio r9, 0(et)
    movi r10, 0b1111111
    beq r10, r9, doneClock
    slli r9, r9, 1
    addi r9, r9, 1
    stwio r9, 0(et)    
doneClock:
	movia et, TIMER0_BASE
    sthio r0, TIMER0_STATUS(et)
    call start_timer_once
    br exit_interrupt_handler
    
reset_aim:
	movia et, leds
    stwio r0, 0(et)
    br doneClock
    
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
    movi r8, 1
    stw r8, 0(et)
    movi r8, 0x1  # holds input to clear the button interrupt
    br doneButtons
button1: # reverse
    movia et, state
    movi r8, 2
    stw r8, 0(et)
    movi r8, 0x2 # holds input to clear the button interrupt
    br doneButtons
button2: # stop
    movia et, state
    stw r0, 0(et)
    movi r8, 0x4
    br doneButtons
  
button3: # shoot
	movi r8, 0x8
    movia et, state
    ldw r9, 0(et)
    bne r0, r9, doneButtons
    # state is 0 (stationary)
    movia et, leds
    ldwio r9, 0(et)
    movi r10, 0b1111111
    bne r10, r9, doneButtons
    # aim time is full
  	stwio r0, 0(et)
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
   
.equ leds, 0xFF200000
.equ buttons, 0xFF200050
.equ JP2, 0xFF200060
.equ keyboard, 0xFF200100
.equ TIMER0_BASE, 0xFF202000
.equ TIMER0_STATUS, 0
.equ TIMER0_CONTROL, 4
.equ TIMER0_PERIODL, 8
.equ TIMER0_PERIODH, 12
.equ TIMER0_SNAPL, 16
.equ TIMER0_SNAPH, 20
.equ TICKS_PER_SEC, 100000

.global _start
_start:
	movia sp, 0x0007FFFC
    movia r17, buttons
	movi r16, 0x1
    wrctl ctl0, r16 # enable interrupts globaly
    movi r16, 0xF
    stwio r16, 8(r17) # enable interrupts on button 0, 1 and 2
    stwio r16, 12(r17) # clear register (so theres no unexpected interrupts
    movi r16, 0x83
    wrctl ctl3, r16 # accept interrupts from IRQ1 (push buttons) IRQ7 (PS2) and IRQ0
    
    movia r17, keyboard
    movi r16, 0x1
    stwio r16, 4(r17)
    
    movia r17, JP2
    movia  r16, 0x07f557ff  # set direction for motors and sensors to output and sensor data register to inputs
    stwio  r16, 4(r17)
    movi r16, -1
    stwio r16, 0(r17)
    call initialize_timer
    call start_timer_once
    
loop:
    movi r16, 0x0007
    call turnoff
delay:
	subi r16, r16, 1
    bne r0, r16, delay
    
    movia r16, state
    ldw r17, 0(r16)
    beq r0, r17, loop
    # current state is not 0
    movi r18, 0x0007
    movi r16, 1
    beq r17, r16, forw
    movi r16, 2
    beq r17, r16, rev
    
forw:
 	call turnon_forward
    br delay2
rev:
	call turnon_reverse
	br delay2
    
delay2:
	subi r18, r18, 1
    bne r0, r18, delay2
    br loop
    ret
    
    






turnon_forward:
	movia r9, JP2
    # must turn both motors on and set motor 0 to reverse and motor 1 to forward
	ldwio r8, 0(r9)		
    ori r8, r8, 0b10	# set motor 0 to reverse
   	movia r10, 0xFFFFFFF2# turn both motors on and set motor 1 to forward
    and r8, r8, r10
    stwio  r8, 0(r9)
    ret

turnon_reverse:
	movia r9, JP2
	# must turn both motors on and set motor 0 to forward and motor 1 to reverse
    ldwio r8, 0(r9)
    ori r8, r8, 0b1000 	# set motor 1 to reverse
    movia r10, 0xFFFFFFF8# turn both motors on and set motor 0 to forward
    and r8, r8, r10
    stwio  r8, 0(r9) 
    ret
	
turnoff:
	movia r9, JP2    
    ldwio  r8, 0(r9) 
    ori r8, r8, 0b101
    stwio  r8, 0(r9) 
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
	# 4 means bit 2 is high
    movi r9, 0x5
    # Bit 2 is the control register's "start" bit.
    # By writing 1 at Bit 2, we start the timer.
    # This also sets Bit 1 to 0, which means the timer will run once.
    stwio r9, TIMER0_CONTROL(r8)
    ret    
    
.data
state:
.word 0
  

    
