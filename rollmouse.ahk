; Requires AHK >= 1.1.21.00

/*
ToDo:

* Better history.
  Expire items that are too old.
  Filter outliers - eg a slight move up sometimes has a few move downs in there - keep general up motion but filter out direction inversions.
  Clear history on change of direction?

*/

#SingleInstance force
ADHD := new ADHDLib

ADHD.config_about({name: "Rollmouse", version: "1.0.5", author: "evilC", link: "<a href=""https://github.com/evilC/RollMouse"">GitHub Page</a>    /   <a href=""http://ahkscript.org/boards/viewtopic.php?f=6&t=8439"">Discussion Thread</a>"})
ADHD.config_updates("http://evilc.com/files/ahk/adhd/rollmouse.au.txt")

ADHD.config_size(375,230)

ADHD.config_hotkey_add({uiname: "Quit", subroutine: "Quit"})

ADHD.config_event("option_changed", "option_changed_hook")

ADHD.init()
ADHD.create_gui()

Gui1 := WinExist()

Gui, Tab, 1

row := 40

Gui, Font, italic
Gui, Add, Text, x10 y%row%, Move Factor controls how fast the mouse will be moved in any given`ndirection when you perform a roll. Decimals (eg 0.5) are permissible.
Gui, Font
row += 30

Gui, Add, Text, x10 y%row%, Move Factor:
Gui, Add, Text, x120 yp, x
ADHD.gui_add("Edit", "MoveFactorX", "xp+10 yp-2 W50", "", "1")
Gui, Add, Text, xp+80 yp+2, y
ADHD.gui_add("Edit", "MoveFactorY", "xp+10 yp-2 W50", "", "1")

row += 30
Gui, Font, italic
Gui, Add, Text, x10 y%row%, Move Threshold controls how fast you have to move the mouse`nto perform a roll. Decimals are NOT permitted.
Gui, Font
row += 30
Gui, Add, Text, x10 y%row%, Move Threshold:
Gui, Add, Text, x120 yp, x
ADHD.gui_add("Edit", "MoveThreshX", "xp+10 yp-2 W50", "", "4")
Gui, Add, Text, xp+80 yp+2, y
ADHD.gui_add("Edit", "MoveThreshY", "xp+10 yp-2 W50", "", "4")

row += 30
ADHD.gui_add("CheckBox", "MinimizeOnStart", "x10 y" row, "Minimize on StartUp", 0)

ADHD.finish_startup()

rm := new RollMouse

Gui1 := WinExist()
Menu("Tray","Nostandard"), Menu("Tray","Add","Restore","GuiShow"), Menu("Tray","Add")
Menu("Tray","Default","Restore"), Menu("Tray","Click",1), Menu("Tray","Standard")

OnMessage(0x112, "WM_SYSCOMMAND")

if (MinimizeOnStart){
	Gosub, OnMinimizeButton
}

option_changed_hook()

;OutputDebug, DBGVIEWCLEAR

option_changed_hook(){
	global MoveFactorX, MoveFactorY, MoveThreshX, MoveThreshY
	global rm
	rm.MoveFactor.x := MoveFactorX
	rm.MoveFactor.y := MoveFactorY
	rm.MoveThreshold.x := MoveThreshX
	rm.MoveThreshold.y := MoveThreshY
}

return

class RollMouse {
	; User configurable items
	; The speed at which you must move the mouse to be able to trigger a roll
	MoveThreshold := {x: 4, y: 4}
	; Good value for my mouse with FPS games: 4
	; Good value for my laptop trackpad: 3
	
