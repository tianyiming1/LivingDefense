# S1Autoplay 5-run stress test - output to stdout
$GodotExe = "D:\softwares\Godot_unzipped\Godot_v4.5.1-stable_win64.exe"
$ProjectDir = "D:\GameWorkSpace\TowerDefenseProto"

$Runs = 5
$AcceptCount = 0

Write-Host "=== S1Autoplay 5-run stress test ===" -ForegroundColor Cyan
Write-Host "Config: v12.1 (runner slope 1.5)" -ForegroundColor Cyan
Write-Host "_process -> _physics_process applied" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host "" -NoNewline
    Write-Host "=== Run ${i}/$Runs ===" -ForegroundColor Yellow
    
    $args = @("--path", $ProjectDir, "--scene", "res://tests/S1Autoplay.tscn", "--quit-after", "1")
    $process = Start-Process -FilePath $GodotExe -ArgumentList $args -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "PASS Run ${i}: ACCEPT" -ForegroundColor Green
        $AcceptCount++
    } else {
        Write-Host "FAIL Run ${i}: REJECT (exit $($process.ExitCode))" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Total: $Runs, ACCEPT: $AcceptCount, REJECT: $($Runs - $AcceptCount)" -ForegroundColor Cyan

if ($AcceptCount -eq $Runs) {
    Write-Host "=== ALL RUNS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== SOME RUNS FAILED ===" -ForegroundColor Red
}
