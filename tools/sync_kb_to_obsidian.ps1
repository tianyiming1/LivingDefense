# kb -> Obsidian 镜像同步脚本
# 源: D:\GameWorkSpace\TowerDefenseProto\kb  (项目知识库, 权威)
# 目标: D:\AI_Knowledge\Projects\TowerDefenseProto  (Obsidian 库镜像)
# 用法: powershell -ExecutionPolicy Bypass -File sync_kb_to_obsidian.ps1
$src = "D:\GameWorkSpace\TowerDefenseProto\kb"
$dst = "D:\AI_Knowledge\Projects\TowerDefenseProto"
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
$count = 0
Get-ChildItem $src -File -Filter *.md | ForEach-Object {
    Copy-Item $_.FullName -Destination $dst -Force
    $count++
}
Write-Host "[sync] kb -> Obsidian 镜像完成: $count 个文件"
Write-Host "[sync] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"