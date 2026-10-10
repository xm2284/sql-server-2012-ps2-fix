# 一键安装脚本：SQL Server 2012 所需的 PowerShell 2.0 补丁
# 来源：微软官方临时缓解包 ps2DLC (KB5065506)
$ErrorActionPreference = 'Continue'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loadGAC = Join-Path (Join-Path $dir 'ps2DLC') 'loadGAC.ps1'

function OK($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function BAD($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red }
function INFO($m) { Write-Host "  [..] $m" -ForegroundColor Cyan }
function WARN($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }

Write-Host ""
Write-Host "========================================================" -ForegroundColor White
Write-Host "  SQL Server 2012 安装补丁  -  PowerShell 2.0 修复" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor White
Write-Host ""

# 1. 管理员权限检查
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    BAD "当前不是管理员权限"
    WARN "请右键点击脚本 -> 以管理员身份运行"
    Read-Host "`n按回车键退出"
    exit 1
}
OK "管理员权限已确认"

# 2. 检查补丁文件
if (-not (Test-Path -LiteralPath $loadGAC)) {
    BAD "找不到 ps2DLC\loadGAC.ps1"
    WARN "请确认已完整解压（不要只复制了部分文件）"
    Read-Host "`n按回车键退出"
    exit 1
}
OK "补丁文件已就位"

# 3. 检查 .NET Framework 3.5（PS2 运行时依赖）
INFO "正在检查 .NET Framework 3.5 ..."
$nf = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue
if ($nf -and $nf.Install -eq 1) {
    OK ".NET Framework 3.5 已安装 (版本 $($nf.Version))"
} else {
    WARN ".NET Framework 3.5 未安装 —— PowerShell 2.0 需要它才能运行"
    $ans = Read-Host "  是否现在自动启用 .NET 3.5? (y/n)"
    if ($ans -match '^[Yy]') {
        INFO "正在通过 DISM 启用 .NET 3.5（可能需要几分钟）..."
        $r = & dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart 2>&1
        $nf2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue
        if ($nf2 -and $nf2.Install -eq 1) {
            OK ".NET Framework 3.5 启用成功"
        } else {
            BAD ".NET 3.5 启用失败（可能需要联网或系统镜像）"
            WARN "请手动到 控制面板 -> 启用或关闭Windows功能 中勾选 .NET 3.5"
            WARN "启用后请重启电脑，再重新运行本脚本"
            Read-Host "`n按回车键退出"
            exit 1
        }
    } else {
        BAD "已取消。缺少 .NET 3.5 时补丁无法生效"
        Read-Host "`n按回车键退出"
        exit 1
    }
}

# 4. 运行 loadGAC.ps1
INFO "正在安装 PowerShell 2.0 程序集到 GAC 并写入注册表 ..."
$null = Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Push-Location -LiteralPath (Split-Path -Parent $loadGAC)
try {
    $out = & $loadGAC 2>&1
    foreach ($line in $out) {
        $t = "$line"
        if ($t -match 'succeeded') { OK "注册表导入成功" }
        elseif ($t -match 'failed') { BAD "注册表导入失败: $t" }
        elseif ($t -match 'must be run as Administrator') { BAD "权限不足" }
        else { Write-Host "       $t" }
    }
} catch {
    BAD "执行出错: $($_.Exception.Message)"
} finally {
    Pop-Location
}

# 5. 验证
Write-Host ""
INFO "正在验证安装结果 ..."
$regPath = 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine'
$ok = $true

if (Test-Path $regPath) {
    $v = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).PowerShellVersion
    if ($v -eq '2.0') { OK "注册表 PowerShellVersion = 2.0" }
    else { BAD "注册表 PowerShellVersion = '$v' (应为 2.0)"; $ok = $false }
} else {
    BAD "注册表键不存在: $regPath"; $ok = $false
}

$root = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\PowerShell\1' -ErrorAction SilentlyContinue
if ($root -and $root.Install -eq 1) { OK "注册表 Install = 1" }
else { BAD "注册表 Install 未设为 1"; $ok = $false }

$gac = 'C:\Windows\assembly\GAC_MSIL\System.Management.Automation'
if (Test-Path $gac) {
    $found = Get-ChildItem $gac -Directory | Where-Object { $_.Name -like '1.0.0.0*' }
    if ($found) { OK "GAC 中已注册 PS2 程序集 (1.0.0.0)" }
    else { WARN "GAC 中未发现 1.0.0.0 版本（可能不影响安装）" }
} else {
    WARN "GAC 路径不存在（可能不影响安装）"
}

Write-Host ""
if ($ok) {
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "  补丁安装成功！" -ForegroundColor Green
    Write-Host "  现在请重新运行 SQL Server 安装程序，" -ForegroundColor Green
    Write-Host "  PowerShell 2.0 错误将不再出现。" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
} else {
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host "  补丁未完全成功，请把上面的 [FAIL] 信息截图反馈" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
}
Write-Host ""
Read-Host "按回车键关闭窗口"
