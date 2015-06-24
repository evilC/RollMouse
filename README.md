# RollMouse

![ScreenShot](https://github.com/evilC/RollMouse/blob/master/rollmouse.png?raw=true)

##What does it do?

RollMouse is intended to solve the issue of having to compromise between low sensitivity (High accuracy, but hard to generate large mouse movements) and high sensitivity (Can generate large mouse movements easily, but accuracy suffers).  

It does this by making the mouse behave in a similar manner to spinning a TrackBall.

With RollMouse, you can set your sensitivity low, but still easily generate large and continuous mouse movements.  

RollMouse is compatible with all optical mice (ie most "normal" mice on the market) and laptop trackpads.

##Why would I want it?
###Games
Many mouse have "DPI Shift" / "Sniper Mode" buttons, but these often require sacrificing a button on your mouse in order to use them, and are often impractical to use. Setting your mouse to drop DPI while you hold the aim button is probably the most practical, but shifting DPI mid-game is not going to help your Muscle Memory.  
###Windows
If you have a large desktop area (ie Multiple Monitors), moving the mouse around can be a chore.  
If you use a laptop with a trackpad, you probably hate having to make lots of small movements to generate a long movement in one direction.  
*Note: If you use RollMouse on a laptop, I strongly recommend also turning on "Pointer Trails" else it can be hard to keep track of the mouse pointer when RollMouse moves it. This option can be enabled by going to Control Panel > Mouse > Pointer Options tab > Display Pointer Trails.*

##How do I use it?
First off, some definitions, or this will get confusing ;)  
With a mouse, the "surface" is the mouse mat, and the "device" is the mouse.  
With a trackpad, the "surface" is the trackpad, and the "device" is your finger.  

If you keep the device in contact with the surface, RollMouse does nothing - it should not interfere with "normal" operation.  
However, if you lift the device from the surface **while the device is still in motion** then RollMouse will keep moving the mouse pointer in the direction of the motion until you place the device back on the surface.  

When it does this, the direction and speed that it moves the mouse is proportionate to the speed and direction that you were moving the mouse when you lifted.  

Use of RollMouse is very intuitive - many people already lift while moving, in order to reposition the mouse when it reaches the edge of the mat.  
With RollMouse, however, the mouse cursor **keeps moving** while you are repositioning the mouse.  

##How does it work?
RollMouse makes use of the laws of physics.  
If you move a mouse across a surface, no matter how quickly you stop moving the mouse, the movement will "tail off" - ie you start off moving fast and the mouse is sending "5, 5 , 5, 5, [...]".  
You then stop, and the mouse will report like "5, 4, 3, 2, 1, 0"  
You cannot avoid this - the laws of intertia mean you cannot stop an object with mass instantly.

However, if you lift the device off the surface whilst in motion, as soon as the mouse reaches a certain height, the sensor stops getting any readings at all - so the mouse will report like "5, 5, 5, 5, 0"  

##How do I run it?
Download RollMouse.exe and run it - it's as simple as that.  
There is also a source code version (RollMouse.ahk) which you would need AutoHotkey installed (Plus a library) to use.  
