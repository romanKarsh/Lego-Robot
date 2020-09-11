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
    movia et, leds
    ldwio r8, 0(et)
    xori r8, r8, 0x1
    stwio r8, 0(et)
    # must turn mottor on (reverse), also not change anything else
    ldwio r8, 0(r9)		
    ori r8, r8, 0b1010	# set motor 0 and 1 to reverse 
   	movia et, 0xFFFFFFFA
    and r8, r8, et		# turn motor 0 and 1 on
    stwio  r8, 0(r9)
    
    movi r8, 0x1
    br doneButtons
button1:
	movia et, leds
    ldwio r8, 0(et)
    xori r8, r8, 0x2
    stwio r8, 0(et)
    # turn mottors 1 and 0 on (forward), also not change anything else
    ldwio r8, 0(r9)
    movia et, 0xFFFFFFF0
    and r8, r8, et	# set bits 0, 1, 2 and 3 all to 0
    stwio  r8, 0(r9) 
    
    movi r8, 0x2
    br doneButtons
button2:
    movia et, leds
    stwio r0, 0(et)
        
    stwio  r8, 0(r9) 
    ori r8, r8, 0b101   # turn mottor 0 and 1 off, also not change anything else
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
    