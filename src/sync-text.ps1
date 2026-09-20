param(
    [ValidateSet('Check','Import','Export')][string]$Mode = 'Check',
    [string]$ReviewPath = "$PSScriptRoot/../docs/文案审阅稿.md",
    [string]$ModPath = "$PSScriptRoot/../outputs/cod fishing mod"
)
$ErrorActionPreference = 'Stop'
$zhPath = Join-Path $ModPath 'i18n/zh.json'
$enPath = Join-Path $ModPath 'i18n/default.json'
$zh = Get-Content -LiteralPath $zhPath -Raw | ConvertFrom-Json -AsHashtable
$en = Get-Content -LiteralPath $enPath -Raw | ConvertFrom-Json -AsHashtable
if (@(Compare-Object @($zh.Keys) @($en.Keys)).Count) { throw 'Chinese and English translation keys differ.' }
if ($Mode -ne 'Export') {
    $review = Get-Content -LiteralPath $ReviewPath -Raw
    $entries = [regex]::Matches($review, '(?ms)^### (?<key>[a-z][a-z0-9.-]+)\s*\r?\n(?:(?!^### ).)*?^中文：\s*\r?\n(?<zh>.*?)^English:\s*\r?\n(?<en>.*?)(?=^### |^## |\z)')
    $seen = @{}
    foreach ($entry in $entries) {
        $key = $entry.Groups['key'].Value
        if ($seen.ContainsKey($key) -or !$zh.ContainsKey($key)) { throw "Duplicate or unknown key: $key" }
        $seen[$key] = $true
        foreach ($locale in @('zh','en')) {
            $target = if ($locale -eq 'zh') { $zh } else { $en }
            $value = $entry.Groups[$locale].Value.Trim()
            if (!$value) { throw "Empty translation: $key ($locale)" }
            $oldTokens = @([regex]::Matches($target[$key], '\{\{[^}]+\}\}') | ForEach-Object Value | Sort-Object) -join '|'
            $newTokens = @([regex]::Matches($value, '\{\{[^}]+\}\}') | ForEach-Object Value | Sort-Object) -join '|'
            if ($oldTokens -cne $newTokens) { throw "Changed placeholders: $key ($locale)" }
            if ($Mode -eq 'Check' -and $target[$key] -cne $value) { throw "Review and language file differ: $key ($locale)" }
            if ($Mode -eq 'Import') { $target[$key] = $value }
        }
    }
    if ($seen.Count -ne $zh.Count) { throw 'Review is missing translation entries.' }
}
if ($Mode -eq 'Import') {
    $zh | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $zhPath -Encoding utf8
    $en | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $enPath -Encoding utf8
}
$manifest = Get-Content -LiteralPath (Join-Path $ModPath 'manifest.json') -Raw | ConvertFrom-Json
if ($Mode -eq 'Check' -and $review -notmatch ('版本：' + [regex]::Escape($manifest.Version) + '\s')) { throw 'Review version differs from manifest.' }
if ($Mode -eq 'Export') {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# cod fishing mod 文案审阅稿'); $lines.Add('')
    $lines.Add("版本：$($manifest.Version) · 作者：$($manifest.Author)"); $lines.Add('')
    $lines.Add('仅收录当前版本使用的文案。保留文本键、@（玩家姓名）、^（换行）、{{…}}（动态内容）、$h 和 #$b#（对话控制符）。修改后运行 sync-text.ps1 -Mode Import；此命令导入两种语言，不会自动翻译。'); $lines.Add('')
    foreach ($key in $zh.Keys) {
        foreach ($line in @("### $key", '', '中文：', '', $zh[$key], '', 'English:', '', $en[$key], '')) { $lines.Add($line) }
    }
    $lines.Add('## 模组列表信息'); $lines.Add('')
    $lines.Add("名称：$($manifest.Name)"); $lines.Add(''); $lines.Add("作者：$($manifest.Author)"); $lines.Add(''); $lines.Add("说明：$($manifest.Description)"); $lines.Add('')
    $lines.Add('## 安装说明'); $lines.Add(''); $lines.Add((Get-Content -LiteralPath (Join-Path $ModPath '安装说明.txt') -Raw).Trim())
    [IO.File]::WriteAllLines([IO.Path]::GetFullPath($ReviewPath), $lines, [Text.UTF8Encoding]::new($false))
}
Write-Output "$Mode passed: $($zh.Count) bilingual entries."
