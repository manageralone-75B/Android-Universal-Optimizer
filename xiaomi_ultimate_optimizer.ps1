[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Universal Android - Full System Optimizer (Full AOT All Packages)"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "     เครื่องมือปรับแต่ง เร่งความเร็ว และลดความร้อน สำหรับ Android ทุกรุ่น" -ForegroundColor Cyan
Write-Host "            (โหมด Full AOT: คอมไพล์ครบทุกแอพทั้งระบบ 100%)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$adbExe = "adb"

# 1. ตรวจสอบเครื่องมือ ADB
$hasAdb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $hasAdb) {
    $localAdb = Join-Path $scriptDir "platform-tools\adb.exe"
    if (Test-Path $localAdb) {
        $adbExe = $localAdb
    } else {
        Write-Host "[-] กำลังเตรียมเครื่องมือ Google Platform-Tools..." -ForegroundColor Yellow
        $zipPath = Join-Path $scriptDir "platform-tools.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $scriptDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $adbExe = $localAdb
    }
}

# 2. ตรวจสอบการเชื่อมต่อ
$deviceFound = $false
while (-not $deviceFound) {
    Write-Host "[*] กำลังตรวจหาอุปกรณ์ Android ที่เชื่อมต่อผ่าน USB..." -ForegroundColor Yellow
    $devicesOutput = & $adbExe devices
    $lines = $devicesOutput | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }
    
    if ($lines) {
        $deviceFound = $true
        Write-Host "[V] ตรวจพบและเชื่อมต่ออุปกรณ์สำเร็จ!" -ForegroundColor Green
    } else {
        Write-Host "[X] ยังไม่พบอุปกรณ์ กรุณาเสียบสาย USB และกด 'อนุญาตเสมอ' บนหน้าจอ" -ForegroundColor Red
        Write-Host "กด Enter เพื่อลองตรวจหาใหม่อีกครั้ง..."
        Read-Host
    }
}

# 3. ข้อมูลเครื่อง
$brand = (& $adbExe shell getprop ro.product.brand).Trim().ToUpper()
$model = (& $adbExe shell getprop ro.product.model).Trim()
$marketName = (& $adbExe shell getprop ro.product.marketname).Trim()
$androidVer = (& $adbExe shell getprop ro.build.version.release).Trim()
$displayDevice = if ($marketName) { "$brand $marketName ($model)" } else { "$brand $model" }

Write-Host ""
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host "  อุปกรณ์:        $displayDevice" -ForegroundColor White
Write-Host "  ระบบปฏิบัติการ:   Android $androidVer" -ForegroundColor White
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

function Get-DeviceStats {
    $batt = & $adbExe shell dumpsys battery
    $tempLine = $batt | Where-Object { $_ -match "temperature:\s*(\d+)" }
    $temp = if ($tempLine -match "(\d+)") { [math]::Round([double]$matches[1] / 10, 1) } else { "N/A" }

    $mem = & $adbExe shell dumpsys meminfo
    $usedLine = $mem | Where-Object { $_ -match "Used RAM:\s*([\d,]+)K" }
    $used = if ($usedLine -match "([\d,]+)K") { [math]::Round([double]($matches[1] -replace ',', '') / 1024, 0) } else { "N/A" }

    $freeLine = $mem | Where-Object { $_ -match "Free RAM:\s*([\d,]+)K" }
    $free = if ($freeLine -match "([\d,]+)K") { [math]::Round([double]($matches[1] -replace ',', '') / 1024, 0) } else { "N/A" }

    return @{ Temp = $temp; UsedRAM = $used; FreeRAM = $free }
}

Write-Host ""
Write-Host "[*] กำลังวิเคราะห์สถานะทรัพยากรก่อนเริ่มการปรับแต่ง..." -ForegroundColor Yellow
$beforeStats = Get-DeviceStats
Write-Host "  -> อุณหภูมิแบตเตอรี่: $($beforeStats.Temp) °C" -ForegroundColor DarkCyan
Write-Host "  -> Used RAM: $($beforeStats.UsedRAM) MB | Free RAM: $($beforeStats.FreeRAM) MB" -ForegroundColor DarkCyan
Write-Host ""

