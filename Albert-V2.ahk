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

; ==============================================================================
;                         СИСТЕМА АНАЛИТИКИ
; ==============================================================================

; Буферизированный журнал. Запись на диск идёт в фоне, чтобы хоткеи
; не зависели от скорости файловой системы.
global statsLogFile := A_ScriptDir . "\activity_log.txt"
global statsLogBuffer := ""
global statsLogPending := 0

; Состояние текущего звонка.
global statsCallActive := false
global statsCallAnswered := false
global statsCallPhone := ""
global statsCallStartedTick := 0
global statsCallAnsweredTick := 0
global statsCallAttempt := 0
global statsCallMode := 0

; F9 использует Escape как отмену подтверждения.
global statsIgnoreEsc := false

; Переменные для защиты от мерцания виджетов
global widgetsVisible := false 
global lastSipX := -1
global lastSipY := -1

ToolTip("Режим: BITRIX (F12: SAP | F11: Режимы | End: Normal)")
SetTimer(() => ToolTip(), -3000)

; Статистика записывается в фоне, без I/O на каждом нажатии.
SetTimer(StatsFlushLog, 1000)
OnExit(StatsOnExit)
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

; ==============================================================================
;                         3.1. СИСТЕМА АНАЛИТИКИ
; ==============================================================================

StatsNormalizeKey(key)
{
    key := StrReplace(key, "$", "")
    key := StrReplace(key, "~", "")
    key := StrReplace(key, "*", "")
    return key
}


; Добавляет событие в RAM-буфер.
StatsQueueEvent(
    key,
    eventType,
    phone := "",
    duration := 0,
    detail := ""
)
{
    global statsLogBuffer, statsLogPending

    key := StatsNormalizeKey(key)

    phone := StrReplace(phone, "|", "")
    detail := StrReplace(detail, "|", "")

    timestamp := FormatTime(
        A_Now,
        "yyyy-MM-dd HH:mm:ss"
    )

    date := FormatTime(
        A_Now,
        "yyyy-MM-dd"
    )

    time := FormatTime(
        A_Now,
        "HH:mm:ss"
    )

    modeName := StatsGetModeName()

    line :=
        timestamp
        . "|" . date
        . "|" . time
        . "|" . modeName
        . "|" . key
        . "|" . eventType
        . "|" . phone
        . "|" . duration
        . "|" . detail
        . "`n"

    statsLogBuffer .= line
    statsLogPending++

    if (statsLogPending >= 20)
        StatsFlushLog()
}


StatsFlushLog(*)
{
    global statsLogFile, statsLogBuffer, statsLogPending

    if (statsLogBuffer == "")
        return

    try
    {
        FileAppend(
            statsLogBuffer,
            statsLogFile,
            "UTF-8"
        )

        statsLogBuffer := ""
        statsLogPending := 0
    }
    catch
    {
        ; Ошибка журнала не должна ломать рабочую часть скрипта.
    }
}


StatsOnExit(exitReason, exitCode)
{
    StatsCloseCurrentCall()
    StatsFlushLog()
}


StatsGetModeName()
{
    global currentMode

    switch currentMode
    {
        case 0:
            return "NORMAL"
        case 1:
            return "MICROSIP"
        case 2:
            return "BITRIX"
        case 3:
            return "SVERKA"
        case 4:
            return "TELEGRAM"
        case 5:
            return "SAP"
        default:
            return "UNKNOWN"
    }
}


StatsTrackButton(key)
{
    global currentMode

    if (currentMode == 0)
        return

    StatsQueueEvent(
        key,
        "BUTTON"
    )
}


StatsSamePhone(a, b)
{
    if (
        a == ""
        || b == ""
        || a == "---"
        || b == "---"
    )
        return false

    a := RegExReplace(a, "\D", "")
    b := RegExReplace(b, "\D", "")

    if (a == "" || b == "")
        return false

    if (StrLen(a) >= 9)
        a := SubStr(a, -8)

    if (StrLen(b) >= 9)
        b := SubStr(b, -8)

    return a == b
}


; Запускает новую попытку или считает F1/Redial повторной попыткой
; того же самого клиента.
StatsBeginOrRetryCall(
    key := "UNKNOWN",
    phone := ""
)
{
    global statsCallActive
    global statsCallPhone
    global statsCallAttempt
    global statsCallAnswered
    global statsCallStartedTick
    global statsCallAnsweredTick

    ; Тот же номер = новая попытка. Предыдущая попытка получает
    ; окончательный результат NO_ANSWER, после чего запускается новый CALL_STARTED.
    if (
        statsCallActive
        && StatsSamePhone(
            statsCallPhone,
            phone
        )
    )
    {
        nextAttempt := statsCallAttempt + 1

        StatsFinishCall(
            "NO_ANSWER",
            "RETRY"
        )

        ; Возвращаем номер и номер попытки для новой записи.
        statsCallPhone := phone
        statsCallActive := true
        statsCallAnswered := false
        statsCallStartedTick := A_TickCount
        statsCallAnsweredTick := 0
        statsCallAttempt := nextAttempt

        StatsQueueEvent(
            key,
            "CALL_RETRY",
            phone,
            0,
            "attempt=" . nextAttempt
        )

        StatsQueueEvent(
            key,
            "CALL_STARTED",
            phone,
            0,
            "attempt=" . nextAttempt
        )

        return
    }

    StatsStartCall(
        key,
        phone
    )
}


