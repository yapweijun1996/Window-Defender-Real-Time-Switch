# Window-Defender-Real-Time-Switch

Tiny batch + PowerShell scripts to **toggle Microsoft Defender Real-time protection** and optionally **auto-disable it at startup**.

> ⚠️ **Use at your own risk.** Disabling real-time protection reduces security. On managed (work/school) PCs, policies may block these changes.

---

## Files

* `defender_rt_on.bat` – Enable Defender **Real-time protection**.
* `defender_rt_off.bat` – Disable Defender **Real-time protection**.
* `check_rt_status.bat` – Print current status (`True`/`False`).
* `install_wd_rt_auto_off.bat` – Install a **Scheduled Task** that turns RT **OFF** at **logon** (runs as `SYSTEM`), with built-in verification and functional testing.
* `remove_wd_rt_auto_off.bat` – Remove that Scheduled Task.
* `verify_wd_rt_auto_off.bat` – Standalone verification script for the scheduled task (optional).
* `repair_wd_rt_task.bat` – Repair/recreate the scheduled task with boot trigger and functional testing.
* `wd_rt_task_doctor.bat` – Diagnostic and auto-repair script for the scheduled task.

All scripts require **Administrator**.

---

## Requirements

1. **Run as Administrator** (right-click → *Run as administrator*).
2. **Tamper Protection** must be **OFF**
   Windows Security → *Virus & threat protection* → *Tamper Protection*.
   If it’s ON, Windows will block the change.
3. On work/school devices, **GPO/MDM** may override these settings.

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

### Auto-disable on every logon

Creates a logon task that runs as **SYSTEM** and flips RT off silently after user login. The installer now includes built-in verification and functional testing.

```bat
install_wd_rt_auto_off.bat
```

Remove the task anytime:

```bat
remove_wd_rt_auto_off.bat
```

### Repair and diagnose the task

If the auto-disable task isn't working, use these scripts to diagnose and repair:

```bat
# Comprehensive diagnostic and auto-repair
wd_rt_task_doctor.bat

# Force recreate with boot trigger
repair_wd_rt_task.bat

# Verify existing task functionality
verify_wd_rt_auto_off.bat
```

---

## How it works (Mermaid)

### 1) Auto-disable at logon (flow)

```mermaid
flowchart TD
     A[User logs on] --> B[Task Scheduler triggers WD-RT-AutoOff@Logon SYSTEM]
     B --> C[PowerShell delay 30s let Defender initialize]
     C --> D[Set-MpPreference -DisableRealtimeMonitoring $true]
     D --> E{Success?}
     E -- Yes --> F[Write log to %ProgramData%\\wd-rt-toggle.log]
     E -- No --> G[Likely Tamper Protection or GPO/MDM]
     F --> H[RT = OFF]
     G --> H2[RT may remain ON]
```

### 2) Manual toggle (sequence)

```mermaid
sequenceDiagram
    participant User
    participant Batch as Batch (.bat)
    participant PS as PowerShell
    participant Defender

    User->>Batch: Run defender_rt_off.bat (Admin)
    Batch->>PS: Set-MpPreference -DisableRealtimeMonitoring $true
    PS->>Defender: Apply preference
    Defender-->>PS: Status = OFF/ON (depending on policy)
    PS-->>User: RealTimeProtectionEnabled = False/True

    User->>Batch: Run defender_rt_on.bat (Admin)
    Batch->>PS: Set-MpPreference -DisableRealtimeMonitoring $false
    PS->>Defender: Apply preference
    Defender-->>PS: Status = ON
    PS-->>User: RealTimeProtectionEnabled = True
```

### 3) Defender RT state (with policies)

```mermaid
stateDiagram-v2
    [*] --> ON
    ON --> OFF: defender_rt_off.bat<br/>auto task
    OFF --> ON: defender_rt_on.bat<br/>policy re-enable
    ON --> ON: GPO/MDM or Tamper Protection blocks change
    OFF --> OFF: Task rerun / user keeps off

    note right of OFF
      OFF = Real-time protection disabled.
      May revert to ON if:
      • Tamper Protection is ON
      • Org policy enforces Defender
    end note
```

---

## What the installer creates

* **Scheduled Task name:** `WD-RT-AutoOff@Logon`
  Trigger: **At logon** → runs as **SYSTEM**, **highest privileges**
* **Log file:** `%ProgramData%\wd-rt-toggle.log` (one line per run)
* **Installer now includes:** Built-in verification and functional testing

---

## Verify it works (optional)

The installer now includes built-in verification and functional testing. For standalone verification, run as **Administrator**:

```bat
verify_wd_rt_auto_off.bat
:: or wait longer before checking (in seconds)
verify_wd_rt_auto_off.bat 30
```

Expected output: `RealTimeProtectionEnabled = False`.

---

## Troubleshooting

* **“Access is denied” / “UnauthorizedAccess” / no effect**

  * Turn **Tamper Protection** OFF.
  * Ensure the `.bat` was run **as Administrator**.
  * Org policies (GPO/MDM) or 3rd-party AV may re-enable Defender.

* **Task exists but RT stays ON after logon**

  * Increase the delay inside the installer (default 30s, can be adjusted) and reinstall.
  * Some environments force Defender back ON shortly after logon.

* **Check current state quickly**

  ```bat
  check_rt_status.bat
  ```

  `False` means real-time protection is OFF.

---

## Security note

These scripts deliberately weaken protection. **Use only on trusted, isolated machines** (dev/lab). You are responsible for complying with your organization’s policies and local laws.

---

## License

MIT — see `LICENSE` for details.
Copyright (c) 2025 **Wei Jun**

---

## Credits

* Built-in PowerShell cmdlets: `Set-MpPreference`, `Get-MpComputerStatus`, `Start-Service`, `Register-ScheduledTask`.
* Pure **Batch + PowerShell**. No external dependencies.
