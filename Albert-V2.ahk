#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
;                         1. ИНИЦИАЛИЗАЦИЯ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
; ==============================================================================

global iniFile := A_ScriptDir . "\settings.ini"

global todayKey := FormatTime(A_Now, "yyyy-MM-dd")
global todaySales := IniRead(iniFile, "DailySales", todayKey, 0)

; 0 = Normal, 1 = MicroSIP, 2 = Bitrix, 3 = Sverka, 4 = Telegram, 5 = SAP
global currentMode := 2  
global lastWorkMode := 2

global statusF2 := "boradi"
global statusF3 := "ko'tarmadi"
global statusF4 := "gaplashilingan"

global statusSverkaF2 := "boradi"
global statusSverkaF4 := "ko'chada"

; Тексты, которые F3 и F4 вводят в режиме SAP.
; Их можно изменить здесь, не затрагивая остальные сценарии скрипта.
global sapF3Text := "Sayfuddinov Abdulloh"
global sapF4Text := "Mijozni telefon raqamiga boglana olmadik"



global callCount := 0
global currentPhoneNum := "---"

; Переменные для защиты от мерцания виджетов
global widgetsVisible := false 
global lastSipX := -1
global lastSipY := -1

ToolTip("Режим: BITRIX (F12: SAP | F11: Режимы | End: Normal)")
SetTimer(() => ToolTip(), -3000)
; ==============================================================================
;                         2. ИНТЕРФЕЙС, ВИДЖЕТЫ MICROSIP И ИНДИКАТОР РЕЖИМА
; ==============================================================================

; --- Виджеты привязки к MicroSIP ---
infoWidget := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner")
infoWidget.SetFont("s8 bold", "Segoe UI")
infoWidget.BackColor := "F0F0F0"
infoText := infoWidget.Add("Text", "c008800 w125 Center h18 +0x200", "№:---  #0")

daySalesWidget := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner")
daySalesWidget.BackColor := "F0F0F0"
daySalesWidget.SetFont("s7", "Segoe UI")
daySalesLabel := daySalesWidget.Add("Text", "c777777 w40 Center h12", "ДЕНЬ")
daySalesWidget.SetFont("s12 bold", "Segoe UI")
daySalesValText := daySalesWidget.Add("Text", "c0066CC w40 Center h22", todaySales)


; --- Постоянный индикатор текущего режима (ЖЕСТКО ПОВЕРХ ТАСКБАРА) ---
trayHwnd := WinExist("ahk_class Shell_TrayWnd")
global modeWidget := Gui("+AlwaysOnTop -Caption +ToolWindow" . (trayHwnd ? " +Owner" . trayHwnd : ""))
modeWidget.BackColor := "272727"
modeWidget.MarginX := 0
modeWidget.MarginY := 0
modeWidget.SetFont("s9 bold", "Segoe UI")
global modeText := modeWidget.Add("Text", "cFFFFFF Center w105 h30 +0x200 Background272727", "BITRIX")

MonitorGet(1, &ML, &MT, &MR, &MB)
global modeGuiW := 105
global modeGuiH := 35
global modeGuiX := MR - 450
global modeGuiY := MB - modeGuiH

modeWidget.Show("x" . modeGuiX . " y" . modeGuiY . " w" . modeGuiW . " h" . modeGuiH . " NoActivate")

SetTimer(AttachWidgetsToMicroSip, 100)
SetTimer(KeepModeIndicatorVisible, 300)
UpdateModeIndicator()

; Обновляет постоянный виджет внизу экрана: выводит название активного режима
; и повторно выводит окно поверх панели задач, не забирая фокус у рабочего окна.
UpdateModeIndicator()
{
    global currentMode, modeText, modeWidget, modeGuiX, modeGuiY, modeGuiW, modeGuiH
    
    if (currentMode == 0)
        modeText.Value := "NORMAL"
    else if (currentMode == 1)
        modeText.Value := "MICROSIP"
    else if (currentMode == 2)
        modeText.Value := "BITRIX"
    else if (currentMode == 3)
        modeText.Value := "SVERKA"
    else if (currentMode == 4)
        modeText.Value := "TELEGRAM"
    else if (currentMode == 5)
        modeText.Value := "SAP"

    ; Возвращаем индикатор поверх Taskbar без перехвата фокуса
    WinSetAlwaysOnTop(1, modeWidget.Hwnd)

    modeWidget.Show(
        "x" . modeGuiX .
        " y" . modeGuiY .
        " w" . modeGuiW .
        " h" . modeGuiH .
        " NoActivate"
    )
}
KeepModeIndicatorVisible()
{
    global modeWidget, modeGuiX, modeGuiY, modeGuiW, modeGuiH

    try
    {
        if !WinExist("ahk_id " . modeWidget.Hwnd)
            return

        WinSetAlwaysOnTop(1, modeWidget.Hwnd)

        modeWidget.Show(
            "x" . modeGuiX .
            " y" . modeGuiY .
            " w" . modeGuiW .
            " h" . modeGuiH .
            " NoActivate"
        )
    }
}

; Каждые 100 мс ищет окно MicroSIP и держит рядом с ним два информационных
; виджета. Также скрывает их при сворачивании/закрытии MicroSIP и обнуляет
; дневную статистику при смене календарного дня.
AttachWidgetsToMicroSip()
{
    global infoWidget, daySalesWidget, todayKey, todaySales, iniFile, currentMode
    global widgetsVisible, lastSipX, lastSipY
    
    currentDay := FormatTime(A_Now, "yyyy-MM-dd")
    if (currentDay != todayKey)
    {
        todayKey := currentDay
        todaySales := IniRead(iniFile, "DailySales", todayKey, 0)
        UpdateAllWidgetsDisplay()
    }

    try
    {
        hwnd := WinExist("ahk_exe microsip.exe")
        if (hwnd)
        {
            minMax := WinGetMinMax(hwnd)
            if (minMax == -1)
            {
                if (widgetsVisible)
                {
                    infoWidget.Hide()
                    daySalesWidget.Hide()
                    widgetsVisible := false
                }
                return
            }

            WinGetPos(&X, &Y, &W, &H, hwnd)
            if (W == 0 || H == 0)
            {
                if (widgetsVisible)
                {
                    infoWidget.Hide()
                    daySalesWidget.Hide()
                    widgetsVisible := false
                }
                return
            }

            bottomX := X + 10
            bottomY := Y + H - 62
            daySalesX := X + 14
            daySalesY := Y + 250

            if (!widgetsVisible)
            {
                infoWidget.Show("x" . bottomX . " y" . bottomY . " w125 h20 NoActivate")
                daySalesWidget.Show("x" . daySalesX . " y" . daySalesY . " w42 h50 NoActivate")
                widgetsVisible := true
                lastSipX := X
                lastSipY := Y
            }
            else if (X != lastSipX || Y != lastSipY)
            {
                infoWidget.Move(bottomX, bottomY)
                daySalesWidget.Move(daySalesX, daySalesY)
                lastSipX := X
                lastSipY := Y
            }
        }
        else
        {
            if (widgetsVisible)
            {
                infoWidget.Hide()
                daySalesWidget.Hide()
                widgetsVisible := false
            }
        }
    }
    catch
    {
        if (widgetsVisible)
        {
            infoWidget.Hide()
            daySalesWidget.Hide()
            widgetsVisible := false
        }
    }
}
; ==============================================================================
;                         3. ВНУТРЕННИЕ ФУНКЦИИ И ЛОГИКА
; ==============================================================================

