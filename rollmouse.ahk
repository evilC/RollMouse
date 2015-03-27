#SingleInstance force
rm := new RollMouse()

class RollMouse {
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
		
		this.InitHistory()
	}
	
	MouseMoved(wParam, lParam, code){
		static DeviceSize := 2 * A_PtrSize
		static iSize := 0
		static TimerFunc := 0
		static last_t := 0
		static axes := {x: 1, y: 2}
		static offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}
		Critical

		if (!TimerFunc){
			TimerFunc := this.MouseStopped.Bind(this)
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
			if (adm){
				this.History[axis].Insert({t: t, dt: dt, dm: dm, adm: adm})
				if (this.History[axis].MaxIndex() > 20){
					this.History[axis].Remove(1)
				}
			}
		}
		SetTimer %TimerFunc%, -20
	}
	
	MouseStopped(){
		static axes := {x: 1, y: 2}
		s := ""
		for axis in axes {
			lifted := 1
			last_vector := 0
			max := this.History[axis].MaxIndex()
			; Check if movement ends abruptly, or tails off
			if (max > 10){
				; Loop through the last movements in the buffer...
				Loop % max{
					; Ignore changes of direction...
					if (last_vector == this.History[axis][A_Index].dm){
						; If this movement was too long after the last one...
						if (this.History[axis][A_Index].dt > 10000){
							; No lift - Movement tailed off
							lifted := 0
							break
						}
					}
					last_vector := this.History[axis][A_Index].dm
				}
				if (lifted){
					ToolTip % axis ": " this.History[axis].MaxIndex()
					SoundBeep
				}
			}
		}
		this.InitHistory()
	}
	
	InitHistory(){
		this.History := {x: [], y: []}
	}
}

Esc::
GuiClose:
ExitApp