	; The speed at which to move the mouse, can be decimals (eg 0.5)
	; X and Y do not need to be equal
	; Good value for my mouse with FPS games: x:2, y: 1 (don't need vertical roll so much)
	MoveFactor := {x: 1, y: 1}
	; Good value for my laptop trackpad: 0.2
	
	; How fast (in ms) to send moves when rolling.
	; High values for this will cause rolls to appear jerky instead of smooth
	; if you halved this, double MoveFactor to get the same move amount, but at a faster frequency.
	RollFreq := 1
	
	; How long to wait after each move to decide whether a roll has taken place.
	TimeOutRate := 50
	
	; The amount that we are currently rolling by
	LastMove := {x: 0, y: 0}

	; The number of previous moves stored - used to calculate vector of a roll
	; Higher numbers = greater fidelity, but more CPU
	MOVE_BUFFER_SIZE := 5

	; Non user-configurable items
	STATE_UNDER_THRESH := 1
	STATE_OVER_THRESH := 2
	STATE_ROLLING := 3
	StateNames := ["UNDER THRESHOLD", "OVER THRESHOLD", "ROLLING"]
	
	State := 1
	
	TimeOutFunc := 0
	History := {}	; Movement history. The most recent item is first (Index 1), and old (high index) items get pruned off the end
	
	; Called on startup.
	__New(){
		static RIDEV_INPUTSINK := 0x00000100
		
		; Create GUI (GUI needed to receive messages)
		;Gui, Show, w100 h100
		
		; Set TimeOutRate to negative value to have timer only fire once.
		this.TimeOutRate := this.TimeOutRate * -1
		
		; Register mouse for WM_INPUT messages.
		DevSize := 8 + A_PtrSize
		VarSetCapacity(RAWINPUTDEVICE, DevSize)
		NumPut(1, RAWINPUTDEVICE, 0, "UShort")
		NumPut(2, RAWINPUTDEVICE, 2, "UShort")
		Flags := RIDEV_INPUTSINK
		NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
		NumPut(WinExist("A"), RAWINPUTDEVICE, 8, "Uint")
		r := DllCall("user32.dll\RegisterRawInputDevices", "Ptr", &RAWINPUTDEVICE, "UInt", 1, "UInt", DevSize )
		
		fn := this.MouseMoved.Bind(this)
		this.MoveFunc := fn
		this.ListenForMouseMovement(1)
		
		; Initialize
		this.TimeOutFunc := this.DoRoll.Bind(this)
		this.InitHistory()
	}
	
	; Turns on or off listening for mouse movement
	ListenForMouseMovement(mode){
		fn := this.MoveFunc
		if (mode){
			OnMessage(0x00FF, fn)
		} else {
			OnMessage(0x00FF, fn, 0)
		}
	}
	
	; Called when the mouse moved.
	; Messages tend to contain small (+/- 1) movements, and happen frequently (~20ms)
	MouseMoved(wParam, lParam, code){
		static MAX_TIME := 1000000		; Only cache values for this long.
		
		; RawInput statics
		static DeviceSize := 2 * A_PtrSize, iSize := 0, sz := 0, offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2), button: (18+A_PtrSize*2)}, uRawInput
		
		static axes := {x: 1, y: 2}

		Critical
		VarSetCapacity(raw, 40, 0)
		If (!DllCall("GetRawInputData",uint,lParam,uint,0x10000003,uint,&raw,"uint*",40,uint, 16) || ErrorLevel || !NumGet(raw, 8))
			Return 0	; Ignore events with a Device ID of 0 - these are mouse movements we sent using mouse_event
		; Find size of rawinput data - only needs to be run the first time.
		if (!iSize){
			r := DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", iSize, "UInt", 8 + (A_PtrSize * 2))
			VarSetCapacity(uRawInput, iSize)
		}
		sz := iSize	; param gets overwritten with # of bytes output, so preserve iSize
		; Get RawInput data
		r := DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", &uRawInput, "UInt*", sz, "UInt", 8 + (A_PtrSize * 2))

		; ignore button activity
		if (NumGet(&uRawInput, offsets.button, "Int") == 0){
			return
		}

		moved := {x: 0, y: 0}
		
		for axis in axes {
			obj := {}
			obj.delta_move := NumGet(&uRawInput, offsets[axis], "Int")
			obj.abs_delta_move := abs(obj.delta_move)
			obj.sgn_move := (obj.abs_delta_move = obj.delta_move) ? 1 : -1

			if (obj.abs_delta_move >= this.MoveThreshold[axis]){
				moved[axis] := 1
			}
			
			this.UpdateHistory(axis, obj)
		}

