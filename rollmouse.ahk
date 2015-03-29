; Requires AHK >= 1.1.21.00

#SingleInstance force
rm := new RollMouse()

OutputDebug, DBGVIEWCLEAR

class RollMouse {
	Rolling := 0
	TimeOutFunc := 0
	History := {}	; Movement history. The most recent item is first (Index 1), and old (high index) items get pruned off the end
	MOVE_BUFFER_SIZE := 20
	
	; Called on startup.
	__New(){
		static RIDEV_INPUTSINK := 0x00000100
		
		; Create GUI (GUI needed to receive messages)
		Gui, Show, w100 h100
		
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
		OnMessage(0x00FF, fn)
		
		; Initialize
		this.TimeOutFunc := this.MouseStopped.Bind(this)
		this.InitHistory()
	}
	
	; Called when the mouse moved.
	; Messages tend to contain small (+/- 1) movements, and happen frequently (~20ms)
	MouseMoved(wParam, lParam, code){
		static DeviceSize := 2 * A_PtrSize
		static iSize := 0
		static sz := 0
		static last_t := 0
		static axes := {x: 1, y: 2}
		static offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}
		static uRawInput
		
		Critical
		
		; Get accurate timestamp for this message
		DllCall("QueryPerformanceCounter",Int64P, t)

		; Get delta time
		dt := t - last_t
		last_t := t
		
		; Find size of rawinput data - only needs to be run the first time.
		if (!iSize){
			r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", iSize, "UInt", 8 + (A_PtrSize * 2))
			VarSetCapacity(uRawInput, iSize)
		}
		sz := iSize	; param gets overwritten with # of bytes output, so preserve iSize
		; Get RawInput data
		r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", &uRawInput, "UInt*", sz, "UInt", 8 + (A_PtrSize * 2))
		
		; Update History array
		for axis in axes {
			dm := NumGet(&uRawInput, offsets[axis], "Int")	; delta move
			adm := abs(dm)	; absolute delta move
			sm := (adm = dm) ? 1 : -1	; sign of move
			if (adm){
				; Prune for change in direction
				
				; Add new entry
				this.History[axis].InsertAt(1,{t: t, dt: dt, dm: dm, adm: adm, sm: sm})
				; Prune old entries...
				
				; Enforce max length
				if (this.History[axis].Length() > this.MOVE_BUFFER_SIZE){
					;this.History[axis].Remove(1)
					this.History[axis].Pop()
				}
				
				; Prune for time
				
			}
		}
		
		; Decide what action to take due to the mouse movement.
		if (this.Rolling){
			; We are rolling the mouse.
			; If this is genuine user input, we should stop rolling (The user placed the mouse back on the mat)
			; Howver, when we "Roll" the mouse using code, we see the movement we just output as input.
			if (this.History.x[this.History.x.Length()].dt < 10000){
				; Latest move update was less that 10000 ago, this is actual user input...
				; ...A bit unsure as to exactly why this works, could maybe do with improving?
				
				; Turn off Roll timer
				fn := this.RollFunc
				SetTimer % fn, Off
				this.Rolling := 0
			}
		} else {
			; Mouse is being used normally, set a timeout func to run 20 ms from now
			fn := this.TimeOutFunc
			SetTimer % fn, -20
		}
	}
	
	; Timeout occurred after a move - mouse stopped moving.
	; Decide whether to Roll mouse or not
	MouseStopped(){
		;static MIN_MOVE_TIME := 10000
		static MIN_MOVE_TIME := 14000
		static axes := {x: 1, y: 2}
		s := {x: "", y: ""}
		is_lifted := {x: 1, y: 1}
		move_counts := {x:0 , y:0}
		
		dbg := "Mouse Stopped: "

		for axis in axes {
			last_vector := 0
			max := this.History[axis].Length()
			; Check if movement ends abruptly, or tails off
			
			; Ignore short movements...
			if (max = this.MOVE_BUFFER_SIZE){
				; Loop through the last movements in the buffer...
				Loop % max{
					s[axis] .= this.History[axis][A_Index].dt ", "
					; If direction changed, or delta time was too long, discount this gesture
					if ( (last_vector != 0 && last_vector != this.History[axis][A_Index].sm ) || this.History[axis][A_Index].dt > MIN_MOVE_TIME){
						is_lifted[axis] := 0
						dbg .= axis " Direction changed, or delta time was too long. "
						break
					}
					last_vector := this.History[axis][A_Index].sm
				}
			} else {
				dbg .= axis " Did not meet max buffer size. "
				is_lifted[axis] := 0
			}
		}
		if (is_lifted.x || is_lifted.y){
			if (!this.Rolling){
				this.Rolling := 1
				obj := is_lifted
				for axis in axes {
					obj[axis] *= this.History[axis][1].sm
				}
				fn := this.RollMouse.Bind(this, obj)
				this.RollFunc := fn
				SetTimer % fn, 20
				this.RollMouse(is_lifted)
				
				dbg .= "ROLL TRIGGERED (max x: " this.History.x.Length() ", y: " this.History.y.Length() ")"
				if(is_lifted.x){
					dbg .= " | x: " s.x
				}
				if(is_lifted.y){
					dbg .= " | y: " s.y
				}
			}
		}
		OutputDebug % dbg

		this.InitHistory()
	}
	
	RollMouse(axes){
		static MOVE_FACTOR := 100
		DllCall("mouse_event", "UInt", 0x01, "UInt", axes.x * MOVE_FACTOR, "UInt", 0) ; move
	}
	
	InitHistory(){
		this.History := {x: [], y: []}
	}
}

;Esc::
F12::
GuiClose:
ExitApp