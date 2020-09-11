.data
state:
.word 0	# 1 for forward, 2 for reverse and 0 for stationary

.text

.equ leds, 0xFF200000
.equ buttons, 0xFF200050
.equ JP1, 0xFF200060

.global _start
_start:
	movia sp, 0x0007FFFC
    movia r17, buttons
	movi r16, 0x1
    wrctl ctl0, r16 # enable interrupts globaly
    movi r16, 0x7
    stwio r16, 8(r17) # enable interrupts on button 0, 1 and 2
    stwio r16, 12(r17) # clear register (so theres no unexpected interrupts
    movi r16, 0x2
    wrctl ctl3, r16 # accept interrupts from IRQ 1 (push buttons)
    
    movia r17, JP1
    movia  r16, 0x07f557ff  # set direction for motors and sensors to output and sensor data register to inputs
    stwio  r16, 4(r17)
    movi r16, -1
    stwio r16, 0(r17)
loop:
	movia r16, 0x11
    br loop
    ret
    
.section .exceptions,"ax"
interrupt_handler:
    addi sp, sp, -12
    stw r8, 0(sp)
    stw r9, 4(sp)
    stw ra, 8(sp)
    
    # which device caused the interrupt? Buttons use IRQ 1
    rdctl et, ctl4
    andi et, et, 0x2
    beq et, r0, exit_interrupt_handler
    
    # which button caused interrupt?
    movia r9, JP1
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
    
	# handle interrupt from that device.
button0:
    movia et, state
    movi r8, 1
    stw r8, 0(et)
    # must turn both motors on and set motor 0 to reverse and motor 1 to forward
    ldwio r8, 0(r9)		
    ori r8, r8, 0b10	# set motor 0 to reverse
   	movia et, 0xFFFFFFF2# turn both motors on and set motor 1 to forward
    and r8, r8, et
    stwio  r8, 0(r9)
    movi r8, 0x1  # holds input to clear the button interrupt
    br doneButtons
button1:
    movia et, state
    movi r8, 2
    stw r8, 0(et)
    # must turn both motors on and set motor 0 to forward and motor 1 to reverse
    ldwio r8, 0(r9)
    ori r8, r8, 0b1000 	# set motor 1 to reverse
    movia et, 0xFFFFFFF8# turn both motors on and set motor 0 to forward
    and r8, r8, et
    stwio  r8, 0(r9) 
    movi r8, 0x2 # holds input to clear the button interrupt
    br doneButtons
button2:
    movia et, state
    stw r0, 0(et)
    # must turn mottor 0 and 1 off, also not change anything else
    ldwio  r8, 0(r9) 
    ori r8, r8, 0b101
    stwio  r8, 0(r9) 
    
    movi r8, 0x4
    br doneButtons
    
doneButtons:
 	# acknowledge interrupt is handled.
	movia et, buttons # r8 has corresponding button bit high
    stwio r8, 12(et)
    br exit_interrupt_handler
    
exit_interrupt_handler:
    ldw r8, 0(sp)
    ldw r9, 4(sp)
    ldw ra, 8(sp)
    addi sp, sp, 12
	subi ea, ea, 4
	eret
    