		if (moved.x || moved.y){
			; A move over the threshold was detected.
			this.ChangeState(this.STATE_OVER_THRESH)
		} else {
			this.ChangeState(this.STATE_UNDER_THRESH)
		}

	}
	
	UpdateHistory(axis, obj){
		this.History[axis].InsertAt(1, obj)
		; Enforce max number of entries
		max := this.History[axis].Length()
		if (max > (this.MOVE_BUFFER_SIZE - 1)){
			this.History[axis].RemoveAt(max, max - this.MOVE_BUFFER_SIZE)
		}
	}
	
	; A timeout occurred - Perform a roll
	DoRoll(){
		static axes := {x: 1, y: 2}
		
		;s := ""
		
		if (this.State != this.STATE_ROLLING){
			; If roll has just started, calculate roll vector from movement history
			this.LastMove := {x: 0, y: 0}
			
			for axis in axes {
				;s .= axis ": "
				trend := 0
				if (this.History[axis].Length() < this.MOVE_BUFFER_SIZE){
					; ignore gestures that are too short
					continue
				}
				Loop % this.History[axis].Length() {
					if (A_Index != 1){
						; Calculate the trend of the history.
						trend += (this.History[axis][A_Index].delta_move - this.History[axis][A_Index-1].delta_move)
					}
					this.LastMove[axis] += this.History[axis][A_Index].delta_move
					s .= this.History[axis][A_Index].delta_move ","
				}
				;s .= "(" trend ")`n"
				/*
				Disabled, as seems to break mouse trackpads.
				Also seems to stop MoveFactor being applied to both axes?
				if (sgn(trend) != sgn(this.History[axis][1].delta_move)){
					; downward trend of move speed detected - this is probably a normal stop of the mouse, not a lift
					continue
				}
				*/
				this.LastMove[axis] := round(this.LastMove[axis] * this.MoveFactor[axis])
			}
		}
		
		if (this.LastMove.x = 0 && this.LastMove.y = 0){
			return
		}
		this.ChangeState(this.STATE_ROLLING)

		;OutputDebug % "ROLL DETECTED: `n" s "Rolling x: " this.LastMove.x ", y: " this.LastMove.y "`n`n"
		fn := this.MoveFunc
		while (this.State == this.STATE_ROLLING){
			; Send output
			DllCall("user32.dll\mouse_event", "UInt", 0x0001, "UInt", this.LastMove.x, "UInt", this.LastMove.y, "UInt", 0, "UPtr", 0)
			; Wait for a bit (allow real mouse movement to be detected, which will turn off roll)
			Sleep % this.RollFreq
		}
		
	}
	
	InitHistory(){
		this.History := {x: [], y: []}
	}
	
	ChangeState(newstate){
		fn := this.TimeOutFunc
		if (this.State != newstate){
			;OutputDebug, % "Changing State to : " this.StateNames[newstate]
			this.State := newstate
		}
		
		; DO NOT return if this.State == newstate!
		; We need to reset the timer!
		
		if (this.State = this.STATE_UNDER_THRESH){
			; Kill the timer
			SetTimer % fn, Off
			; Clear the history
			this.InitHistory()
		} else if (this.State = this.STATE_OVER_THRESH){
			; Mouse is moving fast - start timer to detect sudden stop in messages (mouse was lifted in motion)
			SetTimer % fn, % this.TimeOutRate
		}
		/* else if (this.State = this.STATE_ROLLING){
			;this.LastMove := {x: 0, y: 0}
		}
		*/
	}
}

Sgn(val){
	if (val > 0){
		return 1
	} else if (val < 0){
		return -1
	} else {
		return 0
	}
}

Quit:
	ExitApp
	return

; Minimze to tray by SKAN http://www.autohotkey.com/board/topic/32487-simple-minimize-to-tray/
WM_SYSCOMMAND(wParam){
   If ( wParam = 61472 ) {
   SetTimer, OnMinimizeButton, -1
   Return 0
   }
}


Menu( MenuName, Cmd, P3="", P4="", P5="" ) {
	Menu, %MenuName%, %Cmd%, %P3%, %P4%, %P5%
	Return errorLevel
}

OnMinimizeButton:
	MinimizeGuiToTray( R, Gui1 )
	Menu("Tray","Icon")
	Return

GuiShow:
  DllCall("DrawAnimatedRects", UInt,Gui1, Int,3, UInt,&R+16, UInt,&R )
  Menu("Tray","NoIcon")
  Gui, Show
Return

MinimizeGuiToTray( ByRef R, hGui ) {
  WinGetPos, X0,Y0,W0,H0, % "ahk_id " (Tray:=WinExist("ahk_class Shell_TrayWnd"))
  ControlGetPos, X1,Y1,W1,H1, TrayNotifyWnd1,ahk_id %Tray%
  SW:=A_ScreenWidth,SH:=A_ScreenHeight,X:=SW-W1,Y:=SH-H1,P:=((Y0>(SH/3))?("B"):(X0>(SW/3))
  ? ("R"):((X0<(SW/3))&&(H0<(SH/3)))?("T"):("L")),((P="L")?(X:=X1+W0):(P="T")?(Y:=Y1+H0):)
  VarSetCapacity(R,32,0), DllCall( "GetWindowRect",UInt,hGui,UInt,&R)
  NumPut(X,R,16), NumPut(Y,R,20), DllCall("RtlMoveMemory",UInt,&R+24,UInt,&R+16,UInt,8 )
  DllCall("DrawAnimatedRects", UInt,hGui, Int,3, UInt,&R, UInt,&R+16 )
  WinHide, ahk_id %hGui%
}

#Include <adhdlib>