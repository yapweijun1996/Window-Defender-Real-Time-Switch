# wd-rt-toggle

Tiny batch + PowerShell scripts to **toggle Microsoft Defender Real-time protection** and optionally **auto-disable it at startup**.

> ⚠️ **Use at your own risk.** Turning off real-time protection lowers security. On managed (work/school) PCs, policies may block these changes.

---

## Contents

* `defender_rt_on.bat` – Enable Defender **Real-time protection**.
* `defender_rt_off.bat` – Disable Defender **Real-time protection**.
* `check_rt_status.bat` – Print current status (`True`/`False`).
* `install_wd_rt_auto_off.bat` – Create a **Scheduled Task** to auto-disable RT at every **startup**.
* `remove_wd_rt_auto_off.bat` – Remove that Scheduled Task.

All scripts are Windows-native and require **Administrator**.

---

## Requirements

1. **Run as Administrator** (right-click → *Run as administrator*).
2. **Tamper Protection** must be **OFF**
   Windows Security → *Virus & threat protection* → *Tamper Protection*.
   If it’s ON, Windows will block the change.
3. On work/school devices, **GPO/MDM** may prevent changes.

---

## Quick Start

### Toggle manually

```bat
:: turn OFF real-time protection
defender_rt_off.bat

:: turn ON real-time protection
defender_rt_on.bat

:: check status (False = OFF, True = ON)
check_rt_status.bat
```

### Auto-disable on every reboot (background)

Creates a **startup** task that runs as **SYSTEM** and flips RT off silently.

```bat
install_wd_rt_auto_off.bat
```

* A small delay is used to let Defender initialize, then `Set-MpPreference -DisableRealtimeMonitoring $true` is applied.
* A log line is appended to `%ProgramData%\wd-rt-toggle.log`.

Remove the task anytime:

```bat
remove_wd_rt_auto_off.bat
```

---

## What gets created

* **Scheduled Task name:** `WD-RT-AutoOff@Startup`
  Trigger: `At startup` (runs as `SYSTEM`, highest privileges)

* **Log file:** `%ProgramData%\wd-rt-toggle.log` (optional status lines)

---

## Troubleshooting

* **“Access is denied” / “UnauthorizedAccess” / no effect**

  * Turn **Tamper Protection** OFF.
  * Make sure you launched the `.bat` **as Administrator**.
  * Some organizations enforce Defender via **Group Policy/MDM** (cannot be overridden).

* **Task exists but RT stays ON after boot**

  * Open Windows Security soon after logging in—if it flips back ON automatically, a policy or third-party AV is enforcing it.
  * Increase the delay in the installer script (e.g., from 15s to 30s) and reinstall the task.

* **Check current state**

  ```bat
  check_rt_status.bat
  ```

  `False` means real-time protection is OFF.

---

## Safety & Disclaimer

These scripts modify Windows Defender settings and reduce protection. **Only use in trusted, isolated environments** (e.g., dev machines, labs). You are responsible for compliance with your organization’s policies and local laws.

---

## License

MIT — do whatever you want, but no warranty.

```
MIT License

Copyright (c) 2025 <Your Name>

Permission is hereby granted, free of charge, to any person obtaining a copy...
```

---

## Credits

* Uses built-in PowerShell cmdlets: `Set-MpPreference`, `Get-MpComputerStatus`, `Start-Service`.
* Pure batch + PowerShell; no external dependencies.

---

**Tip（简中小贴士）**：如果开机后自动又被打开，多半是 **Tamper Protection** 或公司策略在强制开启；先关掉 Tamper Protection，再以管理员运行脚本。
