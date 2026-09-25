from pathlib import Path
import subprocess,re,hashlib,datetime
root=Path(__file__).resolve().parents[1]
p=root/'Albert-V2.ahk'
raw=p.read_bytes()
s=raw.decode('utf-8-sig').replace('\r\n','\n')
base=subprocess.check_output(['git','show','96c9b28:Albert-V2.ahk'],cwd=root).decode('utf-8-sig').replace('\r\n','\n')
release=root/'release/Albert-V2.ahk'
release_hash=hashlib.sha256(release.read_bytes()).hexdigest()
backup=root/'backups'/('before-personal-restore-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'.ahk')
backup.parent.mkdir(exist_ok=True)
backup.write_bytes(raw)

def segment(text,start,end):
    a=text.index(start); b=text.index(end,a)
    return text[a:b]

# Preserve the user's added DND-off/Pause code beyond the release functions.
extra=s[s.index('DisableMicroSipDnd()\n{'):]
branches=segment(s,'DefaultAlbertBranches()\n{','\nDisableMicroSipDnd()\n{')
branches=branches[branches.index('    return Map('):branches.rfind('\n}')].rstrip()
branches=branches.replace('    return Map(', '    branchExceptions := Map(',1)
s=s[:s.index('; RELEASE:')].rstrip()+'\n\n'+extra
s=s.replace('    branchExceptions := LoadAlbertBranches()',branches)
s=s.replace('''        ToolTip("Филиал не настроен: " . rawBranch . ". Добавьте его через F10 → Филиалы.")
        SetTimer(() => ToolTip(), -3500)
        return''','''        tgGroupName := RegExReplace(rawBranch, "i)^[A-Z0-9]+\\s*-\\s*(asko[-\\s]*|)", "")
        tgGroupName := Trim(tgGroupName)''')
s=s.replace('SetTimer(InitializeAlbertRelease, -50)\n','')
s=s.replace('$F10::ShowAlbertSettings()\n\nShowStatusSettings()\n{','$F10::\n{')
s=re.sub(r'global sapF3Text := .*\nglobal employeeTag := .*\n',re.search(r'global sapF3Text := .*\n',base)[0],s)
s=s.replace('global currentMode, employeeTag','global currentMode')
s=s.replace(' . " " . employeeTag',' . " #Abdulloh"')
s=s.replace('sipIni := AlbertPath("MicroSipIni")','sipIni := A_AppData . "\\MicroSIP\\microsip.ini"')
s=s.replace('sipExe := AlbertPath("MicroSip")','sipExe := EnvGet("LOCALAPPDATA") . "\\MicroSIP\\microsip.exe"')
s=s.replace('5 = SAP\n','5 = SAP, 6 = ZIK\n')
s=s.replace('SAP → Telegram → MicroSIP','SAP → ZIK → Telegram → MicroSIP')
hb=segment(base,'; ==============================================================================\n;                         ZIK AHK HEARTBEAT','; ==============================================================================\n;                         2.')
anchor='; ==============================================================================\n;                         2.'
s=s.replace(anchor,hb+anchor,1)
s=s.replace('        modeText.Value := "SAP"','        modeText.Value := "SAP"\n    else if (currentMode == 6)\n        modeText.Value := "ZIK"',1)
s=s.replace('        case 5:\n            return "SAP"','        case 5:\n            return "SAP"\n\n        case 6:\n            return "ZIK"',1)
zb=segment(base,'; ==============================================================================\n;                         ZIK —','; ==============================================================================\n;                         4.')
anchor='; ==============================================================================\n;                         4.'
s=s.replace(anchor,zb+anchor,1)
start=s.index('$F12::'); end=s.index('; F10 открывает',start)
bs=base.index('$F12::'); be=base.index('; F10 открывает',bs)
s=s[:start]+base[bs:be]+s[end:]
s=s.replace('; F12 — SAP → TELEGRAM','; F12 — SAP → ZIK → TELEGRAM')
for hotkey,command in [('$F1::','ZikF1Next'),('$F2::','ZikF2Kochadan'),('$Launch_Media::','ZikF2Kochadan'),('$Browser_Home::','ZikF1Next')]:
    start=s.index(hotkey); end=s.index('\n}',start)
    body=s[start:end]
    # Insert before first operation, after opening brace; global variables are superglobal.
    brace=body.index('{')+1
    body=body[:brace]+f'\n    if (currentMode == 6)\n    {{\n        {command}()\n        return\n    }}\n'+body[brace:]
    s=s[:start]+body+s[end:]
pg=segment(base,'PgUp::{','; ==============================================================================\n;        7.')
anchor='; ==============================================================================\n;        7.'
s=s.replace(anchor,pg+anchor,1)
# Cosmetic desktop labels match personal start.ahk (3=communications, 4=warehouse).
s=s.replace('КАЛЬКУЛЯТОР (Стол 3)','КАЛЬКУЛЯТОР (Стол 4)').replace('ТЕЛЕГРАМ (Стол 2)','ТЕЛЕГРАМ (Стол 3)').replace('со Стола 3 на Стол 2','со Стола 4 на Стол 3').replace('ВОЗВРАТ В CRM (на Стол 3)','ВОЗВРАТ В CRM (на Стол 4)')
for forbidden in ['InitializeAlbertRelease','AlbertPath(', 'LoadAlbertBranches','employeeTag','ShowAlbertSettings','C:\\Albert']:
    assert forbidden not in s,forbidden
for required in ['ZikSendCommand','Pause::','DisableMicroSipDnd','ParseFirstWarehouseRow','ProcessWaitClose("microsip.exe", 3) != 0','ANDIJON ASKO']:
    assert required in s,required
p.write_text(s,encoding='utf-8-sig')
assert hashlib.sha256(release.read_bytes()).hexdigest()==release_hash
print('Backup:',backup)
print('Personal restored; release unchanged:',release_hash)
