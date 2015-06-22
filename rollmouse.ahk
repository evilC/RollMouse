; Requires AHK >= 1.1.21.00

#SingleInstance force
rm := new RollMouse()

OutputDebug, DBGVIEWCLEAR

/*
ToDo:

* Add GUI
  Persistent settings etc.
* Filter mouse wheel
  Ignore all messages that are just the wheel moving
* Better history.
  Expire items that are too old.
  Filter outliers - eg a slight move up sometimes has a few move downs in there - keep general up motion but filter out direction inversions.
  Clear history on change of direction?

*/
class RollMouse {
	; User configurable items
	; The speed at which you must move the mouse to be able to trigger a roll
	MoveThreshold := {x: 4, y: 4}
	
	; The speed at which to move the mouse, can be decimals (eg 0.5)
	; X and Y do not need to be equal
	MoveFactor := {x: 2, y: 1}
	
	; How fast (in ms) to send moves when rolling.
	; High values for this will cause rolls to appear jerky instead of smooth
	; if you halved this, double MoveFactor to get the same move amount, but at a faster frequency.
	RollFreq := 10
	
	; How long to wait after each move to decide whether a roll has taken place.
	TimeOutRate := 20
	
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
		Gui, Show, w100 h100
		
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
		r := DllCall("RegisterRawInputDevices", "Ptr", &RAWINPUTDEVICE, "UInt", 1, "UInt", DevSize )
		
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
		
		Critical
		
		; RawInput statics
		static DeviceSize := 2 * A_PtrSize, iSize := 0, sz := 0, offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}, uRawInput
		
		static axes := {x: 1, y: 2}
		
		; Find size of rawinput data - only needs to be run the first time.
		if (!iSize){
			r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", iSize, "UInt", 8 + (A_PtrSize * 2))
			VarSetCapacity(uRawInput, iSize)
		}
		sz := iSize	; param gets overwritten with # of bytes output, so preserve iSize
		; Get RawInput data
		r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", &uRawInput, "UInt*", sz, "UInt", 8 + (A_PtrSize * 2))
		
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
		
		s := ""
		
		if (this.State != this.STATE_ROLLING){
			; If roll has just started, calculate roll vector from movement history
			this.LastMove := {x: 0, y: 0}
			
			for axis in axes {
				s .= axis ": "
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
				s .= "(" trend ")`n"
				if (sgn(trend) != sgn(this.History[axis][1].delta_move)){
					; downward trend of move speed detected - this is probably a normal stop of the mouse, not a lift
					continue
				}
				this.LastMove[axis] := round(this.LastMove[axis] * this.MoveFactor[axis])
			}
		}
		
		if (this.LastMove.x = 0 && this.LastMove.y = 0){
			return
		}
		this.ChangeState(this.STATE_ROLLING)

		OutputDebug % "ROLL DETECTED: `n" s "Rolling x: " this.LastMove.x ", y: " this.LastMove.y "`n`n"
		fn := this.MoveFunc
		while (this.State == this.STATE_ROLLING){
			; Disable listening for mouse movement (so the output we are about to make is not seen as input)
			this.ListenForMouseMovement(0)
			; Send output
			DllCall("mouse_event", "UInt", 0x01, "Int", this.LastMove.x, "Int", this.LastMove.y) ; move
			; Hand control to next thread (allow move to take place)
			Sleep 0
			; Turn on listening for mouse movement
			this.ListenForMouseMovement(1)
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
			OutputDebug, % "Changing State to : " this.StateNames[newstate]
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

return

F12::
GuiClose:
ExitApp
