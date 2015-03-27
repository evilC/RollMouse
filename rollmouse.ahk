#SingleInstance force
rm := new RollMouse()

class RollMouse {
	Moving := 0
	TimeOutFunc := 0
	MOVE_BUFFER_SIZE := 50
	
	__New(){
		static RIDEV_INPUTSINK := 0x00000100
		Gui, Show, w100 h100
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
		
		this.TimeOutFunc := this.MouseStopped.Bind(this)
		this.MoveFunc := this.MoveMouse.Bind(this)
		this.InitHistory()
	}
	
	MouseMoved(wParam, lParam, code){
		static DeviceSize := 2 * A_PtrSize
		static iSize := 0
		static last_t := 0
		static axes := {x: 1, y: 2}
		static offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}
		
		Critical

		if (this.Moving){
			fn := this.MoveFunc
			SetTimer % fn, Off
			this.Moving := 0
		}
		DllCall("QueryPerformanceCounter",Int64P, t)
		dt := t - last_t
		last_t := t
		if (!iSize){
			r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", iSize, "UInt", 8 + A_PtrSize * 2)
		}
		r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003, "Ptr", &uRawInput, "UInt*", iSize, "UInt", 8 + A_PtrSize * 2)
		for axis in axes {
			dm := NumGet(&uRawInput, offsets[axis], "Int")
			adm := abs(dm)
			sm := (adm = dm) ? 1 : -1
			if (adm){
				this.History[axis].Insert({t: t, dt: dt, dm: dm, adm: adm, sm: sm})
				if (this.History[axis].MaxIndex() > this.MOVE_BUFFER_SIZE){
					this.History[axis].Remove(1)
				}
			}
		}
		fn := this.TimeOutFunc
		SetTimer % fn, -20
	}
	
	MouseStopped(){
		static axes := {x: 1, y: 2}
		s := {x: "", y: ""}
		is_lifted := {x: 1, y: 1}
		move_counts := {x:0 , y:0}

		for axis in axes {
			last_vector := 0
			max := this.History[axis].MaxIndex()
			; Check if movement ends abruptly, or tails off
			
			; Ignore short movements...
			if (max = this.MOVE_BUFFER_SIZE){
				; Loop through the last movements in the buffer...
				Loop % max{
					; Ignore changes of direction...
					s[axis] .= this.History[axis][A_Index].dt ", "
					if ( (last_vector != 0 && last_vector != this.History[axis][A_Index].sm ) || this.History[axis][A_Index].dt > 10000){
						is_lifted[axis] := 0
						break
					}
					last_vector := this.History[axis][A_Index].sm
				}
			} else {
				is_lifted[axis] := 0
			}
		}
		if (is_lifted.x || is_lifted.y){
			if (!this.Moving){
				this.Moving := 1
				;fn := this.MoveFunc
				;SetTimer % fn, 20
				out := "ROLL TRIGGERED (max x: " this.History.x.MaxIndex() ", y: " this.History.y.MaxIndex() ")`n"
				if(is_lifted.x){
					out .= "`nx: " s.x
				}
				if(is_lifted.y){
					out .= "`ny: " s.y
				}
				ToolTip % out
			}
		} else {
			ToolTip
		}
		this.InitHistory()
	}
	
	MoveMouse(){
		SoundBeep
		;DllCall("mouse_event", "UInt", 0x01, "UInt", 10, "UInt", 0) ; move
	}
	
	InitHistory(){
		this.History := {x: [], y: []}
	}
}

Esc::
GuiClose:
ExitApp