StatsStartCall(
    key := "UNKNOWN",
    phone := ""
)
{
    global statsCallActive
    global statsCallAnswered
    global statsCallPhone
    global statsCallStartedTick
    global statsCallAnsweredTick
    global statsCallAttempt
    global statsCallMode
    global currentMode

    if (statsCallActive)
    {
        if (statsCallAnswered)
        {
            StatsFinishCall(
                "ANSWERED",
                "NEXT_CALL"
            )
        }
        else
        {
            StatsFinishCall(
                "NO_ANSWER",
                "NEXT_CALL"
            )
        }
    }

    statsCallActive := true
    statsCallAnswered := false
    statsCallPhone := phone
    statsCallStartedTick := A_TickCount
    statsCallAnsweredTick := 0
    statsCallAttempt := 1
    statsCallMode := currentMode

    StatsQueueEvent(
        key,
        "CALL_STARTED",
        phone,
        0,
        "attempt=1"
    )
}


StatsMarkClientAnswered(
    key := "Telegram",
    phone := ""
)
{
    global statsCallActive
    global statsCallAnswered
    global statsCallPhone
    global statsCallStartedTick
    global statsCallAnsweredTick

    if (!statsCallActive)
        return false

    if (
        phone != ""
        && statsCallPhone != ""
        && statsCallPhone != "---"
        && !StatsSamePhone(
            statsCallPhone,
            phone
        )
    )
        return false

    if (statsCallAnswered)
        return true

    statsCallAnswered := true
    statsCallAnsweredTick := A_TickCount

    responseSeconds := Round(
        (statsCallAnsweredTick - statsCallStartedTick) / 1000
    )

    StatsQueueEvent(
        key,
        "CLIENT_ANSWERED",
        statsCallPhone,
        responseSeconds
    )

    return true
}


StatsFinishCall(
    result := "",
    detail := ""
)
{
    global statsCallActive
    global statsCallAnswered
    global statsCallPhone
    global statsCallStartedTick
    global statsCallAnsweredTick
    global statsCallAttempt
    global statsCallMode

    if (!statsCallActive)
        return

    durationSeconds := Round(
        (A_TickCount - statsCallStartedTick) / 1000
    )

    if (result == "")
    {
        if (statsCallAnswered)
            result := "ANSWERED"
        else
            result := "NO_ANSWER"
    }

    detailText :=
        result
        . ";attempt="
        . statsCallAttempt

    if (detail != "")
        detailText .= ";" . detail

    StatsQueueEvent(
        "CALL",
        "CALL_RESULT",
        statsCallPhone,
        durationSeconds,
        detailText
    )

    statsCallActive := false
    statsCallAnswered := false
    statsCallPhone := ""
    statsCallStartedTick := 0
    statsCallAnsweredTick := 0
    statsCallAttempt := 0
    statsCallMode := 0
}


StatsCloseCurrentCall()
{
    global statsCallActive, statsCallAnswered

    if (!statsCallActive)
        return

    if (statsCallAnswered)
        StatsFinishCall("ANSWERED", "MODE_EXIT")
    else
        StatsFinishCall("NO_ANSWER", "MODE_EXIT")
}


StatsValidDate(dateText)
{
    return RegExMatch(
        dateText,
        "^\d{4}-\d{2}-\d{2}$"
    )
}


StatsDateAdd(dateText, days)
{
    if !StatsValidDate(dateText)
        return dateText

    raw := StrReplace(
        dateText,
        "-",
        ""
    ) . "000000"

    try
    {
        return FormatTime(
            DateAdd(
                raw,
                days,
                "Days"
            ),
            "yyyy-MM-dd"
        )
    }
    catch
    {
        return dateText
    }
}


StatsNormalizePhone(phone)
{
    clean := RegExReplace(
        phone,
        "\D",
        ""
    )

    if (StrLen(clean) >= 9)
        return SubStr(clean, -8)

    return clean
}


