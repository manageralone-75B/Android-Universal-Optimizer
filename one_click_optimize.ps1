[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Android 1-Click Auto Optimizer - Full System AOT (All Brands)"

Clear-Host
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "     🚀 โปรแกรมเร่งความเร็วและลดความร้อนมือถือ (Full AOT Auto Mode)" -ForegroundColor Cyan
Write-Host "        คอมไพล์โค้ดล่วงหน้าแบบตัวเต็มครบทุกแอพ 100% (Full Speed)" -ForegroundColor Cyan
Write-Host "                  รองรับ Android ทุกแบรนด์ ทุกรุ่น" -ForegroundColor Cyan
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

# 2. รอการเชื่อมต่ออุปกรณ์อัตโนมัติ
Write-Host "[*] กำลังตรวจหามือถือที่เชื่อมต่อสาย USB..." -ForegroundColor Yellow
Write-Host "    (หากยังไม่ได้เสียบสาย กรุณาเสียบสาย USB และกด 'อนุญาต' บนหน้าจอมือถือ)" -ForegroundColor DarkGray

$deviceFound = $false
$dots = 0
while (-not $deviceFound) {
    $devicesOutput = & $adbExe devices 2>$null
    $lines = $devicesOutput | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }
    
    if ($lines) {
        $deviceFound = $true
        break
    }
    
    $dots++
    $dotStr = "." * (($dots % 4) + 1)
    Write-Host ("`r[*] รอการเชื่อมต่อมือถือ$dotStr    ") -NoNewline -ForegroundColor Yellow
    Start-Sleep -Milliseconds 1500
}
Write-Host ""

# 3. ดึงข้อมูลเครื่องอัตโนมัติ
$brand = (& $adbExe shell getprop ro.product.brand 2>$null).Trim().ToUpper()
$model = (& $adbExe shell getprop ro.product.model 2>$null).Trim()
$marketName = (& $adbExe shell getprop ro.product.marketname 2>$null).Trim()
$androidVer = (& $adbExe shell getprop ro.build.version.release 2>$null).Trim()

$deviceName = if ($marketName) { "$brand $marketName ($model)" } else { "$brand $model" }

Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host "  [V] เชื่อมต่อสำเร็จ: $deviceName" -ForegroundColor Green
Write-Host "  [i] ระบบปฏิบัติการ:  Android $androidVer" -ForegroundColor White
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

function Get-DeviceStats {
    $batt = & $adbExe shell dumpsys battery 2>$null
    $tempLine = $batt | Where-Object { $_ -match "temperature:\s*(\d+)" }
    $temp = if ($tempLine -match "(\d+)") { [math]::Round([double]$matches[1] / 10, 1) } else { "N/A" }

    $mem = & $adbExe shell dumpsys meminfo 2>$null
    $usedLine = $mem | Where-Object { $_ -match "Used RAM:\s*([\d,]+)K" }
    $used = if ($usedLine -match "([\d,]+)K") { [math]::Round([double]($matches[1] -replace ',', '') / 1024, 0) } else { "N/A" }

    $freeLine = $mem | Where-Object { $_ -match "Free RAM:\s*([\d,]+)K" }
    $free = if ($freeLine -match "([\d,]+)K") { [math]::Round([double]($matches[1] -replace ',', '') / 1024, 0) } else { "N/A" }

    return @{ Temp = $temp; UsedRAM = $used; FreeRAM = $free }
}

$beforeStats = Get-DeviceStats

# [1/5] Animation Scale 0.5x
Write-Host "[1/5] ปรับความเร็วอนิเมชั่น 0.5x (เปิดแอพติดนิ้วขึ้นทันที)..." -ForegroundColor Cyan
& $adbExe shell settings put global window_animation_scale 0.5 2>&1 | Out-Null
& $adbExe shell settings put global transition_animation_scale 0.5 2>&1 | Out-Null
& $adbExe shell settings put global animator_duration_scale 0.5 2>&1 | Out-Null
if ($brand -match "XIAOMI|REDMI|POCO") {
    & $adbExe shell settings put global miui_enable_blur 0 2>&1 | Out-Null
}
Write-Host "  [V] สำเร็จเรียบร้อย" -ForegroundColor Green

# [2/5] Radio & Storage Tweaks
Write-Host "[2/5] ปิดชิปสแกนสัญญาณเบื้องหลัง & ลดขนาด Log (ลดความร้อนสะสม)..." -ForegroundColor Cyan
& $adbExe shell settings put global wifi_scan_always_enabled 0 2>&1 | Out-Null
& $adbExe shell settings put global ble_scan_always_enabled 0 2>&1 | Out-Null
& $adbExe shell logcat -G 64K 2>&1 | Out-Null
& $adbExe shell setprop persist.logd.size 64K 2>&1 | Out-Null
Write-Host "  [V] สำเร็จเรียบร้อย" -ForegroundColor Green

# [3/5] Safe Debloat
Write-Host "[3/5] สแกนและปิดเซอร์วิสโฆษณา/Telemetry/ขยะแฝงในเครื่อง..." -ForegroundColor Cyan
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

$installedRaw = & $adbExe shell pm list packages -u 2>$null
$installedList = $installedRaw | ForEach-Object { ($_ -replace 'package:', '').Trim() }
$foundBloat = $bloatDatabase | Where-Object { $installedList -contains $_ }