; Синхронизирует текст виджетов с текущим номером, счётчиком попыток и числом
; продаж за день. Вызывается после любого изменения этих данных.
UpdateAllWidgetsDisplay()
{
    global callCount, currentPhoneNum, todaySales
    global infoText, daySalesValText
    
    dispNum := (currentPhoneNum != "") ? currentPhoneNum : "---"
    infoText.Value := "№:" . dispNum . "  #" . callCount
    daySalesValText.Value := todaySales
}

; Сбрасывает количество попыток звонка для нового номера и сразу обновляет виджет.
ResetCallAttemptCounter()
{
    global callCount
    callCount := 0
    UpdateAllWidgetsDisplay()
}

; Извлекает из произвольного текста только цифры и проверяет длину номера.
; При add998=true возвращает номер в международном виде 998XXXXXXXXX;
; при false возвращает 9 цифр для ввода в MicroSIP. Некорректные данные дают Error.
CleanAndFormatPhone(num, add998)
{
    cleanNum := RegExReplace(num, "\D", "")
    len := StrLen(cleanNum)

    if (len < 9 || len > 12)
        return "Error"

    if (len == 10 || len == 11)
    {
        cleanNum := SubStr(cleanNum, -9)
        len := 9
    }

    if (add998)
    {
        if (len == 9)
            return "998" . cleanNum
        if (len == 12 && SubStr(cleanNum, 1, 3) != "998")
            return "998" . SubStr(cleanNum, 4)
        return cleanNum
    }
    else
    {
        if (len == 12)
            return SubStr(cleanNum, 4)
        return cleanNum
    }
}

; Ищет следующий корректный номер в таблице: копирует активную ячейку, при
; необходимости идёт вниз, а явно испорченные номера помечает как Error.
; Возвращает отформатированный номер либо Error, если поиск нужно остановить.
SearchNextPhoneInTable(add998)
{
    maxTries := 15
    emptyCount := 0

    Loop maxTries
    {
        A_Clipboard := ""
        Send("{Ctrl Down}c{Ctrl Up}")
        if !ClipWait(0.6)
        {
            emptyCount++
            if (emptyCount >= 2)
                return "Error"

            Send("{Down}")
            Sleep(30)
            continue
        }

        rawText := Trim(A_Clipboard, "`r`n`t ")
        if (rawText == "")
        {
            emptyCount++
            if (emptyCount >= 2)
            {
                ToolTip("Конец списка (2 пустые ячейки подряд)")
                SetTimer(() => ToolTip(), -1600)
                return "Error"
            }
            Send("{Down}")
            Sleep(30)
            continue
        }

        emptyCount := 0
        phone := CleanAndFormatPhone(rawText, add998)

        if (phone != "Error")
            return phone

        ToolTip("Битый номер! Запись Error...")
        SetTimer(() => ToolTip(), -960)

        Send("{Right}{Right}")
        Sleep(30)
        A_Clipboard := "Error"
        Send("{Ctrl Down}v{Ctrl Up}{Enter}{Up}{Left}{Left}{Down}")
        Sleep(30)
    }
    return "Error"
}

; Завершает текущий сценарий MicroSIP, записывает переданный статус в таблицу,
; находит следующий номер и сразу переносит его в MicroSIP для нового звонка.
HandleSipCallFlow(statusText)
{
    global currentPhoneNum
    
    Send("{Enter}")
    Sleep(30)
    Send("!{Tab}")
    Sleep(80)

    Send("{Right}{Right}")
    Sleep(30)
    A_Clipboard := statusText
    Send("{Ctrl Down}v{Ctrl Up}{Enter}{Up}{Left}{Left}{Down}")
    Sleep(30)

    phone := SearchNextPhoneInTable(false)
    if (phone == "Error")
        return

    currentPhoneNum := phone
    ResetCallAttemptCounter()

    A_Clipboard := phone
    Send("!{Tab}")
    Sleep(80)
    Send("{Ctrl Down}a{Ctrl Up}")
    Sleep(30)
    Send("{Ctrl Down}v{Ctrl Up}{Enter}")
}

