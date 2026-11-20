# 网页快开 —— 把搜索框里输入的网址交给系统默认浏览器打开
# 契约：盒子把参数 JSON 的路径作为第一个位置参数传入，即 $args[0]

function Resolve-TargetUrl {
    param([string]$Text)

    $value = $Text.Trim().Trim('"').Trim("'").Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    if ($value -match '\s') { return $null }

    # 已带协议（https://、http://、ftp://、file://、mailto: 等）直接用
    if ($value -match '^[a-zA-Z][a-zA-Z0-9+.\-]*:') { return $value }

    # 本机地址补 http://
    if ($value -match '^(localhost|127\.0\.0\.1|(\d{1,3}\.){3}\d{1,3})(:\d+)?(/|$)' -or
        $value -match '^\[[0-9a-fA-F:]+\](:\d+)?(/|$)') {
        return "http://$value"
    }

    # 形如 example.com/path 的补 https://
    if ($value -match '^[^\s/]+\.[^\s/]+') { return "https://$value" }

    return $null
}

$url = ''

# 1. 读盒子的参数 JSON（搜索触发时提示词写进 data.url，恒为字符串数组）
$jsonPath = $args[0]
if ($jsonPath -and (Test-Path -LiteralPath $jsonPath)) {
    try {
        $payload = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($payload.data -and $payload.data.PSObject.Properties.Name -contains 'url') {
            $raw = @($payload.data.url)[0]
            if ($null -ne $raw) { $url = [string]$raw }
        }
    } catch {
        Write-Host "读取参数文件失败：$($_.Exception.Message)"
    }
}

# 2. 没有数据（例如直接点脚本卡片）时，让用户手输
if ([string]::IsNullOrWhiteSpace($url)) {
    $url = Read-Host '请输入要打开的网址'
}

$target = Resolve-TargetUrl -Text $url
if (-not $target) {
    Write-Host "不是可打开的网址：$url"
    exit 0
}

# 3. 交给默认浏览器（ShellExecute）
try {
    Start-Process -FilePath $target
    Write-Host "已用默认浏览器打开：$target"
} catch {
    try {
        Start-Process -FilePath 'rundll32.exe' -ArgumentList 'url.dll,FileProtocolHandler', $target
        Write-Host "已用默认浏览器打开：$target"
    } catch {
        Write-Host "打开失败：$($_.Exception.Message)"
    }
}

exit 0