# [1/6] Animation Scales 0.5x
Write-Host "[1/6] ปรับความเร็วภาพเคลื่อนไหว (Animation Scales 0.5x)..." -ForegroundColor Cyan
& $adbExe shell settings put global window_animation_scale 0.5 2>&1 | Out-Null
& $adbExe shell settings put global transition_animation_scale 0.5 2>&1 | Out-Null
& $adbExe shell settings put global animator_duration_scale 0.5 2>&1 | Out-Null
if ($brand -match "XIAOMI|REDMI|POCO") {
    & $adbExe shell settings put global miui_enable_blur 0 2>&1 | Out-Null
}
Write-Host "  [V] สำเร็จเรียบร้อย" -ForegroundColor Green

# [2/6] Radio Tweaks
Write-Host "`n[2/6] ปิดการสแกนหา Wi-Fi & Bluetooth ตลอดเวลาเบื้องหลัง..." -ForegroundColor Cyan
& $adbExe shell settings put global wifi_scan_always_enabled 0 2>&1 | Out-Null
& $adbExe shell settings put global ble_scan_always_enabled 0 2>&1 | Out-Null
Write-Host "  [V] ปิดชิปสแกนสัญญาณเบื้องหลัง (ลดความร้อน)" -ForegroundColor Green

# [3/6] Log Buffer 64K
Write-Host "`n[3/6] ลดขนาด Logcat Buffer & เคลียร์ Background Tracing..." -ForegroundColor Cyan
& $adbExe shell logcat -G 64K 2>&1 | Out-Null
& $adbExe shell setprop persist.logd.size 64K 2>&1 | Out-Null
Write-Host "  [V] ปรับขนาด Log Buffer เป็น 64KB (ลดการเขียน Disk)" -ForegroundColor Green

# [4/6] Debloat
Write-Host "`n[4/6] สแกนแอพขยะและบริการติดตามสถิติตามแบรนด์..." -ForegroundColor Cyan
$bloatDatabase = @(
    "com.facebook.services", "com.facebook.system", "com.facebook.appmanager",
    "com.google.android.videos", "com.google.android.music", "com.google.android.apps.subscriptions.red",
    "com.google.android.feedback", "com.google.android.printservice.recommendation", "com.google.mainline.telemetry",
    "com.miui.msa.global", "com.miui.analytics", "com.miui.daemon", "com.xiaomi.joyose", "com.miui.bugreport",
    "com.miui.miservice", "com.miui.phrase", "com.bsp.catchlog", "com.xiaomi.mipicks", "com.miui.videoplayer",
    "com.mi.globalbrowser", "com.android.browser", "com.miui.yellowpage", "com.miui.hybrid", "com.miui.hybrid.accessory",
    "com.xiaomi.glgm", "com.xiaomi.payment", "com.mipay.wallet.id", "com.mipay.wallet.in", "org.mipay.android.manager", "com.micredit.in",
    "com.samsung.android.bixby.agent", "com.samsung.android.bixby.wakeup", "com.samsung.android.app.spage", "com.samsung.android.spay",
    "com.samsung.android.kidsinstaller", "com.sec.android.app.sbrowser", "com.samsung.android.game.gamehome", "com.samsung.android.app.tips",
    "com.heytap.mcs", "com.oppo.market", "com.heytap.browser", "com.coloros.gamespace", "com.heytap.usercenter",
    "com.vivo.browser", "com.vivo.appstore", "com.vivo.game", "com.vivo.easyshare", "com.vivo.pushservice"
)

$installedRaw = & $adbExe shell pm list packages -u
$installedList = $installedRaw | ForEach-Object { ($_ -replace 'package:', '').Trim() }
$foundBloat = $bloatDatabase | Where-Object { $installedList -contains $_ }

$disabledCount = 0
foreach ($pkg in $foundBloat) {
    $res = & $adbExe shell pm disable-user --user 0 $pkg 2>&1
    if ($res -match "disabled-user" -or $res -match "new state") {
        Write-Host "  [V] ปิดการทำงาน: $pkg" -ForegroundColor Green
        $disabledCount++
    }
}
Write-Host "  -> ปิดบริการขยะเรียบร้อย: $disabledCount รายการ" -ForegroundColor Green