BuildDailyAnalytics(selectedDate)
{
    global statsLogFile, iniFile

    stats := {
        calls: 0,
        answered: 0,
        noAnswer: 0,
        sales: 0,
        cancelledSales: 0,
        retries: 0,

        totalCallSeconds: 0,
        totalResponseSeconds: 0,
        idleSeconds: 0,
        activeSpanSeconds: 0,
        averageInterCallSeconds: 0,

        buttons: Map(),
        uniqueClients: Map(),
        repeatClients: Map(),
        answeredClients: Map(),

        hourlyCalls: [],
        hourlyAnswered: [],
        hourlySales: [],

        firstAction: "",
        lastAction: "",

        busiestHour: -1,
        busiestHourCount: 0,

        bestSalesHour: -1,
        bestSalesHourCount: 0
    }

    Loop 24
    {
        stats.hourlyCalls.Push(0)
        stats.hourlyAnswered.Push(0)
        stats.hourlySales.Push(0)
    }

    ; Сбрасываем свежий буфер перед чтением журнала.
    StatsFlushLog()

    ; Для продаж сохраняем совместимость со старым DailySales.
    try
    {
        stats.sales := Integer(
            IniRead(
                iniFile,
                "DailySales",
                selectedDate,
                0
            )
        )
    }
    catch
    {
        stats.sales := 0
    }

    logText := ""

    try
    {
        if FileExist(statsLogFile)
            logText := FileRead(
                statsLogFile,
                "UTF-8"
            )
    }
    catch
    {
        return stats
    }

    if (logText == "")
        return stats

    lastActionTimestamp := ""
    lastCallTimestamp := ""

    interCallTotal := 0
    interCallCount := 0

    for line in StrSplit(
        logText,
        "`n",
        "`r"
    )
    {
        if (Trim(line) == "")
            continue

        parts := StrSplit(
            line,
            "|"
        )

        if (parts.Length < 9)
            continue

        timestamp := parts[1]
        date := parts[2]
        time := parts[3]
        key := parts[5]
        eventType := parts[6]
        phone := parts[7]
        durationText := parts[8]
        detail := parts[9]

        if (date != selectedDate)
            continue

        if (stats.firstAction == "")
            stats.firstAction := timestamp

        stats.lastAction := timestamp

        ; Простой: больше 5 минут без зарегистрированных рабочих действий.
        if (lastActionTimestamp != "")
        {
            try
            {
                gap := DateDiff(
                    timestamp,
                    lastActionTimestamp,
                    "Seconds"
                )

                if (gap > 300)
                    stats.idleSeconds += gap
            }
            catch
            {
            }
        }

        lastActionTimestamp := timestamp

        try
        {
            hourIndex := Integer(
                SubStr(time, 1, 2)
            ) + 1
        }
        catch
        {
            hourIndex := 1
        }

        if (hourIndex < 1 || hourIndex > 24)
            hourIndex := 1

        ; --------------------------------------------------------
        ; КНОПКИ
        ; --------------------------------------------------------

        if (eventType == "BUTTON")
        {
            if !stats.buttons.Has(key)
                stats.buttons[key] := 0

            stats.buttons[key]++
        }

        ; --------------------------------------------------------
        ; ЗВОНОК
        ; --------------------------------------------------------

        else if (eventType == "CALL_STARTED")
        {
            stats.calls++
            stats.hourlyCalls[hourIndex]++

            if (lastCallTimestamp != "")
            {
                try
                {
                    gap := DateDiff(
                        timestamp,
                        lastCallTimestamp,
                        "Seconds"
                    )

                    if (gap >= 0)
                    {
                        interCallTotal += gap
                        interCallCount++
                    }
                }
                catch
                {
                }
            }

            lastCallTimestamp := timestamp

            normalizedPhone :=
                StatsNormalizePhone(phone)

            if (normalizedPhone != "")
            {
                if !stats.uniqueClients.Has(
                    normalizedPhone
                )
                    stats.uniqueClients[normalizedPhone] := 0

                stats.uniqueClients[normalizedPhone]++

                if (
                    stats.uniqueClients[normalizedPhone] > 1
                )
                {
                    stats.repeatClients[
                        normalizedPhone
                    ] := stats.uniqueClients[
                        normalizedPhone
                    ]
                }
            }
        }

        ; --------------------------------------------------------
        ; ОТВЕТ
        ; --------------------------------------------------------

        else if (eventType == "CLIENT_ANSWERED")
        {
            stats.answered++
            stats.hourlyAnswered[hourIndex]++

            try
            {
                stats.totalResponseSeconds +=
                    Integer(durationText)
            }
            catch
            {
            }

            normalizedPhone :=
                StatsNormalizePhone(phone)

            if (normalizedPhone != "")
                stats.answeredClients[
                    normalizedPhone
                ] := 1
        }

        ; --------------------------------------------------------
        ; ПОВТОР
        ; --------------------------------------------------------

        else if (eventType == "CALL_RETRY")
        {
            stats.retries++
        }

        ; --------------------------------------------------------
        ; РЕЗУЛЬТАТ
        ; --------------------------------------------------------

        else if (eventType == "CALL_RESULT")
        {
            try
            {
                stats.totalCallSeconds +=
                    Integer(durationText)
            }
            catch
            {
            }

            if InStr(
                detail,
                "NO_ANSWER"
            )
                stats.noAnswer++

            if InStr(
                detail,
                "SALE"
            )
                stats.hourlySales[hourIndex]++
        }

        ; --------------------------------------------------------
        ; ОТМЕНА ПРОДАЖИ
        ; --------------------------------------------------------

        else if (eventType == "SALE_CANCELLED")
        {
            stats.cancelledSales++
        }
    }

    Loop 24
    {
        calls := stats.hourlyCalls[A_Index]
        sales := stats.hourlySales[A_Index]

        if (calls > stats.busiestHourCount)
        {
            stats.busiestHourCount := calls
            stats.busiestHour := A_Index - 1
        }

        if (sales > stats.bestSalesHourCount)
        {
            stats.bestSalesHourCount := sales
            stats.bestSalesHour := A_Index - 1
        }
    }

    if (interCallCount > 0)
    {
        stats.averageInterCallSeconds :=
            Round(
                interCallTotal / interCallCount
            )
    }

    if (
        stats.firstAction != ""
        && stats.lastAction != ""
    )
    {
        try
        {
            stats.activeSpanSeconds :=
                DateDiff(
                    stats.lastAction,
                    stats.firstAction,
                    "Seconds"
                )
        }
        catch
        {
        }
    }

    return stats
}


