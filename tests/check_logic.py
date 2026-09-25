"""Run isolated AHK regression checks without registering Albert hotkeys.

Usage: python tests/check_logic.py [path/to/AutoHotkey64.exe]
All INI/log writes go to a temporary directory, never the user's live data.
"""
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
AHK = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "C:/Program Files/AutoHotkey/v2/AutoHotkey64.exe"
)
SOURCE = ROOT / "release" / "Albert-V2.ahk"
source = SOURCE.read_text(encoding="utf-8-sig")

# /validate parses the whole script without running its startup code.
subprocess.run(
    [str(AHK), "/ErrorStdOut", "/validate", str(SOURCE)],
    check=True, timeout=20,
)

# Use the production analytics functions, excluding startup, timers and hotkeys.
start = source.index("StatsNormalizeKey(key)\n{")
end = source.index("; Escape остаётся обычным Escape")
functions = source[start:end]
functions += source[source.index("ParseFirstWarehouseRow(selection)\n{"):source.index("$*SC029::")]
# Instantiate production forms hidden; never touch the desktop or Startup folder.
functions += source[source.index("InitializeAlbertRelease()\n{"):].replace('g.Show()', 'g.Show("Hide")')
functions += '\nShowStatusSettings() {\n}\n'
checks = r'''
#Requires AutoHotkey v2.0
global iniFile := A_ScriptDir . "\settings.ini"
global statsLogFile := A_ScriptDir . "\activity_log.txt"
global statsLogBuffer := "", statsLogPending := 0
global currentMode := 1
global sapF3Text := "", employeeTag := ""
global statsCallActive := false, statsCallAnswered := false
global statsCallPhone := "", statsCallAttempt := 0, statsCallMode := 0
global statsCallStartedTick := 0, statsCallAnsweredTick := 0

Assert(condition, label)
{
    if !condition
        throw Error(label)
}

try
{
    CreateAlbertStartupShortcut(A_ScriptDir . "\Albert-test.lnk")
    FileGetShortcut(A_ScriptDir . "\Albert-test.lnk", &target, &workingDir, &args)
    Assert(target == A_AhkPath, "Wrong AutoHotkey shortcut target")
    Assert(workingDir == A_ScriptDir, "Wrong shortcut working directory")
    Assert(args == '"' . A_ScriptFullPath . '" --startup', "Startup argument missing")
    ShowAlbertSettings(true)
    ShowAlbertBranches()
    Suspend(false)
    FileAppend("PASS: settings/branch GUI construction, startup shortcut arguments`n", "*")

    branches := LoadAlbertBranches()
    Assert(branches["AN - ASKO Andijon"] == "ANDIJON ASKO", "Andijon mapping")
    Assert(branches["AR - ASKO Angren"] == "Angren call center", "Angren mapping")
    IniWrite(7, iniFile, "DailySales", "2026-09-24")
    branches["TEST - ASKO Test"] := "Test group"
    SaveAlbertBranches(branches)
    Assert(LoadAlbertBranches()["TEST - ASKO Test"] == "Test group", "Branch not persisted")
    branches.Delete("CT2 - ASKO Chust")
    SaveAlbertBranches(branches)
    Assert(!LoadAlbertBranches().Has("CT2 - ASKO Chust"), "Deleted default reappeared")
    Assert(IniRead(iniFile, "DailySales", "2026-09-24") == 7, "Branch edit destroyed statistics")
    SaveAlbertBranches(Map())
    Assert(LoadAlbertBranches().Count == 0, "Empty branch list not preserved")
    IniWrite("C:\Test Folder\microsip.exe", iniFile, "Paths", "MicroSip")
    Assert(AlbertPath("MicroSip") == "C:\Test Folder\microsip.exe", "Custom path ignored")
    Assert(AlbertDesktopCount() >= 1, "Desktop registry parse failed")
    FileAppend("PASS: branch CRUD/persistence, custom paths, desktop count`n", "*")

    tire := "QR2 - ASKO Qarshi 2`tSHN123`tFortuna ECOPLUS2 4S 175/70/13`tFortuna ECOPLUS2 4S`t175/70/13`t418 000 UZS`t8 шт"
    disk := "AR - ASKO Angren`tDK0045`tQora Diska 114,3/B/13`tQora Diska`t114,3/B/13`t217 000 UZS`t5 шт"
    order := ParseFirstWarehouseRow(tire . "`r`n" . disk)
    Assert(order.branch == "QR2 - ASKO Qarshi 2", "Wrong first branch")
    Assert(order.name == "Fortuna ECOPLUS2 4S 175/70/13", "Wrong tire name")
    Assert(order.priceUzs == 418000 && order.quantity == 8, "Wrong tire price/quantity")
    order := ParseFirstWarehouseRow(disk . "`r`n" . tire)
    Assert(order.name == "Qora Diska 114,3/B/13", "Wrong disk name")
    Assert(order.priceUzs == 217000 && order.quantity == 5, "Wrong disk price/quantity")
    order := ParseFirstWarehouseRow(StrReplace(tire, "8 шт", "3 шт") . "`n" . disk)
    Assert(order.quantity == 3, "Used second row stock")
    rejected := false
    try
        ParseFirstWarehouseRow(StrReplace(tire, "8 шт", "") . "`n" . disk)
    catch
        rejected := true
    Assert(rejected, "Accepted incomplete first row")
    rejected := false
    try
        ParseFirstWarehouseRow(StrReplace(tire, "8 шт", ""))
    catch
        rejected := true
    Assert(rejected, "Accepted missing stock")
    FileAppend("PASS: first warehouse row, SHN/DK, prices and stock`n", "*")

    Assert(!StatsSamePhone("901234567", "991234567"), "Distinct clients merged")
    Assert(StatsSamePhone("+998 90 123-45-67", "901234567"), "Country prefix mismatch")
    Assert(StatsNormalizePhone("+998 90 123-45-67") == "901234567", "Lost phone digit")

    StatsStartCall("F2", "901234567")
    StatsMarkClientAnswered("Launch_Media", "901234567")
    StatsBeginOrRetryCall("F1", "901234567")
    Assert(InStr(statsLogBuffer, "ANSWERED;attempt=1;RETRY"), "Retry lost answer")
    Assert(!InStr(statsLogBuffer, "NO_ANSWER"), "Answered retry became no-answer")
    Assert(statsCallAttempt == 2, "Retry counter mismatch")
    statsLogBuffer := ""
    statsLogPending := 0

    fixture := "2026-09-24 10:00:00|2026-09-24|10:00:00|MICROSIP|F1|CALL_STARTED|901234567|0|attempt=1`n"
        . "2026-09-24 10:10:00|2026-09-24|10:10:00|MICROSIP|F1|CALL_STARTED|991234567|0|attempt=1`n"
    FileAppend(fixture, statsLogFile, "UTF-8")
    data := BuildDailyAnalytics("2026-09-24")
    Assert(data.calls == 2, "Call total mismatch")
    Assert(data.uniqueClients.Count == 2, "Unique clients mismatch")
    Assert(data.averageInterCallSeconds == 600, "Call interval mismatch")
    Assert(data.idleSeconds == 600, "Idle duration mismatch")
    Assert(data.activeSpanSeconds == 600, "Active span mismatch")
    FileAppend("PASS: phone identity, retries and analytics timing`n", "*")
    ExitApp(0)
}
catch as err
{
    FileAppend("FAIL: " . err.Message . "`n", "*")
    ExitApp(1)
}
'''

with tempfile.TemporaryDirectory(prefix="albert-check-") as temp:
    script = Path(temp) / "check.ahk"
    script.write_text(checks + "\n" + functions, encoding="utf-8-sig")
    result = subprocess.run(
        [str(AHK), "/ErrorStdOut", str(script)],
        capture_output=True, timeout=20,
    )
    print(result.stdout.decode("utf-8", errors="replace"), end="")
    print(result.stderr.decode("utf-8", errors="replace"), end="")
    sys.exit(result.returncode)