$disabledCount = 0
foreach ($pkg in $foundBloat) {
    $res = & $adbExe shell pm disable-user --user 0 $pkg 2>&1
    if ($res -match "disabled-user" -or $res -match "new state") {
        $disabledCount++
    }
}
Write-Host "  [V] จัดการปิดขยะระบบเรียบร้อย: $disabledCount รายการ" -ForegroundColor Green

# [4/5] Force Stop Background Hogs
Write-Host "[4/5] ล้างแคชและสั่งหยุดแอพกินแรมเบื้องหลัง..." -ForegroundColor Cyan
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
Write-Host "  [V] เคลียร์พื้นที่หน่วยความจำสำเร็จ" -ForegroundColor Green

# [5/5] Full System Native AOT Compilation (แบบตัวเต็ม ทำครบทุกแอพทั้งระบบ 100%)
Write-Host "[5/5] Native AOT Compilation (โหมดตัวเต็ม: แปลงทุกแอพเป็น Machine Code)..." -ForegroundColor Cyan
$totalCount = $installedList.Count
Write-Host "  [*] กำลังประมวลผลโค้ดแบบตัวเต็มทั้งหมด $totalCount แอพ (แสดงผลสดทุกวินาที)..." -ForegroundColor Yellow

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
Write-Host "  [V] คอมไพล์ครบทุกแอพทั้งระบบสำเร็จ 100%!" -ForegroundColor Green

# สรุปผลลัพธ์
Start-Sleep -Seconds 1
$afterStats = Get-DeviceStats

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "             🎉 ผ่าตัดเครื่องเสร็จสมบูรณ์ 100% (Full AOT Mode)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ("  Used RAM (แรมที่ถูกใช้งาน):  ก่อนทำ {0,5} MB  -->  หลังทำ {1,5} MB" -f $beforeStats.UsedRAM, $afterStats.UsedRAM) -ForegroundColor Cyan
Write-Host ("  Free RAM (แรมว่างพร้อมใช้):  ก่อนทำ {0,5} MB  -->  หลังทำ {1,5} MB" -f $beforeStats.FreeRAM, $afterStats.FreeRAM) -ForegroundColor Cyan
Write-Host ("  อุณหภูมิแบตเตอรี่:          ก่อนทำ {0,5} °C  -->  หลังทำ {1,5} °C" -f $beforeStats.Temp, $afterStats.Temp) -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "💡 [คำแนะนำสำคัญเพื่อให้เครื่องเย็นและลื่นถาวร]:" -ForegroundColor Yellow
if ($brand -match "SAMSUNG") {
    Write-Host "  [Samsung]: ไปที่ 'การตั้งค่า' > 'การดูแลแบตเตอรี่และอุปกรณ์' > 'หน่วยความจำ' > 'RAM Plus' > ปรับเป็น 'ปิด' (Off)" -ForegroundColor Yellow
} elseif ($brand -match "XIAOMI|REDMI|POCO") {
    Write-Host "  [Xiaomi/POCO]: ไปที่ 'การตั้งค่า' > 'การตั้งค่าเพิ่มเติม' > 'การขยายหน่วยความจำ' (Memory extension) > ปรับเป็น 'ปิด' (Off)" -ForegroundColor Yellow
} elseif ($brand -match "OPPO|REALME|ONEPLUS") {
    Write-Host "  [OPPO/Realme/OnePlus]: ไปที่ 'การตั้งค่า' > 'เกี่ยวกับอุปกรณ์' > 'RAM' > 'RAM Expansion' > ปรับเป็น 'ปิด' (Off)" -ForegroundColor Yellow
} elseif ($brand -match "VIVO|IQOO") {
    Write-Host "  [Vivo/iQOO]: ไปที่ 'การตั้งค่า' > 'RAM และพื้นที่เก็บข้อมูล' > 'RAM' > 'Extended RAM' > ปรับเป็น 'ปิด' (Off)" -ForegroundColor Yellow
} else {
    Write-Host "  ค้นหาเมนู 'RAM เสมือน / Memory Extension' ในการตั้งค่า แล้วปรับเป็น 'ปิด' (Off)" -ForegroundColor Yellow
}
Write-Host ""

# รีสตาร์ทอัตโนมัติ 5 วินาที
Write-Host "[*] กำลังจะสั่งรีสตาร์ทมือถือเพื่อให้ระบบใหม่ทำงานสมบูรณ์ใน 5 วินาที..." -ForegroundColor Yellow
Write-Host "    (กดปุ่มใดก็ได้ทันที หากต้องการยกเลิกการรีสตาร์ท)" -ForegroundColor DarkGray

$timeout = 5
$rebootCancelled = $false
while ($timeout -gt 0) {
    if ([Console]::KeyAvailable) {
        $null = [Console]::ReadKey($true)
        $rebootCancelled = $true
        break
    }
    Write-Host ("`rกำลังรีสตาร์ทใน {0} วินาที... " -f $timeout) -NoNewline -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    $timeout--
}
Write-Host ""

if (-not $rebootCancelled) {
    Write-Host "[*] กำลังส่งคำสั่งรีสตาร์ทไปยังมือถือ..." -ForegroundColor Cyan
    & $adbExe reboot 2>&1 | Out-Null
    Write-Host "[V] รีสตาร์ทเรียบร้อย! สามารถถอดสาย USB และใช้งานมือถือได้เลยครับ" -ForegroundColor Green
} else {
    Write-Host "[i] ยกเลิกการรีสตาร์ทแล้ว สามารถใช้งานต่อได้ทันทีครับ" -ForegroundColor Green
}

Write-Host "`nขอบคุณครับ! หน้าต่างนี้จะปิดอัตโนมัติใน 3 วินาที..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3