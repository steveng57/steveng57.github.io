$ErrorActionPreference = 'Stop'

function Get-TitleAndDescription([string]$Path) {
  $raw = Get-Content -Raw -LiteralPath $Path

  $titleMatch = [regex]::Match($raw, '<title>(.*?)</title>', [Text.RegularExpressions.RegexOptions]::Singleline)
  $descMatch  = [regex]::Match($raw, '<meta\s+name="description"\s+content="(.*?)"\s*/?>', [Text.RegularExpressions.RegexOptions]::Singleline)
  $canonMatch = [regex]::Match($raw, '<link\s+rel="canonical"\s+href="(.*?)"\s*/?>', [Text.RegularExpressions.RegexOptions]::Singleline)

  [pscustomobject]@{
    Path        = $Path
    Canonical   = $canonMatch.Groups[1].Value.Trim()
    Title       = $titleMatch.Groups[1].Value.Trim()
    Description = $descMatch.Groups[1].Value.Trim()
  }
}

$targets = @()
$targets += Get-ChildItem -File -Recurse -Path .\_site\categories -Filter index.html -ErrorAction SilentlyContinue
$targets += Get-ChildItem -File -Recurse -Path .\_site\tags -Filter index.html -ErrorAction SilentlyContinue
$targets += Get-ChildItem -File -Recurse -Path .\_site\woodworking -Filter index.html -ErrorAction SilentlyContinue
$targets += Get-ChildItem -File -Recurse -Path .\_site\home-and-garden -Filter index.html -ErrorAction SilentlyContinue

$rows = $targets | ForEach-Object { Get-TitleAndDescription $_.FullName }

$siteDesc = 'A bunch of postings on woodworking and other things that interest me.'

$report = @()
$report += "Scanned: $($rows.Count) index pages"
$report += ''

$report += '== Missing description =='
$report += ($rows | Where-Object { [string]::IsNullOrWhiteSpace($_.Description) } | Select-Object Canonical, Title, Path | Format-Table -AutoSize | Out-String)
$report += ''

$report += '== Duplicate titles (count>1) =='
$report += ($rows | Group-Object Title | Where-Object Count -gt 1 | Sort-Object Count -Descending | Select-Object Count, Name | Format-Table -AutoSize | Out-String)
$report += ''

$report += '== Duplicate descriptions (count>1, non-empty) =='
$report += (
  $rows |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Description) } |
    Group-Object Description |
    Where-Object Count -gt 1 |
    Sort-Object Count -Descending |
    Select-Object Count, @{ n = 'Description'; e = { $_.Name.Substring(0, [Math]::Min(120, $_.Name.Length)) } } |
    Format-Table -AutoSize |
    Out-String
)
$report += ''

$report += '== Category pages using site-wide description (sample) =='
$report += (
  $rows |
    Where-Object { $_.Canonical -match '/categories/' -and $_.Description -eq $siteDesc } |
    Select-Object -First 20 Canonical, Title |
    Format-Table -AutoSize |
    Out-String
)

$reportPath = Join-Path $PWD 'seo-metadata-report.txt'
$report -join "`r`n" | Out-File -LiteralPath $reportPath -Encoding utf8
Write-Host "Wrote $reportPath" -ForegroundColor Green