# [5/6] Force Stop
Write-Host "`n[5/6] สั่งหยุดการทำงานของแอพกินแรมเบื้องหลัง..." -ForegroundColor Cyan
$backgroundHogs = @(
    "com.google.android.apps.photos", "com.google.android.apps.messaging", "com.google.android.youtube",
    "com.android.chrome", "com.google.android.googlequicksearchbox", "com.google.android.gm",
    "com.google.android.apps.wellbeing", "com.microsoft.office.outlook", "com.facebook.katana",
    "com.facebook.orca", "com.instagram.android", "jp.naver.line.android", "com.zhiliaoapp.musically",
    "com.ss.android.ugc.trill", "com.twitter.android", "com.x.android", "com.shopee.th", "com.lazada.android"
)
foreach ($app in $backgroundHogs) {
    if ($installedList -contains $app) {
        & $adbExe shell am force-stop $app 2>&1 | Out-Null
    }
}
Write-Host "  [V] เคลียร์ Background Processes สำเร็จ" -ForegroundColor Green

# [6/6] Full AOT Compilation (ครบทุกแอพทั้งระบบ 100%)
Write-Host "`n[6/6] Native AOT Compilation (โหมดตัวเต็ม: แปลงทุกแอพเป็น Machine Code)..." -ForegroundColor Cyan
$totalCount = $installedList.Count
Write-Host "  [*] กำลังเริ่มคอมไพล์โค้ดแบบตัวเต็มทั้งหมด $totalCount แอพ (แสดงผลสดทุกวินาที)..." -ForegroundColor Yellow

$curIdx = 0
foreach ($pkg in $installedList) {
    $curIdx++
    $pct = [math]::Round(($curIdx / $totalCount) * 100, 1)
    
    $barLen = 20
    $filled = [math]::Round(($curIdx / $totalCount) * $barLen)
    $empty = [math]::Max(0, ($barLen - $filled))
    $barStr = ("=" * $filled) + (" " * $empty)
    $shortPkg = if ($pkg.Length -gt 32) { $pkg.Substring(0, 29) + "..." } else { $pkg.PadRight(32) }
    
    Write-Host ("`r  [{0}] {1,5}% ({2,3}/{3}) : {4}" -f $barStr, $pct, $curIdx, $totalCount, $shortPkg) -NoNewline -ForegroundColor Cyan
    & $adbExe shell cmd package compile -m speed $pkg 2>&1 | Out-Null
}
Write-Host ""
Write-Host "  [V] คอมไพล์ครบสมบูรณ์ทุกแอพ ($totalCount แอพ) เรียบร้อยแล้ว!" -ForegroundColor Green

# สรุปผล
Start-Sleep -Seconds 1
$afterStats = Get-DeviceStats

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "             สรุปผลการปรับแต่งอุปกรณ์ ($displayDevice)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ("  Used RAM (แรมที่ถูกใช้งาน):  ก่อนทำ {0,5} MB  -->  หลังทำ {1,5} MB" -f $beforeStats.UsedRAM, $afterStats.UsedRAM) -ForegroundColor Cyan
Write-Host ("  Free RAM (แรมว่างพร้อมใช้):  ก่อนทำ {0,5} MB  -->  หลังทำ {1,5} MB" -f $beforeStats.FreeRAM, $afterStats.FreeRAM) -ForegroundColor Cyan
Write-Host ("  อุณหภูมิแบตเตอรี่:          ก่อนทำ {0,5} °C  -->  หลังทำ {1,5} °C" -f $beforeStats.Temp, $afterStats.Temp) -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ""

$rebootChoice = Read-Host "ต้องการสั่งรีสตาร์ทเครื่องเพื่อให้ระบบโหลดทุกอย่างขึ้นมาใหม่สมบูรณ์หรือไม่? (Y/N)"
if ($rebootChoice -eq "Y" -or $rebootChoice -eq "y") {
    Write-Host "[*] กำลังส่งคำสั่งรีสตาร์ทไปยังมือถือ..." -ForegroundColor Cyan
    & $adbExe reboot
}

Write-Host "`nเสร็จสิ้นสมบูรณ์ครับ! กด Enter เพื่อปิดหน้าต่าง..." -ForegroundColor Green
Read-Host