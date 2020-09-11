# Keyboard Controlled Robot

Created as a final project for Microprocessors course at the University of Toronto. It is a keyboard-controlled robot, coded entirely in Nios II Assembly. Features include collision-avoidance through the use of light sensors on the front and back, a rotating shooting turret and visual display of state via LEDs and HEX displays.

## Code and Demo
The final code version is in the demo folder.  
https://drive.google.com/file/d/15z9ByuxF2Qa90OXm8oapNsczMkgfoRPU/view?usp=sharing

## Devices/Components used 
- Lego motors
- LED
- 7 segment display
- Push buttons
- Timer
- Light sensors
- PS/2 keyboard.

## How to move the Robot
Option 1: Using Push buttons

To move forward : Push down button0  
To move backwards : Push down button1  
To stop : Push down button2  

Option 2: Using the Keyboard

To move forward: Press 'w' Key  
To move backwards: Press 's' Key  
To turn left: Press 'a' Key  
To turn right: Press 'd' Key  
To stop: 'Spacebar'

## How to use the turret 

Turn turret to left: Press ',' Key  
Turn turret to right: Press '.' Key  
To stop turret: 'Spacebar'  
Shoot turret: Press 'Enter' or alternatively Push down button3

Note that the robot must remain stationary for 7 seconds in order to aim its turret. For each second it is stationary, an additional LED light will light up. Moving will cause all LED lights to turn off and reset the aim. Once you see 7 LED lights, the turret is ready to shoot. 

## Implementation Details

#### How does it work? 

The sensors, clock, buttons and keyboard all trigger interrupts which run the interrupt handler. For the most part the interrupt handler sets global state variables but doesn't set the motion of any motors.  
There are 4 global state variables:  
1. state of the tracks motion, has one of five values (0: turn off, 1: forward , 2: reverse, 3: left, 4: right)  
2. state of the turret motion, has one of three values (0: turn off , 1: left, 2: right)  
3. flag for forward motion collision, 0/1  
4. flag for backward motion collision, 0/1  

Buttons and keyboard keys trigger an interrupt when pressed, the states are set accordingly.  
The light sensors located at the back and front of the robot are set to interrupt when they read below a threshold value (indicating an object is too close), again sets above states accordingly.  
Pseudo Code for when a light sensor interrupts  

    Set flag that this direction is not allowed
    Set seven seg display for that direction to X
    Set the track state accordingly 
	  if the opposite direction is allowed
		  move away from collison in the opposite direction
	  else
		  nothing to be done, stay still
    Disable keyboard interrupts
    Disable button interrupts
    Clear that light sensor interrupt
    eret
    
For example if the front sensor triggers, tracks motion will be set to 2 (reverse, go away from the colision), flag for forward motion collision will be set to 1 and keyboard and button interrupts will be disabled to avoid the user/controller to continue motion towards obstacle.


Lastly the clock is set to interrupt every second and does two things.  
1. Keep track of the number of seconds that have passed while aiming the turret.  
2. Checks if flags for forward or backward motion collision need to be cleared (no object/obstacle anymore) and so set track motion to 0 (don't need to go away from the colision)  

Pseudo Code for when timer interrupts  

    Check if any direction was blocked (flag was high)  
    For each that was  
	      if that sensor reads above threshold value  
		      # (we moved away from the obstacle)  
		      Clear flag that says this direction not allowed  
		      Set seven seg display back to [] for that direction  
		      Set track state to 0 (stationary)  
		      Enable keyboard interrupts  
		      Enable button interrupts  
	      else  
		      Do nothing (we haven't moved away from the obstacle enough yet)  
    eret
    
Finally the main loop polls the state for any changes that might have occured from the above interrupts. When state is changed for track or turret motion, the corresponding motors are turned on. This is done to reduce the amount of time spent in handling interrupts, more work is done outside. There is pulse modulation on the the track and turret motors. The main loop periodically turns off the track and turret motors to ensure they are not always on when in use, controling the speed.