StatsFormatDuration(seconds)
{
    try
    {
        seconds := Integer(seconds)
    }
    catch
    {
        seconds := 0
    }

    if (seconds < 0)
        seconds := 0

    hours := Floor(seconds / 3600)
    minutes := Floor(
        Mod(seconds, 3600) / 60
    )
    secs := Mod(seconds, 60)

    if (hours > 0)
    {
        return Format(
            "{:02}:{:02}:{:02}",
            hours,
            minutes,
            secs
        )
    }

    return Format(
        "{:02}:{:02}",
        minutes,
        secs
    )
}


StatsGetTopButtons(buttons, limit := 8)
{
    result := []

    for key, value in buttons
    {
        inserted := false

        Loop result.Length
        {
            idx := A_Index

            if (value > result[idx].value)
            {
                result.InsertAt(
                    idx,
                    {
                        key: key,
                        value: value
                    }
                )

                inserted := true
                break
            }
        }

        if (!inserted)
        {
            result.Push({
                key: key,
                value: value
            })
        }

        if (result.Length > limit)
            result.Pop()
    }

    return result
}


; Escape остаётся обычным Escape благодаря "~".
; При активном неподтверждённом звонке он фиксирует NO_ANSWER.
~Esc::
{
    global currentMode, statsIgnoreEsc
    global statsCallActive, statsCallAnswered

    if (currentMode != 0)
        StatsTrackButton("Esc")

    if (statsIgnoreEsc)
        return

    if (
        currentMode != 0
        && statsCallActive
        && !statsCallAnswered
    )
    {
        StatsFinishCall(
            "NO_ANSWER",
            "ESC"
        )
    }
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

    StatsBeginOrRetryCall(
        "HandleSipCallFlow",
        currentPhoneNum
    )
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

    StatsBeginOrRetryCall(
        "F2",
        currentPhoneNum
    )
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

    StatsBeginOrRetryCall(
        "F1",
        currentPhoneNum
    )

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
    StatsTrackButton("End")
    if (currentMode != 0)
    {
        StatsCloseCurrentCall()
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
    StatsTrackButton("F11")

    if (currentMode != 2 && currentMode != 3)
        currentMode := 2
    else if (currentMode == 2)
        currentMode := 3
    else
        currentMode := 2

    lastWorkMode := currentMode

    StatsQueueEvent(
        "F11",
        "MODE_CHANGED",
        "",
        0,
        "mode=" . StatsGetModeName()
    )

    UpdateModeIndicator()
    ToolTip("РЕЖИМ: " . (currentMode == 2 ? "BITRIX" : "SVERKA"))
    SetTimer(() => ToolTip(), -1200)
}


; F12 циклически переключает: SAP → Telegram → MicroSIP → SAP.
$F12::
{
    global currentMode, lastWorkMode
    StatsTrackButton("F12")

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

    StatsQueueEvent(
        "F12",
        "MODE_CHANGED",
        "",
        0,
        "mode=" . StatsGetModeName()
    )

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
    StatsTrackButton("F10")
    
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
    StatsTrackButton("F1")
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
        Sleep(200)
        Send("#{1}")
        Sleep(200)
        Send("{Enter}")
        Sleep(80)
        Send("{Up}")
        Sleep(80)
        Send("{Enter}")
        Sleep(80)
        StatsBeginOrRetryCall(
            "F1",
            currentPhoneNum
        )
    }
}