; Режим SAP, F2: копирует номер, который пользователь заранее выделил двойным
; щелчком; убирает код страны 998, активирует MicroSIP и звонит. Буфер обмена
; сохраняется и восстанавливается, поэтому эта операция не портит копируемый текст.
CallSelectedPhoneInSapMode()
{
    global currentPhoneNum, callCount

    savedClipboard := ClipboardAll()
    A_Clipboard := ""
    Send("{Ctrl Down}c{Ctrl Up}")

    if !ClipWait(0.5)
    {
        A_Clipboard := savedClipboard
        ToolTip("Выделите номер двойным щелчком и нажмите F1")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    phone := CleanAndFormatPhone(A_Clipboard, false)
    if (phone == "Error")
    {
        A_Clipboard := savedClipboard
        ToolTip("Выделенный текст не похож на номер")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    if !WinExist("ahk_exe microsip.exe")
    {
        A_Clipboard := savedClipboard
        ToolTip("MicroSIP не запущен")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    currentPhoneNum := phone
    ; Выбран новый номер: первая попытка всегда начинается с #1.
    callCount := 1
    UpdateAllWidgetsDisplay()

    WinActivate("ahk_exe microsip.exe")
    Sleep(100)
    A_Clipboard := phone
    Send("{Ctrl Down}a{Ctrl Up}")
    Sleep(30)
    Send("{Ctrl Down}v{Ctrl Up}{Enter}")
    Sleep(80)
    A_Clipboard := savedClipboard
}

; Режим SAP, F3/F4: печатает переданный текст в активное поле без использования
; буфера обмена. Поэтому ранее скопированный номер или другой текст сохраняется.
InsertSapText(textToInsert)
{
    SendText(textToInsert)
}

; Режим SAP, F1: повторно набирает текущий номер из виджета MicroSIP. В отличие
; от F2 номер не копируется заново, а счётчик попыток увеличивается на единицу.
RedialCurrentSapPhone()
{
    global currentPhoneNum, callCount

    phone := CleanAndFormatPhone(currentPhoneNum, false)
    if (phone == "Error" || currentPhoneNum == "---")
    {
        ToolTip("Сначала выберите номер через F2")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    if !WinExist("ahk_exe microsip.exe")
    {
        ToolTip("MicroSIP не запущен")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    savedClipboard := ClipboardAll()
    A_Clipboard := phone
    WinActivate("ahk_exe microsip.exe")
    Sleep(100)
    Send("{Ctrl Down}a{Ctrl Up}")
    Sleep(30)
    Send("{Ctrl Down}v{Ctrl Up}{Enter}")
    Sleep(80)
    A_Clipboard := savedClipboard

    callCount++
    UpdateAllWidgetsDisplay()
}


; ==============================================================================
;                         4. НАСТРОЙКИ И ПЕРЕКЛЮЧЕНИЕ РЕЖИМОВ
; ==============================================================================

; End всегда переводит скрипт в NORMAL: перехваченные клавиши вновь передаются
; активной программе как обычно, а автоматизации временно не выполняются.
~End::
{
    global currentMode
    if (currentMode != 0)
    {
        currentMode := 0
        UpdateModeIndicator()
        ToolTip("РЕЖИМ: NORMAL (Скрипты отключены)")
        SetTimer(() => ToolTip(), -1200)
    }
}

; F11 поочерёдно переключает два CRM-режима: BITRIX и SVERKA.
$F11::
{
    global currentMode, lastWorkMode

    if (currentMode != 2 && currentMode != 3)
        currentMode := 2
    else if (currentMode == 2)
        currentMode := 3
    else
        currentMode := 2

    lastWorkMode := currentMode
    UpdateModeIndicator()
    ToolTip("РЕЖИМ: " . (currentMode == 2 ? "BITRIX" : "SVERKA"))
    SetTimer(() => ToolTip(), -1200)
}


; F12 циклически переключает: SAP → Telegram → MicroSIP → SAP.
$F12::
{
    global currentMode, lastWorkMode

    ; Если был любой другой режим — сначала включается SAP.
    if (currentMode != 5 && currentMode != 4 && currentMode != 1)
        currentMode := 5
    else if (currentMode == 5)
        currentMode := 4
    else if (currentMode == 4)
        currentMode := 1
    else
        currentMode := 5

    lastWorkMode := currentMode
    UpdateModeIndicator()

    if (currentMode == 5)
        ToolTip("РЕЖИМ: SAP (F1 — повтор | F2 — номер | F3/F4 — текст)")
    else if (currentMode == 4)
        ToolTip("РЕЖИМ: TELEGRAM")
    else
        ToolTip("РЕЖИМ: MICROSIP")

    SetTimer(() => ToolTip(), -1500)
}


; F10 открывает форму изменения текстов статусов для существующих сценариев.
$F10::
{
    global statusF2, statusF3, statusF4, statusSverkaF2, statusSverkaF4
    
    settingsGui := Gui("+AlwaysOnTop", "Настройка статусов")
    settingsGui.SetFont("s10", "Segoe UI")

    settingsGui.Add("Text", "w280", "--- Статусы MICROSIP / TG ---")
    settingsGui.Add("Text", "w280", "F2:")
    inputF2 := settingsGui.Add("Edit", "w280 vF2Val", statusF2)
    settingsGui.Add("Text", "w280 y+5", "F3:")
    inputF3 := settingsGui.Add("Edit", "w280 vF3Val", statusF3)
    settingsGui.Add("Text", "w280 y+5", "F4:")
    inputF4 := settingsGui.Add("Edit", "w280 vF4Val", statusF4)

    settingsGui.Add("Text", "w280 y+10", "--- Статусы SVERKA ---")
    settingsGui.Add("Text", "w280", "F2 (Сверка):")
    inputSverkaF2 := settingsGui.Add("Edit", "w280 vSvF2Val", statusSverkaF2)
    settingsGui.Add("Text", "w280 y+5", "F4 (Сверка):")
    inputSverkaF4 := settingsGui.Add("Edit", "w280 vSvF4Val", statusSverkaF4)

    saveBtn := settingsGui.Add("Button", "w280 y+15 Default", "Сохранить")
    saveBtn.OnEvent("Click", SaveSettings)

    settingsGui.Show()

    ; Локальная функция окна настроек: считывает все поля формы в глобальные
    ; переменные статусов, закрывает окно и показывает подтверждение сохранения.
    SaveSettings(*)
    {
        global statusF2, statusF3, statusF4, statusSverkaF2, statusSverkaF4
        
        statusF2 := inputF2.Value
        statusF3 := inputF3.Value
        statusF4 := inputF4.Value
        statusSverkaF2 := inputSverkaF2.Value
        statusSverkaF4 := inputSverkaF4.Value

        settingsGui.Destroy()
        ToolTip("Статусы обновлены!")
        SetTimer(() => ToolTip(), -1200)
    }
}


; ==============================================================================
;                         5. ОСНОВНЫЕ РАБОЧИЕ КЛАВИШИ (F1 - F9)
; ==============================================================================

; F1 запускает действие, соответствующее активному режиму: в SAP повторно
; звонит по текущему номеру, а в остальных режимах сохраняет прежний сценарий.
$F1::
{
    global callCount, currentPhoneNum, currentMode
    if (currentMode == 0)
    {
        Send("{F1}")
        return
    }

    
    else if (currentMode == 4)
    {
        Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
        Sleep(30)
        Send("!{Tab}")
        Sleep(80)

        phone := SearchNextPhoneInTable(true)
        if (phone == "Error")
            return

        currentPhoneNum := phone
        ResetCallAttemptCounter()

        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(80)
        Send("{Ctrl Down}v{Ctrl Up}")
    }
    else if (currentMode == 1 || currentMode == 2 || currentMode == 3 || currentMode == 5)
    {
        if WinExist("ahk_exe microsip.exe")
            WinActivate("ahk_exe microsip.exe")

        callCount++
        UpdateAllWidgetsDisplay()

        Send("{Enter}")
        Sleep(30)
        Send("{Up}")
        Sleep(30)
        Send("{Enter}")
    }
}

; F2 выполняет второй сценарий режима: в SAP забирает выделенный номер и звонит,
; а в остальных режимах оставляет исходную обработку статуса/номера без изменений.
$F2::
{
    global currentPhoneNum, callCount, currentMode
    if (currentMode == 0)
    {
        Send("{F2}")
        return
    }

    if (currentMode == 5)
    {
        CallSelectedPhoneInSapMode()
        return
    }
    else if (currentMode == 1)
    {
        HandleSipCallFlow(statusF2)
    }
    else if (currentMode == 2)
    {
        A_Clipboard := ""
        Send("{Ctrl Down}c{Ctrl Up}")
        if !ClipWait(0.4)
            return

        phone := CleanAndFormatPhone(A_Clipboard, true)
        if (phone == "Error")
        {
            ToolTip("Ошибка номера!")
            SetTimer(() => ToolTip(), -1000)
            return
        }

        currentPhoneNum := CleanAndFormatPhone(phone, false)
        ResetCallAttemptCounter()

        if WinExist("ahk_exe Telegram.exe")
            WinActivate("ahk_exe Telegram.exe")
        
        Sleep(60)
        Send("{Escape 3}")
        Sleep(120)
        Send("^f")
        Sleep(120)
       
        Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
        Sleep(30)
        A_Clipboard := phone
        Send("{Ctrl Down}v{Ctrl Up}")
    }
    else if (currentMode == 3)
    {
        Send("{Enter}")
        Sleep(50)
        Send("!{Tab}")
        Sleep(100)

        Send("{Right}")
        Sleep(40)
        A_Clipboard := "boradi"
        Send("{Ctrl Down}v{Ctrl Up}")
        Sleep(40)
        Send("{Enter}")
        Sleep(50)
        Send("{Left}")
        Sleep(50)

        A_Clipboard := ""
        Send("{Ctrl Down}c{Ctrl Up}")
        if !ClipWait(0.4)
            return

        phone := CleanAndFormatPhone(A_Clipboard, false)
        if (phone == "Error")
            return

        currentPhoneNum := phone
        ResetCallAttemptCounter()
        callCount := 1
        UpdateAllWidgetsDisplay()

        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(100)
        Send("{Ctrl Down}a{Ctrl Up}")
        Sleep(30)
        Send("{Ctrl Down}v{Ctrl Up}{Enter}")
    }
    else if (currentMode == 4)
    {
        Send("{Home}")
        Sleep(30)
        Send("{Delete 3}")
    }
}
$F3::
{
    global currentPhoneNum, callCount, currentMode, sapF3Text, statusF3

    if (currentMode == 0)
    {
        Send("{F3}")
        return
    }

    ; SAP: вставить имя сотрудника.
    if (currentMode == 5)
    {
        InsertSapText(sapF3Text)
        return
    }

    ; MicroSIP: прежний сценарий статуса F3.
    else if (currentMode == 1)
    {
        HandleSipCallFlow(statusF3)
    }

    ; Bitrix: очистить поиск Telegram.
    else if (currentMode == 2)
    {
        if WinExist("ahk_exe Telegram.exe")
            WinActivate("ahk_exe Telegram.exe")

        Sleep(40)
        Send("{Home}")
        Sleep(30)
        Send("{Delete 3}")
    }

    ; SVERKA: записать статус в клетку справа, перейти к следующему номеру и позвонить.
    else if (currentMode == 3)
    {
        ; Завершаем текущий звонок и возвращаемся в таблицу.
        Send("{Enter}")
        Sleep(50)
        Send("!{Tab}")
        Sleep(100)

        ; Переходим в ячейку статуса справа от номера.
        Send("{Right}")
        Sleep(50)

        ; Записываем «ko'tarmadi».
        A_Clipboard := statusF3
        Send("{Ctrl Down}v{Ctrl Up}")
        Sleep(40)

        ; Enter сохраняет статус. Затем возвращаемся к номеру следующей строки.
        Send("{Enter}{Up}{Left}{Down}")
        Sleep(60)

        ; Копируем следующий номер.
        A_Clipboard := ""
        Send("{Ctrl Down}c{Ctrl Up}")
        if !ClipWait(0.4)
            return

        phone := CleanAndFormatPhone(A_Clipboard, false)
        if (phone == "Error")
            return

        ; Для нового номера первая попытка — #1.
        currentPhoneNum := phone
        ResetCallAttemptCounter()
        callCount := 1
        UpdateAllWidgetsDisplay()

        ; Возвращаемся в MicroSIP и звоним.
        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(100)
        Send("{Ctrl Down}a{Ctrl Up}")
        Sleep(30)
        Send("{Ctrl Down}v{Ctrl Up}{Enter}")
    }

    ; Telegram: прежний поиск следующего номера.
    else if (currentMode == 4)
    {
        Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
        Sleep(30)
        Send("!{Tab}")
        Sleep(80)
        Send("{Down}")
        Sleep(30)

        phone := SearchNextPhoneInTable(true)
        if (phone == "Error")
            return

        currentPhoneNum := phone
        ResetCallAttemptCounter()

        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(80)
        Send("{Ctrl Down}v{Ctrl Up}")
    }
}

; F4 в SAP вводит текст о том, что с клиентом не удалось связаться; в остальных
; режимах обслуживает прежние сценарии звонка, статусов и Telegram.
$F4::
{
    global currentPhoneNum, callCount, currentMode, sapF4Text
    if (currentMode == 0)
    {
        Send("{F4}")
        return
    }

    if (currentMode == 5)
    {
        InsertSapText(sapF4Text)
        return
    }
    else if (currentMode == 1)
    {
        HandleSipCallFlow(statusF4)
    }
    else if (currentMode == 2)
    {
        if WinExist("ahk_exe Telegram.exe")
        {
            WinActivate("ahk_exe Telegram.exe")
            Sleep(40)
            Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
            Sleep(30)
        }

        if (currentPhoneNum == "---" || currentPhoneNum == "")
            return

        cleanSipPhone := CleanAndFormatPhone(currentPhoneNum, false)
        if (cleanSipPhone == "Error")
            return

        currentPhoneNum := cleanSipPhone

        if WinExist("ahk_exe microsip.exe")
            WinActivate("ahk_exe microsip.exe")

        Sleep(90)
        A_Clipboard := cleanSipPhone
        Send("{Ctrl Down}a{Ctrl Up}")
        Sleep(30)
        Send("{Ctrl Down}v{Ctrl Up}{Enter}")
        
        callCount := 1
        UpdateAllWidgetsDisplay()
    }
    else if (currentMode == 3)
    {
        Send("{Enter}")
        Sleep(50)
        Send("!{Tab}")
        Sleep(100)

        Send("{Right}")
        Sleep(40)
        A_Clipboard := "ko'chada"
        Send("{Ctrl Down}v{Ctrl Up}")
        Sleep(40)
        Send("{Enter}")
        Sleep(50)
        Send("{Left}")
        Sleep(50)

        A_Clipboard := ""
        Send("{Ctrl Down}c{Ctrl Up}")
        if !ClipWait(0.4)
            return

        phone := CleanAndFormatPhone(A_Clipboard, false)
        if (phone == "Error")
            return

        currentPhoneNum := phone
        ResetCallAttemptCounter()
        callCount := 1
        UpdateAllWidgetsDisplay()

        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(100)
        Send("{Ctrl Down}a{Ctrl Up}")
        Sleep(30)
        Send("{Ctrl Down}v{Ctrl Up}{Enter}")
    }
    else if (currentMode == 4)
    {
        Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
        Sleep(30)
        Send("!{Tab}")
        Sleep(80)

        Send("{Right}{Right}")
        Sleep(30)
        A_Clipboard := statusF4
        Send("{Ctrl Down}v{Ctrl Up}{Enter}{Up}{Left}{Left}{Down}")
        Sleep(30)

        phone := SearchNextPhoneInTable(true)
        if (phone == "Error")
            return

        currentPhoneNum := phone
        ResetCallAttemptCounter()

        A_Clipboard := phone
        Send("!{Tab}")
        Sleep(80)
        Send("{Ctrl Down}v{Ctrl Up}")
    }
}

; F6 закрывает окно MicroSIP, если оно запущено, и сообщает результат пользователю.
$F6::
{
    if (currentMode == 0)
    {
        Send("{F6}")
        return
    }

    if WinExist("ahk_exe microsip.exe")
    {
        WinClose("ahk_exe microsip.exe")
        ToolTip("MicroSIP закрыт")
    }
    else
    {
        ToolTip("MicroSIP не запущен")
    }

    SetTimer(() => ToolTip(), -1200)
}

; F7 переносит номер из буфера в Telegram либо выполняет специальный шаг сверки.
$F7::
{
    global currentPhoneNum
    if (currentMode == 0)
    {
        Send("{F7}")
        return
    }
    else if (currentMode == 3)
    {
        Send("{Ctrl Down}c{Ctrl Up}")
        Sleep(50)
        Send("!{Tab}")
        Sleep(80)
        Send("{Down}")
        Sleep(100)
        Send("{Ctrl Down}v{Ctrl Up}")
        Sleep(50)
        Send("!{Tab}")
        Sleep(80)
        Send("{Down}")
        return
    }
    else
    {
        rawText := A_Clipboard
        phone := CleanAndFormatPhone(rawText, true)
        if (phone == "Error")
        {
            ToolTip("В буфере нет корректного номера!")
            SetTimer(() => ToolTip(), -1000)
            return
        }

        currentPhoneNum := CleanAndFormatPhone(phone, false)
        ResetCallAttemptCounter()

        if WinExist("ahk_exe Telegram.exe")
            WinActivate("ahk_exe Telegram.exe")

        Sleep(60)
        Send("{Escape 3}")
        Sleep(80)
        Send("^f")
        Sleep(100)
        Send("{Ctrl Down}a{Ctrl Up}{Backspace}")
        Sleep(30)
        A_Clipboard := phone
        Send("{Ctrl Down}v{Ctrl Up}")
    }
}

; F8 вставляет данные в режиме сверки или очищает поле поиска Telegram.
$F8::
{
    if (currentMode == 0)
    {
        Send("{F8}")
        return
    }
    else if (currentMode == 3)
    {
        Send("{Ctrl Down}v{Ctrl Up}")
        Sleep(30)
    }
    else
    {
        if WinExist("ahk_exe Telegram.exe")
            WinActivate("ahk_exe Telegram.exe")

        Sleep(40)
        Send("{Home}")
        Sleep(30)
        Send("{Delete 3}")
    }
}

; F9 после явного подтверждения закрывает рабочие программы для подготовки к сверке.
$F9::
{
    if (currentMode == 0)
    {
        Send("{F9}")
        return
    }

    ToolTip("⚠️ ЗАКРЫТЬ лишние программы для сверки?`n[ ENTER ] — Закрыть | [ ESC / жди 3с ] — Отмена")
    
    ih := InputHook("L1 T3", "{Enter}{Escape}")
    ih.Start()
    ih.Wait()

    ToolTip()

    if (ih.EndKey != "Enter")
    {
        ToolTip("Отменено")
        SetTimer(() => ToolTip(), -800)
        return
    }

    SetTitleMatchMode(2)

    targetKeywords := ["Bitrix", "Битрикс", "SAP", "sap"]
    for kw in targetKeywords
    {
        while WinExist(kw . " ahk_exe chrome.exe")
        {
            WinClose()
            Sleep(40)
        }
    }

    otherProcesses := [
        "microsip.exe",
        "Telegram.exe",
        "CalculatorApp.exe",
        "calc.exe"
    ]

    for proc in otherProcesses
    {
        while ProcessExist(proc)
        {
            ProcessClose(proc)
            Sleep(20)
        }
    }

    ToolTip("✅ Рабочее место очищено, музыка осталась!")
    SetTimer(() => ToolTip(), -1200)
}


; ==============================================================================
;                         6. СИСТЕМНЫЕ И ДОПОЛНИТЕЛЬНЫЕ КЛАВИШИ
; ==============================================================================

; Volume Mute фиксирует завершённый звонок как продажу и увеличивает дневной счётчик.
$Volume_Mute::
{
    global currentMode, todayKey, todaySales, iniFile
    if (currentMode == 0)
    {
        Send("{Volume_Mute}")
        return
    }
    
    Sleep(250)
    Send("#{1}")
    Sleep(250)
    Send("{Enter}")

    currentDay := FormatTime(A_Now, "yyyy-MM-dd")
    if (currentDay != todayKey)
    {
        todayKey := currentDay
        todaySales := IniRead(iniFile, "DailySales", todayKey, 0)
    }

    todaySales++
    IniWrite(todaySales, iniFile, "DailySales", todayKey)
    UpdateAllWidgetsDisplay()

    ToolTip("Звонок завершен! Продаж сегодня: " . todaySales)
    SetTimer(() => ToolTip(), -1200)
    Sleep(300)
    Send("#{3}")
}

; PrintScreen отменяет одну продажу, не позволяя счётчику стать отрицательным.
$PrintScreen::
{
    global currentMode, todayKey, todaySales, iniFile

    if (currentMode == 0)
    {
        Send("{PrintScreen}")
        return
    }

    currentDay := FormatTime(A_Now, "yyyy-MM-dd")
    if (currentDay != todayKey)
    {
        todayKey := currentDay
        todaySales := IniRead(iniFile, "DailySales", todayKey, 0)
    }

    if (todaySales > 0)
    {
        todaySales--
        IniWrite(todaySales, iniFile, "DailySales", todayKey)
        UpdateAllWidgetsDisplay()
        ToolTip("Отмена продажи (-1). Продаж сегодня: " . todaySales)
    }
    else
    {
        ToolTip("Продажи уже на нуле: 0")
    }

    SetTimer(() => ToolTip(), -1200)
}

; Медиа- и дополнительные клавиши открывают Telegram и запускают прежний сценарий
; поиска/передачи номера из буфера обмена.
$Launch_Media::
$Launch_App1::
$Launch_App2::
{
    rawText := A_Clipboard
    cleanNum := RegExReplace(rawText, "\D", "")

    if (cleanNum == "")
    {
        ToolTip("Буфер пуст или нет цифр!")
        SetTimer(() => ToolTip(), -1000)
        return
    }

    if (StrLen(cleanNum) >= 10)
        cleanNum := SubStr(cleanNum, -9)

    if WinExist("ahk_exe Telegram.exe")
        WinActivate("ahk_exe Telegram.exe")
    else
        return

    Sleep(80)
    Send("{Escape 3}")
    Sleep(80)
    Send("{Down 2}{Enter}")
    Sleep(250)
    Send("{Down}")
    Sleep(60)
    SendInput(cleanNum . " ")
    Sleep(200)
    Send("^#{Right}")
}

; Browser Home закрывает текущую вкладку и переключает виртуальный рабочий стол влево.
$Browser_Home::
{
    Send("^w")
    Sleep(50)
    Send("^#{Left}")
}

; Volume Down переключает Windows на рабочий стол слева.
$Volume_Down::
{
    Send("^#{Left}")
}

; Volume Up переключает Windows на рабочий стол справа.
$Volume_Up::
{
    Send("^#{Right}")
}

; Insert строит окно со столбчатой статистикой продаж за последние десять дней.
$Insert::
{
    global iniFile, todaySales, todayKey
    
    salesData := ""
    try {
        salesData := IniRead(iniFile, "DailySales",, "")
    }
    
    chartGui := Gui("+AlwaysOnTop", "Статистика продаж по дням")
    chartGui.BackColor := "FFFFFF"

    chartGui.SetFont("s12 bold", "Segoe UI")
    chartGui.Add("Text", "w420 Center c0066CC +0x200", "ГРАФИК ПРОДАЖ ПО ДНЯМ")

    chartGui.SetFont("s10 norm", "Segoe UI")
    chartGui.Add("Text", "w420 Center c777777", "Сегодня (" . todayKey . "): " . todaySales . " продаж")
    chartGui.Add("Text", "w420 0x10 y+8")

    dateList := []
    maxVal := 1
    foundToday := false

    if (salesData != "")
    {
        for line in StrSplit(salesData, "`n", "`r")
        {
            if (line == "" || !InStr(line, "="))
                continue
            parts := StrSplit(line, "=")
            dStr := Trim(parts[1])
            vNum := Integer(Trim(parts[2]))
            dateList.Push({date: dStr, val: vNum})
            if (dStr == todayKey)
                foundToday := true
            if (vNum > maxVal)
                maxVal := vNum
        }
    }

    if (!foundToday)
    {
        dateList.Push({date: todayKey, val: todaySales})
        if (todaySales > maxVal)
            maxVal := todaySales
    }

    startIndex := (dateList.Length > 10) ? dateList.Length - 9 : 1

    Loop (dateList.Length - startIndex + 1)
    {
        idx := startIndex + A_Index - 1
        item := dateList[idx]
        
        barW := Integer((item.val / maxVal) * 200)
        if (barW < 4 && item.val > 0)
            barW := 4

        chartGui.SetFont("s10 norm", "Segoe UI")
        chartGui.Add("Text", "w85 y+8 c333333", item.date)
        
        if (item.val > 0)
            chartGui.Add("Progress", "x+5 w" . barW . " h18 BackgroundE0E0E0 c008800 Range0-100", 100)
        else
            chartGui.Add("Text", "x+5 w10 h18 c999999", "-")
            
        chartGui.SetFont("s10 bold", "Segoe UI")
        chartGui.Add("Text", "x+10 h18 c000000", item.val)
    }

    chartGui.SetFont("s10 norm", "Segoe UI")
    closeBtn := chartGui.Add("Button", "w120 x160 y+20 Default", "Закрыть")
    closeBtn.OnEvent("Click", (*) => chartGui.Destroy())

    chartGui.Show()
}


$PgDn::{
    Send("#r")
    Sleep(120)
    SendText("cmd")
    Sleep(120)
    Send("{Enter}")

}

; Scroll Lock с подтверждением закрывает перечисленные программы и инициирует
; выключение компьютера; Escape или повторный Scroll Lock отменяют операцию.
$ScrollLock::
{
    ToolTip("⚠️ ВНИМАНИЕ! Нажмите ENTER для ЗАКРЫТИЯ ПРОГРАММ И ВЫКЛЮЧЕНИЯ ПК (Escape для отмены)")
    
    loop
    {
        if KeyWait("Enter", "D T 5")
        {
            ToolTip()
            break
        }
        else if KeyWait("Escape", "D") || KeyWait("ScrollLock", "D")
        {
            ToolTip("Отменено.")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        else
        {
            ToolTip()
            return
        }
    }

    ToolTip("Закрытие всех программ...")
    
    killList := [
        "sublime_text.exe",
        "microsip.exe",
        "Telegram.exe",
        "chrome.exe",
        "browser.exe",
        "calc.exe",
        "CalculatorApp.exe",
        "wps.exe",
        "et.exe",
        "excel.exe"
    ]

    for proc in killList
    {
        while ProcessExist(proc)
        {
            ProcessClose(proc)
            Sleep(50)
        }
    }

    ToolTip("Выключение компьютера...")
    Send("#d")
    Sleep(500)
    WinActivate("ahk_class Progman") 
    Sleep(200)
    Click(10, 10)
    Sleep(300)
    Send("!{F4}")
    Sleep(1000)
    Send("{Enter}")
    ToolTip()
}


; ==============================================================================
;        7. УМНАЯ КЛАВИША Ё / ТИЛЬДА (SC029) - МЕГА КОМБО РОБОТ И ПАУЗА МУЗЫКИ
; ==============================================================================
; Ё/тильда: в русском языке вводит символ, в SVERKA управляет музыкой, а в
; английской раскладке запускает существующий сценарий отправки заказа в Telegram.
$*SC029::
{
    global currentMode

    ; Режим 0: обычный ввод символа
    if (currentMode == 0)
    {
        Send("{Blind}{SC029}")
        return
    }

    ; Режим 3: переключение Play/Pause
    if (currentMode == 3)
    {
        Send("{Media_Play_Pause}")
        return
    }

    ; Получаем точный код языка раскладки активного окна
    activeHwnd := WinExist("A")
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", activeHwnd, "Ptr", 0, "UInt")
    layoutId := DllCall("GetKeyboardLayout", "UInt", threadId, "UPtr")
    langId := layoutId & 0xFFFF

    ; Если русская раскладка (0x0419) -> строго печатаем букву "ё"
    if (langId == 0x0419)
    {
        if GetKeyState("Shift", "P")
            SendText("Ё")
        else
            SendText("ё")
        return
    }

    ; --- ДАЛЕЕ КОД ВЫПОЛНЯЕТСЯ ТОЛЬКО НА АНГЛИЙСКОЙ РАСКЛАДКЕ ---
    
    ; 1. Копируем выделенный текст (от Склада до Цены)
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(0.4)
    {
        ToolTip("Ничего не выделено! Выдели строку.")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    rawText := Trim(A_Clipboard)
    rawText := RegExReplace(rawText, "[\r\n\t]+", " ") 

    if RegExMatch(rawText, "i)^(.*?\d+\s*шт)", &mFirstRow)
        rawText := mFirstRow[1]

    ; Проверка остатка
    if RegExMatch(rawText, "i)(\d+)\s*шт", &mQty)
    {
        qty := Integer(mQty[1])
        if (qty < 4)
        {
            ToolTip("❌ ОШИБКА! Там меньше 4 шт! (Остаток: " . qty . " шт)")
            SetTimer(() => ToolTip(), -3000)
            return
        }
    }

    ; Парсинг филиала
    rawBranch := ""
    if RegExMatch(rawText, "i)^(.*?)(?=SHN\d)", &mBranch)
        rawBranch := Trim(mBranch[1])

    branchExceptions := Map(
        "TS - Tashkent-Sergeli1", "Sergili call center",
        "S2 - ASKO Sergeli2", "SERGELI 2",
        "YD - ASKO Yashnaobod", "YASHNOBOD CALL CENTRE",
        "FD - ASKO Farhadskiy", "FARHADSKIY CALL CENTRE",
        "SZ - ASKO Shofayzi", "SHOFAYZ CALLCENTR",
        "YD2 - ASKO Yunusobod", "YUNUSOBOD CALL CENTR",
        "Y2 - ASKO Yunusobod 2", "Yunusobot _2 Call centr",
        "BR - ASKO Bektemir", "BEKTEMIR call center",
        "KE - ASKO Keles", "Keles Asko",
        "NK - ASKO Nazarbek", "NAZARBEK ASKO",
        "MT - ASKO Mehnat", "MEHNAT ASKO",
        "OL - ASKO Olmaliq", "OLMALIQ CALL CENTRE",
        "OL2 - ASKO Olmaliq 2", "Olmaliq 2 Premium Call Centre",
        "BD - ASKO Bekobod", "BEKOBOD CALL CENTRE",
        "ON - ASKO Oqqo'rg'on", "Oqqorg’on call centr",
        "YL - ASKO Yangiyol", "YANGIYOL call centre",
        "BK - ASKO Boka", "BOKA CALL CENTRE",
        "QY - ASKO Qibray", "Qibray call center N1",
        "YB - ASKO Yangibozor", "Yangi bozor cal markaz",
        "GT - ASKO Gazalkent", "GAZALKENT ASKO",
        "QV - Asko Qorasuv", "Qorasuv Asko",
        "CQ - ASKO Chirchiq", "Chirchiq Call Centr",
        "PS - ASKO Piskent", "Asko Piskent",
        "PT - ASKO Parkent", "Parkent call center",
        "AR - ASKO Angren", "Angren call center",
        "OH - ASKO Ohangaron", "Ohangaron call center",
        "BO - ASKO Buxoro", "Buxoro call center",
        "QL - ASKO Qorakol", "QORAKO'L ASKO",
        "SHK - ASKO Shofirkon", "SHOFAYZ CALLCENTR",
        "GJ - ASKO Gijduvon", "GIJDUVON ASKO CALL CENTER",
        "QA - ASKO Qiziltepa", "Qiziltepa Navoiy Call centr",
        "ND - ASKO Darxon", "Navoiy-3 filiali CALL SENTR Darxon bozori,",
        "ZN - ASKO Zarafshan", "Zarafshon Navoiy Call centr",
        "NA - ASKO Navoi", "Navoi-1 CallCenter",
        "XI - ASKO Xatirchi", "Xatirchi CALL CENTRE",
        "QR - ASKO Qarshi", "Qarshi Call-Centr",
        "QR2 - ASKO Qarshi 2", "QARSHI 2 FILIAL",
        "SS - ASKO Shahrisabz", "SHAXRISABZ",
        "KS - ASKO Koson", "Koson QARSHI Call centr",
        "TR - ASKO Termiz", "Termiz-1 call center",
        "TR2 - ASKO Termiz2", "Termiz 2 Call sentr",
        "DV - ASKO Denov", "DENOV CALL CENTRE",
        "QN - ASKO Qumqorg'on", "QUMQO'RGON ASKO",
        "SH - ASKO Sherobod", "SHEROBOD ASKO",
        "JN - ASKO Jarqo'rg'on", "JARQORGON TERMIZ CALL SENTR",
        "KQ - ASKO Kattaqo'rg'on", "KATTAQURGON CALL CENTRE",
        "SD - ASKO Samarkand", "Samarqand call center",
        "UR - ASKO Urgut", "URGUT CALL CENTRE",
        "SD2 - ASKO Samarqand2", "SAMARQAND 2 FILIAL",
        "JA - ASKO Juma", "JUMA CALL SENTR SAMARQAND Pastdarg‘om",
        "CK - ASKO Chelak", "Chelak call sentr",
        "MR - ASKO Mirbozor", "Mirbozor filiali",
        "IN - ASKO Ishtixon", "ISHTIXON SAMARQAND CALL SENTR",
        "NU - ASKO Nukus", "NUKUS CALL CENTRE",
        "XA - ASKO Xonqa", "XONQA ASKO",
        "UC - ASKO Urganch", "XORAZM - URGANCH CALL CENTRE",
        "JX - ASKO Jizzax", "Jizzax-1 call center",
        "GL - ASKO Gallarol", "GALLAOROL CALL CENTRE",
        "JX2 - ASKO Jizzax 2", "ASKO Jizzax-2 filiali",
        "PR - ASKO Paxtakor", "PAXTAKOR JIZZAX CALL SENTR",
        "GN - ASKO Guliston", "Guliston call center",
        "YR - Asko-Yangiyer", "Yangiyer call center",
        "BQ - ASKO Beshariq", "Fargona Beshariq Call Sentr",
        "RN - ASKO Rishton", "Rishton CALL SENTR",
        "BG - ASKO Bagdod", "Bog'dod call centr",
        "VY - ASKO Vodiy", "Dang’ara Vodiy Asko",
        "FA - ASKO Fargona", "Fargona (Davr) to’yxona",
        "SN - ASKO Shaxrixon", "Andijon SHAXRIXON Call sentr",
        "JQ - ASKO Jalaquduq", "Jalaquduq call center",
        "QG - ASKO Qorgontepa", "QORGONTEPA ASKO",
        "BL - ASKO Bogishamol", "BOGISHAMOL ASKO",
        "AN - ASKO Andijon", "Angren call center",
        "AN2 - ASKO Andijon 80-metr", "Andijon 80m",
        "AA - ASKO Asaka", "ASAKA ASKO",
        "CHN - ASKO Chinobod", "CHINOBOD CALL CENTR",
        "PP - ASKO Pop", "CALL SENTR, POP,",
        "CT2 - ASKO Chust", "Chust filiali CALL SENTR"
    )

    tgGroupName := ""
    if branchExceptions.Has(rawBranch)
        tgGroupName := branchExceptions[rawBranch]
    else
    {
        tgGroupName := RegExReplace(rawBranch, "i)^[A-Z0-9]+\s*-\s*(asko[-\s]*|)", "")
        tgGroupName := Trim(tgGroupName)
    }

    cleanName := ""
    if RegExMatch(rawText, "i)SHN\d+\s*(.*?\d{2,3}/\d{2,3}/\d{2,3})", &mName)
        cleanName := Trim(mName[1])

    textForPrice := RegExReplace(rawText, "[\d\s]*\d{2,3}/\d{2,3}/\d{2,3}", " ")
    priceClean := ""
    
    if RegExMatch(textForPrice, "i)(\d[\d\s]*?)\s*UZS", &mPrice)
    {
        priceRaw := RegExReplace(mPrice[1], "\D", "") 
        if (StrLen(priceRaw) >= 4)
            priceClean := SubStr(priceRaw, 1, StrLen(priceRaw) - 3)
        else
            priceClean := priceRaw
    }

    if (priceClean == "" || cleanName == "" || tgGroupName == "")
    {
        ToolTip("❌ Ошибка парсинга! Выдели от Склада до Цены.")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; КАЛЬКУЛЯТОР (Стол 4)
    Send("#{4}")
    Sleep(250)
    Send("{Escape}") 
    Sleep(50)
    
    A_Clipboard := priceClean
    Send("^v")
    Sleep(60)
    Send("*4{Enter}")
    Sleep(200)

    ; ТЕЛЕГРАМ (Стол 3)
    Sleep(150)
    
    ; Переходим со Стола 4 на Стол 3
    Send("^#{Left}")
    Sleep(250)

    ; Активируем Telegram напрямую, чтобы не перебивало
    Send("#{2}")
    Sleep(300)

    ; 1. Встаем в самый конец уже напечатанного номера
    Send("{End}")
    Sleep(60)

    ; 2. Добавляем пробел, название товара и хэштег ПОСЛЕ номера
    A_Clipboard := "  " . cleanName . " #Abdulloh"
    Send("^v")
    Sleep(120)

    ; 3. Выделяем всю строку, копируем и отправляем клиенту
    Send("^a")
    Sleep(60)
    Send("^c")
    ClipWait(0.3)
    Send("{Enter}")
    Sleep(200)

    ; 4. Сбрасываем фокус и вызываем ГЛОБАЛЬНЫЙ поиск чатов (Ctrl+J) - он не откроет внутричатовый поиск!
    Send("{Escape 2}")
    Sleep(100)
    Send("^f")
    Sleep(250)
    Send("^a{Backspace}")
    Sleep(60)

    ; 5. Вбиваем имя филиала и заходим в группу
    SendText(tgGroupName)
    Sleep(650)
    Send("{Down}")
    Sleep(100)
    Send("{Enter}")
    Sleep(300)

    ; 6. Вставляем скопированное сообщение в найденную группу и отправляем
    Send("^v")
    Sleep(120)
    Send("{Enter}")
    Sleep(200)

    ; ВОЗВРАТ В CRM (на Стол 4)
    Send("^#{Right}")

    ToolTip("✅ Готово! Отправлено клиенту и в " . tgGroupName)
    SetTimer(() => ToolTip(), -3000)
}
