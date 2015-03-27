#SingleInstance force
mr := new RollMouse()

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
		
		this.History := []
	}
	
	MouseMoved(wParam, lParam, code){
		static DeviceSize := 2 * A_PtrSize
		static iSize := 0
		static ox := (20+A_PtrSize*2), oy := (24+A_PtrSize*2)
		static TimerFunc := 0
		static last_t := 0
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
		dx := NumGet(&uRawInput, ox, "Int")
		adx := abs(dx)
		
		if (adx){
			this.History.Insert({t: t, dt: dt, dx: dx, adx: adx})
			if (this.History.MaxIndex() > 20){
				;b := this.History.MaxIndex()
				this.History.Remove(1)
				;a := this.History.MaxIndex()
				;MsgBox % b ", " a
			}
		}

		SetTimer %TimerFunc%, -20
	}
	
	MouseStopped(){
		s := ""
		lifted := 1
		last_vector := 0
		max := this.History.MaxIndex()
		if (max > 10){
			Loop % max{
				if (last_vector != this.History[A_Index].dx){
					
				} else {
					if (this.History[A_Index].dt > 10000){
						lifted := 0
						break
					}
				}
				last_vector := this.History[A_Index].dx
			}
			if (lifted){
				ToolTip % this.History.MaxIndex()
				SoundBeep
			}
		}
		this.History := []
	}
}

Esc::
GuiClose:
ExitApp