# Windows 11 Laptop Freeze Troubleshooting

## Issue Description
- **Symptoms**: Local Windows 11 laptop freezes for seconds at a time
- **Behavior**: System becomes unresponsive to keyboard/mouse input, but caches actions that execute when responsive again
- **Connection**: Accessing dev LXC via PuTTY from the freezing laptop
- **Date**: 2025-11-06

## System Information
- **OS**: Windows 11
- **Computer**: AX16Pro
- **CPU**: AMD Processor (16 cores visible)
- **Memory**: 7.3 GB available of total system memory
- **Storage**: NVMe SSD - Temperature: 45°C, Wear: 0, No errors detected

## Diagnostics Performed

### 1. Hardware Health Checks
```powershell
Get-PhysicalDisk | Get-StorageReliabilityCounter
```
- ✅ Disk health: Good (Temp: 45°C, Wear: 0, no read/write errors)
- ✅ Memory: Healthy (7342 MB available, 12.7 GB committed, 856 MB paged pool)

### 2. Driver Analysis
```powershell
driverquery /v > C:\drivers.txt
Get-WmiObject Win32_PnPSignedDriver | Where-Object {$_.DeviceName -like "*AMD*" -or $_.DeviceName -like "*Radeon*"}
```

**Key Finding - AMD Graphics Driver:**
- Device: AMD Radeon(TM) Graphics
- Driver Version: 31.0.21923.1000
- Driver Date: **March 6, 2025** (VERY RECENT - likely suspect)
- Memory footprint: amdwddmg driver has 82MB paged pool (unusually large)

### 3. Error Log Analysis
```powershell
Get-EventLog -LogName System -EntryType Error -Newest 20
Get-WinEvent -FilterHashtable @{LogName='System'; Level=2,3; StartTime=(Get-Date).AddDays(-1)}
```
- ✅ No driver crashes logged
- ✅ No timeout/hang/freeze errors in event logs
- Indicates: Likely resource contention or silent driver issues

## Mitigations Applied

### 1. Disabled Windows Search Indexing
```powershell
Stop-Service "WSearch" -Force
Set-Service "WSearch" -StartupType Disabled
```

### 2. Performance Monitor Data Collector Created
```powershell
logman create counter FreezeMonitor -f bincirc -v mmddhhmm -max 500 \
  -c "\Processor(_Total)\% Processor Time" \
  "\Processor(_Total)\% Interrupt Time" \
  "\Memory\Available MBytes" \
  -si 15

logman start FreezeMonitor
```
- **Status**: Running
- **Log Location**: `C:\PerfLogs\Admin\FreezeMonitor_11060920.blg`
- **Sample Interval**: 15 seconds

### 3. Real-Time Monitoring Script
Created PowerShell monitoring script that displays:
- CPU usage (red if >80%)
- Memory usage (red if >90%)
- Disk usage (red if >90%)
- Top CPU and memory processes
- Updates every 2 seconds

## Primary Suspects (In Order)

### 1. AMD Graphics Driver (40% probability)
- **Evidence**: 
  - Brand new driver (March 6, 2025)
  - Large memory footprint (82MB paged pool)
  - New drivers often have bugs causing freezes
- **Test**: Disable hardware acceleration in browsers
- **Fix**: Roll back driver via Device Manager

### 2. Disk I/O Stalls (30% probability)
- **Evidence**: Common Windows 11 issue
- **Test**: Monitor disk queue length during freeze
- **Check**: Resource Monitor for response time >100ms

### 3. USB Device Issues (20% probability)
- **Evidence**: Multiple USB drivers loaded (Realtek, VirtualBox, FTDI, CH341, CH343)
- **Test**: Unplug non-essential USB devices
- **Affected drivers**: 
  - Realtek USB Ethernet (rtucx22x64, msu53cx22x64)
  - VirtualBox USB (VBoxUSB, VBoxUSBMon)
  - Serial adapters (FTDI, CH341, CH343, Cypress)

### 4. Network Driver (10% probability)
- **Evidence**: Realtek WiFi driver (rtwlanu7) dated 12/30/2024
- **Test**: Disable WiFi temporarily

## Recommended Troubleshooting Steps

### When Next Freeze Occurs:
1. **Observe real-time monitor** - note which metric spikes (CPU/Memory/Disk)
2. **After freeze**, check recent errors:
   ```powershell
   Get-WinEvent -FilterHashtable @{LogName='System'; Level=2,3; StartTime=(Get-Date).AddMinutes(-5)}
   ```
3. **Stop and analyze performance log**:
   ```powershell
   logman stop FreezeMonitor
   perfmon /sys  # Open the .blg file
   ```

### Quick Tests to Try:
1. **Disable GPU hardware acceleration** (browsers, Discord, etc.)
2. **Unplug all non-essential USB devices**
3. **Roll back AMD graphics driver** (Device Manager → Display adapters → Properties → Driver → Roll Back)
4. **Check for Windows Updates** that might fix driver issues

### Commands for Analysis:
```powershell
# Check DPC/Interrupt time (should be <5% and <3%)
typeperf "\Processor(_Total)\% Interrupt Time" "\Processor(_Total)\% DPC Time" -sc 5

# Check current system counters
Get-Counter '\Memory\Available MBytes','\Memory\Committed Bytes','\Memory\Pool Paged Bytes'

# View performance log
perfmon /sys

# Check Event Viewer custom view for errors around freeze time
eventvwr.msc
```

## Notable Drivers/Services
- **AMD Crash Defender**: Running (amdfendr, amdfendrmgr)
- **Bluetooth**: Multiple Bluetooth drivers active (BTHPORT, BTHUSB, RtkBtFilter)
- **Wireless**: Realtek WiFi (rtwlanu7) - Driver date: 12/30/2024
- **Storage**: GeneStor (Genesys card reader), stornvme (NVMe controller)
- **Audio**: Multiple audio interfaces (CnxtHdAudServ, AtiHDAudioServe, AMD Audio CoProc)

## Files Created
- `C:\drivers.txt` - Full driver list output
- `C:\PerfLogs\Admin\FreezeMonitor_11060920.blg` - Performance counter log

## Next Session Actions
1. Review performance counter log after a freeze is captured
2. Analyze Event Viewer for errors during freeze timeframe
3. Consider AMD driver rollback if GPU-related
4. Test with minimal USB devices if USB-related
5. Check disk response times if disk-related
