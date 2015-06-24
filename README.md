# RollMouse

![ScreenShot](https://github.com/evilC/RollMouse/blob/master/rollmouse.png?raw=true)

##What does it do?

RollMouse is intended to solve the issue of having to compromise between low sensitivity (High accuracy, but hard to generate large mouse movements) and high sensitivity (Can generate large mouse movements easily, but accuracy suffers).  

It does this by making the mouse behave in a similar manner to spinning a TrackBall.

With RollMouse, you can set your sensitivity low, but still easily generate large and continuous mouse movements.  

RollMouse is compatible with all optical mice (ie most "normal" mice on the market) and laptop trackpads.

##Why would I want it?
Primarily intended for games with mouse aiming, but also it is useful for normal Windows operation if you have multiple monitors or a laptop with a trackpad.

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
If you move a mouse across a surface, no matter how quickly you stop moving the mouse, the movement will "tail off" - ie you start off moving fast and the mouse is sending "5,5,5,5".  
You then stop, and the mouse will report like "5,4,3,2,1"  
You cannot avoid this - the laws of intertia mean you cannot stop an object with mass instantly.

However, if you lift the device off the surface whilst in motion, as soon as the mouse reaches a certain height, the sensor stops getting any readings at all - so the mouse will report like "5,5,5,4,0"  

##How do I run it?
Download RollMouse.exe and run it - it's as simple as that.  
There is also a source code version (RollMouse.ahk) which you would need AutoHotkey installed (Plus a library) to use.  