; F2 выполняет второй сценарий режима: в SAP забирает выделенный номер и звонит,
; а в остальных режимах оставляет исходную обработку статуса/номера без изменений.
$F2::
{
    global currentPhoneNum, callCount, currentMode
    StatsTrackButton("F2")
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

        StatsBeginOrRetryCall(
            "F2",
            currentPhoneNum
        )
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
    StatsTrackButton("F3")

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

        StatsBeginOrRetryCall(
            "F3",
            currentPhoneNum
        )
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
    StatsTrackButton("F4")
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

        StatsBeginOrRetryCall(
            "F4",
            currentPhoneNum
        )

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

        StatsBeginOrRetryCall(
            "F4",
            currentPhoneNum
        )
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
    StatsTrackButton("F6")
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
    StatsTrackButton("F7")
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
    StatsTrackButton("F8")
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
    global statsIgnoreEsc
    StatsTrackButton("F9")
    if (currentMode == 0)
    {
        Send("{F9}")
        return
    }

    ToolTip("⚠️ ЗАКРЫТЬ лишние программы для сверки?`n[ ENTER ] — Закрыть | [ ESC / жди 3с ] — Отмена")
    
    statsIgnoreEsc := true
    ih := InputHook("L1 T3", "{Enter}{Escape}")
    ih.Start()
    ih.Wait()

    statsIgnoreEsc := false

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

$Volume_Mute::
{
    global currentMode, todayKey, todaySales, iniFile
    StatsTrackButton("Volume_Mute")

    if (currentMode == 0)
    {
        Send("{Volume_Mute}")
        return
    }

    Sleep(250)
    Send("#{1}")
    Sleep(350)
    Send("{Enter}")
    Sleep(350)

    ; ============================================================
    ; ОБНОВЛЯЕМ ДАТУ
    ; ============================================================

    currentDay := FormatTime(A_Now, "yyyy-MM-dd")

    if (currentDay != todayKey)
    {
        todayKey := currentDay
        todaySales := IniRead(iniFile, "DailySales", todayKey, 0)
    }

    ; ============================================================
    ; ОБЩАЯ СТАТИСТИКА ЗА ДЕНЬ
    ; ============================================================

    todaySales++

    IniWrite(
        todaySales,
        iniFile,
        "DailySales",
        todayKey
    )

    StatsFinishCall(
        "SALE",
        "Volume_Mute"
    )

    ; ============================================================
    ; ПОЧАСОВАЯ СТАТИСТИКА
    ; ============================================================

    currentHour := FormatTime(A_Now, "HH")
    hourKey := todayKey . "_" . currentHour

    hourSales := IniRead(
        iniFile,
        "HourlySales",
        hourKey,
        0
    )

    hourSales++

    IniWrite(
        hourSales,
        iniFile,
        "HourlySales",
        hourKey
    )

    ; ============================================================
    ; ОБНОВЛЕНИЕ ОСНОВНОГО ИНТЕРФЕЙСА
    ; ============================================================

    UpdateAllWidgetsDisplay()

    ToolTip(
        "Звонок завершен! Продаж сегодня: " . todaySales
    )

    SetTimer(() => ToolTip(), -1200)

    Sleep(300)
    Send("#{3}")
}

; PrintScreen отменяет одну продажу, не позволяя счётчику стать отрицательным.
$PrintScreen::
{
    global currentMode, todayKey, todaySales, iniFile
    StatsTrackButton("PrintScreen")

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
    StatsTrackButton(
        A_ThisHotkey
    )

    if (currentMode == 3)
    {
        ; SVERKA → сообщаем ZIK о результате KOCHADAN

        try
        {
            http := ComObject("WinHttp.WinHttpRequest.5.1")

            http.Open(
                "POST",
                "http://127.0.0.1:8765/event",
                false
            )

            http.SetRequestHeader(
                "Content-Type",
                "application/json"
            )

            http.Send(
                '{"event":"kochadan"}'
            )
        }
        catch
        {
            ToolTip("ZIK недоступен")
            SetTimer(() => ToolTip(), -1500)
        }

        return
    }

    ; ===== ТВОЙ СТАРЫЙ КОД =====

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

    StatsMarkClientAnswered(
        A_ThisHotkey,
        cleanNum
    )

    Sleep(80)
    Send("#{2}")
    Sleep(100)
    Send("{Escape 3}")
    Sleep(80)
    Send("^f")
    Sleep(100)
    Send("{Escape}")
    Sleep(100)
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
    StatsTrackButton("Browser_Home")
    Send("^w")
    Sleep(50)
    Send("^#{Left}")
}

; Volume Down переключает Windows на рабочий стол слева.
$Volume_Down::
{
    StatsTrackButton("Volume_Down")
    Send("^#{Left}")
}

; Volume Up переключает Windows на рабочий стол справа.
$Volume_Up::
{
    StatsTrackButton("Volume_Up")
    Send("^#{Right}")
}
; ================================================================
; INSERT — СТАТИСТИКА ПРОДАЖ ЗА ПОСЛЕДНИЕ 10 ДНЕЙ
; ================================================================

$Insert::
{
    global currentMode
    StatsTrackButton("Insert")

    if (currentMode == 0)
    {
        Send("{Insert}")
        return
    }

    ShowDailyStats()
}

ShowDailyStats()
{
    global iniFile, todaySales, todayKey

    ; ============================================================
    ; СОЗДАЁМ ОКНО
    ; ============================================================

    chartGui := Gui(
        "+AlwaysOnTop +Border",
        "Статистика продаж"
    )

    chartGui.BackColor := "FFFFFF"
    chartGui.MarginX := 25
    chartGui.MarginY := 20

    ; ============================================================
    ; ЗАГОЛОВОК
    ; ============================================================

    chartGui.SetFont(
        "s16 bold",
        "Segoe UI"
    )

    chartGui.Add(
        "Text",
        "x25 y20 w620 Center c0066CC",
        "СТАТИСТИКА ПРОДАЖ"
    )

    chartGui.SetFont(
        "s10",
        "Segoe UI"
    )

    chartGui.Add(
        "Text",
        "x25 y52 w620 Center c777777",
        "Последние 10 дней"
    )

    chartGui.Add(
        "Text",
        "x25 y78 w620 h1 BackgroundD9D9D9"
    )

    ; ============================================================
    ; СНАЧАЛА НАХОДИМ МАКСИМАЛЬНОЕ ЗНАЧЕНИЕ
    ; ============================================================

    maxVal := 1

    Loop 10
    {
        daysAgo := A_Index - 1

        dateKey := FormatTime(
            DateAdd(A_Now, -daysAgo, "Days"),
            "yyyy-MM-dd"
        )

        value := IniRead(
            iniFile,
            "DailySales",
            dateKey,
            0
        )

        try
        {
            value := Integer(value)
        }
        catch
        {
            value := 0
        }

        if (value > maxVal)
            maxVal := value
    }

    ; ============================================================
    ; РИСУЕМ ПОСЛЕДНИЕ 10 ДНЕЙ
    ; От старого к новому
    ; ============================================================

    y := 100

    Loop 10
    {
        daysAgo := 10 - A_Index

        dateKey := FormatTime(
            DateAdd(A_Now, -daysAgo, "Days"),
            "yyyy-MM-dd"
        )

        ; --------------------------------------------------------
        ; Получаем продажи за этот день
        ; --------------------------------------------------------

        if (dateKey == todayKey)
        {
            value := todaySales
        }
        else
        {
            value := IniRead(
                iniFile,
                "DailySales",
                dateKey,
                0
            )

            try
            {
                value := Integer(value)
            }
            catch
            {
                value := 0
            }
        }

        ; --------------------------------------------------------
        ; Дата
        ; --------------------------------------------------------

        chartGui.SetFont(
            "s10",
            "Segoe UI"
        )

        chartGui.Add(
            "Text",
            "x25 y" . y . " w90 h22 c333333",
            dateKey
        )

        ; --------------------------------------------------------
        ; Процент заполнения
        ; --------------------------------------------------------

        percent := 0

        if (value > 0)
            percent := (value / maxVal) * 100

        ; --------------------------------------------------------
        ; Полоса
        ; --------------------------------------------------------

        chartGui.Add(
            "Progress",
            "x125 y" . y
            . " w400 h20"
            . " BackgroundE5E5E5"
            . " c008800"
            . " Range0-100",
            percent
        )

        ; --------------------------------------------------------
        ; Число продаж
        ; --------------------------------------------------------

        chartGui.SetFont(
            "s10 bold",
            "Segoe UI"
        )

        chartGui.Add(
            "Text",
            "x540 y" . y . " w60 h22 c222222",
            value
        )

        y += 34
    }

    ; ============================================================
    ; ИТОГ
    ; ============================================================

    chartGui.Add(
        "Text",
        "x25 y" . (y + 5)
        . " w620 h1 BackgroundD9D9D9"
    )

    chartGui.SetFont(
        "s11 bold",
        "Segoe UI"
    )

    chartGui.Add(
        "Text",
        "x25 y" . (y + 18)
        . " w400 h30 c0066CC",
        "Сегодня: " . todaySales . " продаж"
    )

    ; ============================================================
    ; КНОПКА
    ; ============================================================

    closeBtn := chartGui.Add(
        "Button",
        "x520 y" . (y + 15)
        . " w125 h30 Default",
        "Закрыть"
    )

    closeBtn.OnEvent(
        "Click",
        (*) => chartGui.Destroy()
    )

    chartGui.OnEvent(
        "Close",
        (*) => chartGui.Destroy()
    )

    ; ============================================================
    ; ПОКАЗЫВАЕМ ОКНО
    ; ============================================================

    chartGui.Show(
        "w680 h" . (y + 60)
    )
}

; ================================================================
; HOME — ПОЛНАЯ АНАЛИТИКА ВЫБРАННОГО ДНЯ
; ================================================================

$Home::
{
    global currentMode

    StatsTrackButton("Home")

    if (currentMode == 0)
    {
        Send("{Home}")
        return
    }

    ShowHourlyStats()
}


ShowHourlyStats()
{
    global todayKey

    selectedDate := todayKey

    statsGui := Gui(
        "+AlwaysOnTop +Border",
        "Аналитика рабочего дня"
    )

    statsGui.BackColor := "FFFFFF"
    statsGui.MarginX := 25
    statsGui.MarginY := 20

    statsGui.SetFont(
        "s16 bold",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y18 w820 h32 Center c0066CC",
        "АНАЛИТИКА РАБОЧЕГО ДНЯ"
    )

    statsGui.SetFont(
        "s10",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y52 w820 h22 Center c777777",
        "Выбери дату и нажми «Показать»"
    )

    statsGui.Add(
        "Text",
        "x25 y87 w45 h25",
        "Дата:"
    )

    dateEdit := statsGui.Add(
        "Edit",
        "x70 y84 w120 h26",
        selectedDate
    )

    showBtn := statsGui.Add(
        "Button",
        "x200 y83 w100 h28",
        "Показать"
    )

    prevBtn := statsGui.Add(
        "Button",
        "x310 y83 w85 h28",
        "← Вчера"
    )

    currentBtn := statsGui.Add(
        "Button",
        "x405 y83 w95 h28",
        "Сегодня"
    )

    nextBtn := statsGui.Add(
        "Button",
        "x510 y83 w85 h28",
        "Завтра →"
    )

    statsGui.Add(
        "Text",
        "x25 y122 w820 h1 BackgroundD9D9D9"
    )

    cardY := 138

    statsGui.SetFont(
        "s8",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y" . cardY . " w150 h18 Center c777777",
        "ЗВОНКИ"
    )

    statsGui.Add(
        "Text",
        "x185 y" . cardY . " w150 h18 Center c777777",
        "ОТВЕТИЛИ"
    )

    statsGui.Add(
        "Text",
        "x345 y" . cardY . " w150 h18 Center c777777",
        "КЛИЕНТЫ"
    )

    statsGui.Add(
        "Text",
        "x505 y" . cardY . " w150 h18 Center c777777",
        "ПРОДАЖИ"
    )

    statsGui.Add(
        "Text",
        "x665 y" . cardY . " w180 h18 Center c777777",
        "ПИК ЗВОНКОВ"
    )

    statsGui.SetFont(
        "s18 bold",
        "Segoe UI"
    )

    callsValue := statsGui.Add(
        "Text",
        "x25 y" . (cardY + 18) . " w150 h34 Center c0066CC",
        "0"
    )

    answeredValue := statsGui.Add(
        "Text",
        "x185 y" . (cardY + 18) . " w150 h34 Center c008800",
        "0"
    )

    uniqueValue := statsGui.Add(
        "Text",
        "x345 y" . (cardY + 18) . " w150 h34 Center c444444",
        "0"
    )

    salesValue := statsGui.Add(
        "Text",
        "x505 y" . (cardY + 18) . " w150 h34 Center cCC6600",
        "0"
    )

    peakValue := statsGui.Add(
        "Text",
        "x665 y" . (cardY + 18) . " w180 h34 Center cCC6600",
        "—"
    )

    statsGui.SetFont(
        "s8",
        "Segoe UI"
    )

    answerRateValue := statsGui.Add(
        "Text",
        "x185 y" . (cardY + 53) . " w150 h18 Center c777777",
        "0.0% ответов"
    )

    conversionValue := statsGui.Add(
        "Text",
        "x505 y" . (cardY + 53) . " w150 h18 Center c777777",
        "0.0% конверсия"
    )

    graphTop := 240

    statsGui.SetFont(
        "s10 bold",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y" . graphTop . " w400 h22 c444444",
        "ЗВОНКИ ПО ЧАСАМ"
    )

    statsGui.Add(
        "Text",
        "x445 y" . graphTop . " w400 h22 c444444",
        "ВТОРАЯ ПОЛОВИНА ДНЯ"
    )

    statsGui.SetFont(
        "s8",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y" . (graphTop + 25) . " w400 h18 c999999",
        "Количество начатых звонков"
    )

    statsGui.Add(
        "Text",
        "x445 y" . (graphTop + 25) . " w400 h18 c999999",
        "12:00–00:00 • количество звонков"
    )

    graphY := graphTop + 50
    rowH := 24
    hourRows := []

    Loop 24
    {
        idx := A_Index

        if (idx <= 12)
        {
            x := 25
            row := idx - 1
        }
        else
        {
            x := 445
            row := idx - 13
        }

        y := graphY + row * rowH

        hourStart := Format(
            "{:02}:00",
            idx - 1
        )

        hourEnd := Format(
            "{:02}:00",
            Mod(idx, 24)
        )

        statsGui.SetFont(
            "s8",
            "Segoe UI"
        )

        statsGui.Add(
            "Text",
            "x" . x . " y" . y . " w65 h19 c555555",
            hourStart . "–" . hourEnd
        )

        callBar := statsGui.Add(
            "Progress",
            "x" . (x + 70)
            . " y" . y
            . " w190 h17"
            . " BackgroundEEEEEE"
            . " c0066CC"
            . " Range0-100",
            0
        )

        callCountText := statsGui.Add(
            "Text",
            "x" . (x + 265)
            . " y" . y
            . " w40 h19 Center c222222",
            "0"
        )

        hourRows.Push({
            progress: callBar,
            count: callCountText
        })
    }

    bottomY := graphY + 12 * rowH + 8

    statsGui.Add(
        "Text",
        "x25 y" . bottomY
        . " w820 h1 BackgroundD9D9D9"
    )

    statsGui.SetFont(
        "s9",
        "Segoe UI"
    )

    workInfo := statsGui.Add(
        "Text",
        "x25 y" . (bottomY + 10)
        . " w400 h24 c555555",
        "Работа: —"
    )

    intervalInfo := statsGui.Add(
        "Text",
        "x445 y" . (bottomY + 10)
        . " w400 h24 c555555",
        "Средний интервал: —"
    )

    retryInfo := statsGui.Add(
        "Text",
        "x25 y" . (bottomY + 35)
        . " w400 h24 c555555",
        "Повторных попыток: 0"
    )

    bestSalesInfo := statsGui.Add(
        "Text",
        "x445 y" . (bottomY + 35)
        . " w400 h24 c555555",
        "Лучший час по продажам: —"
    )

    noAnswerInfo := statsGui.Add(
        "Text",
        "x25 y" . (bottomY + 60)
        . " w400 h24 c555555",
        "Не ответили: 0"
    )

    idleInfo := statsGui.Add(
        "Text",
        "x445 y" . (bottomY + 60)
        . " w400 h24 c555555",
        "Простои > 5 мин: 00:00"
    )

    buttonsTitleY := bottomY + 95

    statsGui.SetFont(
        "s10 bold",
        "Segoe UI"
    )

    statsGui.Add(
        "Text",
        "x25 y" . buttonsTitleY . " w820 h22 c444444",
        "САМЫЕ ЧАСТЫЕ РАБОЧИЕ ДЕЙСТВИЯ"
    )

    buttonRows := []

    Loop 8
    {
        y := buttonsTitleY + 26 + (A_Index - 1) * 20

        statsGui.SetFont(
            "s8",
            "Segoe UI"
        )

        keyText := statsGui.Add(
            "Text",
            "x25 y" . y . " w150 h18 c333333",
            ""
        )

        countText := statsGui.Add(
            "Text",
            "x175 y" . y . " w70 h18 c777777",
            ""
        )

        buttonRows.Push({
            key: keyText,
            count: countText
        })
    }

    closeBtn := statsGui.Add(
        "Button",
        "x720 y" . (buttonsTitleY + 175)
        . " w125 h30 Default",
        "Закрыть"
    )

    RefreshAnalytics()
    {
        selected := Trim(
            dateEdit.Value
        )

        if !StatsValidDate(selected)
        {
            ToolTip(
                "Дата должна быть в формате YYYY-MM-DD"
            )

            SetTimer(
                () => ToolTip(),
                -1400
            )

            return
        }

        data := BuildDailyAnalytics(
            selected
        )

        callsValue.Value := data.calls
        answeredValue.Value := data.answered
        uniqueValue.Value := data.uniqueClients.Count
        salesValue.Value := data.sales

        if (data.calls > 0)
        {
            answerRate :=
                (data.answered / data.calls) * 100

            answerRateValue.Value :=
                Format(
                    "{:.1f}% ответов",
                    answerRate
                )

            conversion :=
                (data.sales / data.calls) * 100

            conversionValue.Value :=
                Format(
                    "{:.1f}% конверсия",
                    conversion
                )
        }
        else
        {
            answerRateValue.Value := "0.0% ответов"
            conversionValue.Value := "0.0% конверсия"
        }

        if (
            data.busiestHour >= 0
            && data.busiestHourCount > 0
        )
        {
            peakValue.Value :=
                Format(
                    "{:02}:00–{:02}:00",
                    data.busiestHour,
                    Mod(
                        data.busiestHour + 1,
                        24
                    )
                )
                . " (" . data.busiestHourCount . ")"
        }
        else
        {
            peakValue.Value := "—"
        }

        graphMax := 1

        Loop 24
        {
            value := data.hourlyCalls[A_Index]

            if (value > graphMax)
                graphMax := value
        }

        Loop 24
        {
            value := data.hourlyCalls[A_Index]

            percent := 0

            if (value > 0)
                percent :=
                    (value / graphMax) * 100

            hourRows[A_Index].progress.Value :=
                percent

            hourRows[A_Index].count.Value :=
                value
        }

        if (
            data.firstAction != ""
            && data.lastAction != ""
        )
        {
            workInfo.Value :=
                "Работа: "
                . data.firstAction
                . " → "
                . data.lastAction
        }
        else
        {
            workInfo.Value :=
                "Работа: нет событий"
        }

        intervalInfo.Value :=
            "Средний интервал: "
            . StatsFormatDuration(
                data.averageInterCallSeconds
            )

        retryInfo.Value :=
            "Повторных попыток: "
            . data.retries

        noAnswerInfo.Value :=
            "Не ответили: "
            . data.noAnswer

        idleInfo.Value :=
            "Простои > 5 мин: "
            . StatsFormatDuration(
                data.idleSeconds
            )

        if (
            data.bestSalesHour >= 0
            && data.bestSalesHourCount > 0
        )
        {
            bestSalesInfo.Value :=
                "Лучший час по продажам: "
                . Format(
                    "{:02}:00–{:02}:00",
                    data.bestSalesHour,
                    Mod(
                        data.bestSalesHour + 1,
                        24
                    )
                )
                . " (" . data.bestSalesHourCount . ")"
        }
        else
        {
            bestSalesInfo.Value :=
                "Лучший час по продажам: —"
        }

        topButtons :=
            StatsGetTopButtons(
                data.buttons,
                8
            )

        Loop 8
        {
            buttonRows[A_Index].key.Value := ""
            buttonRows[A_Index].count.Value := ""
        }

        for idx, item in topButtons
        {
            if (idx > 8)
                break

            buttonRows[idx].key.Value :=
                item.key

            buttonRows[idx].count.Value :=
                item.value . " раз"
        }
    }

    ; В AHK v2 callback с несколькими операторами нельзя писать как (*) { ... }.
    ; Используем именованные локальные callback-функции.
    MoveAnalyticsDate(delta)
    {
        dateEdit.Value :=
            StatsDateAdd(
                Trim(dateEdit.Value),
                delta
            )

        RefreshAnalytics()
    }

    SetAnalyticsToday()
    {
        global todayKey
        dateEdit.Value := todayKey
        RefreshAnalytics()
    }

    showBtn.OnEvent(
        "Click",
        (*) => RefreshAnalytics()
    )

    prevBtn.OnEvent(
        "Click",
        (*) => MoveAnalyticsDate(-1)
    )

    currentBtn.OnEvent(
        "Click",
        (*) => SetAnalyticsToday()
    )

    nextBtn.OnEvent(
        "Click",
        (*) => MoveAnalyticsDate(1)
    )

    closeBtn.OnEvent(
        "Click",
        (*) => statsGui.Destroy()
    )

    statsGui.OnEvent(
        "Close",
        (*) => statsGui.Destroy()
    )

    statsGui.Show(
        "w870 h" . (buttonsTitleY + 215)
    )
}


$PgDn::{
    StatsTrackButton("PgDn")
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
    StatsTrackButton("ScrollLock")
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
    StatsTrackButton("SC029")

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
