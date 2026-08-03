# ============================================================
# 信息图渲染脚本：html -> png（默认宽度 900，可配置，高度自适应）
# 用法（PowerShell）：
#   ./渲染图片.ps1 中间产物/03-流程.html            # 输出到 图片/03-流程.png
#   ./渲染图片.ps1 中间产物/*.html                   # 批量
#   ./渲染图片.ps1 中间产物/03-流程.html -Out 图片/x.png
# 说明：
#   - 视口宽须与 CSS 的 --sheet-width 一致，否则会裁切或产生多余留白。
#   - 输出 PNG 宽 = Width * Scale，高度贴合内容自动裁剪。
#   - 依赖 Chrome（无则回退 Edge）。不改源 html，渲染时临时注入透明背景。
# ============================================================
param(
  [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
  [string[]]$Inputs,
  [string]$Out,
  [int]$Width = 900,
  [int]$Scale = 2
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) { $chrome = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" }
if (-not (Test-Path $chrome)) { throw "找不到 Chrome / Edge" }

function Render-One($htmlPath, $outPath) {
  $htmlPath = (Resolve-Path $htmlPath).Path
  $srcDir = Split-Path $htmlPath -Parent
  $raw = Get-Content $htmlPath -Raw -Encoding UTF8

  # 临时副本：注入透明背景 + card 贴左上，便于精确裁剪
  $inject = "<style>html,body{background:transparent!important;margin:0!important;padding:0!important}.sheet,.card{margin:0!important}</style>"
  if ($raw -match '</head>') { $tmpHtml = $raw -replace '</head>', "$inject</head>" }
  else { $tmpHtml = $inject + $raw }
  $tmpPath = Join-Path $srcDir ("_render_tmp_{0}.html" -f (Split-Path $htmlPath -Leaf))
  [System.IO.File]::WriteAllText($tmpPath, $tmpHtml, (New-Object System.Text.UTF8Encoding $false))

  $tmpPng = [System.IO.Path]::GetTempFileName() + ".png"
  $userDir = Join-Path $env:TEMP ("poi_render_" + [System.IO.Path]::GetRandomFileName())
  $args = @(
    "--headless=new","--disable-gpu","--hide-scrollbars",
    "--force-device-scale-factor=$Scale",
    "--default-background-color=00000000",
    "--window-size=$Width,8000",
    "--user-data-dir=$userDir",
    "--screenshot=$tmpPng",
    ("file:///" + ($tmpPath -replace '\\','/'))
  )
  # Chrome 有时把 "...bytes written to file" 写到 stderr，配合 ErrorActionPreference=Stop 会误判为致命错误。
  # 这里单独把该调用降级为“不因原生命令 stderr 而中断”，保证后续裁剪/保存一定执行。
  $eapBak = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $chrome @args 2>$null | Out-Null
  $ErrorActionPreference = $eapBak

  if (-not (Test-Path $tmpPng)) { Remove-Item $tmpPath -Force; throw "渲染失败：$htmlPath" }

  # 裁剪：从底部往上找第一行非透明像素
  $bmp = [System.Drawing.Bitmap]::FromFile($tmpPng)
  try {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)

    $bottom = 0
    for ($y = $h - 1; $y -ge 0; $y--) {
      $rowStart = $y * $stride
      $found = $false
      for ($x = 0; $x -lt $w; $x++) {
        # BGRA，alpha 在 +3
        if ($bytes[$rowStart + $x*4 + 3] -ne 0) { $found = $true; break }
      }
      if ($found) { $bottom = $y + 1; break }
    }
    if ($bottom -le 0) { $bottom = $h }
    $pad = [int]($Scale * 0) # card 自带 padding，无需额外留白
    $cropH = [Math]::Min($h, $bottom + $pad)

    $cropRect = New-Object System.Drawing.Rectangle(0,0,$w,$cropH)
    $cropped = $bmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $outFull = [System.IO.Path]::GetFullPath($outPath)
    $outDir = Split-Path $outFull -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
    $cropped.Save($outFull, [System.Drawing.Imaging.ImageFormat]::Png)
    $cropped.Dispose()
    Write-Host ("OK  {0}  ->  {1}  ({2}x{3})" -f (Split-Path $htmlPath -Leaf), (Split-Path $outFull -Leaf), $w, $cropH)
  }
  finally {
    $bmp.Dispose()
    Remove-Item $tmpPath, $tmpPng -Force -ErrorAction SilentlyContinue
    Remove-Item $userDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

foreach ($pattern in $Inputs) {
  $files = Get-ChildItem $pattern -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.html' -and $_.Name -notlike '_render_tmp_*' }
  if (-not $files) { Write-Warning "无匹配 html：$pattern"; continue }
  foreach ($f in $files) {
    if ($Out -and $files.Count -eq 1) { $target = $Out }
    else {
      # 默认：同级 ../图片/<同名>.png
      $imgDir = Join-Path (Split-Path $f.DirectoryName -Parent) "图片"
      $target = Join-Path $imgDir ($f.BaseName + ".png")
    }
    Render-One $f.FullName $target
  }
}
