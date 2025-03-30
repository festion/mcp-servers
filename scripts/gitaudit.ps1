# gitaudit.ps1

Write-Host "🛠️ Running GitOps audit script..."

$ReportDir = "output"
$MarkdownReportPath = Join-Path $ReportDir "GitRepoReport.md"
$HtmlReportPath     = Join-Path $ReportDir "GitRepoReport.html"
$Timestamp = Get-Date -Format "yyyy-MM-dd"

# Ensure output directory exists
if (-Not (Test-Path $ReportDir)) {
    Write-Host "📁 Creating output directory: $ReportDir"
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

# Detect mode
$mode = $env:GITHUB_EVENT_INPUTS_MODE
if (-not $mode) { $mode = "default" }

Write-Host "Run mode: $mode"

# Only inject test repo in test mode
if ($mode -eq "test") {
    $testRepo = "repos/testrepo/.git"
    if (-not (Test-Path $testRepo)) {
        Write-Host "🧪 Injecting test repo: $testRepo"
        New-Item -ItemType Directory -Path $testRepo -Force | Out-Null
    }
}


# Markdown header
$Header = @"
# GitOps Repository Audit Report

## GitOps Repository Audit Summary - $Timestamp
"@
$Header | Out-File -FilePath $MarkdownReportPath -Encoding utf8

# HTML setup
$HtmlBody = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>GitOps Audit Report</title>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f7f7f7; padding: 20px; }
    h1 { color: #333; }
    details { margin-bottom: 15px; border: 1px solid #ccc; background: #fff; padding: 10px; border-radius: 5px; }
    summary { font-weight: bold; font-size: 16px; cursor: pointer; }
    .ok { color: green; }
    .warn { color: orange; }
    .error { color: red; }
    pre { background: #eee; padding: 10px; overflow-x: auto; }
  </style>
</head>
<body>
<h1>GitOps Repository Audit Report</h1>
<p><strong>Generated:</strong> $Timestamp</p>
"@

# Define root folder
$Root = "repos"
if (-Not (Test-Path $Root)) {
    $msg = "⚠️ Directory '$Root' does not exist. No repositories to audit."
    Write-Host $msg
    $msg | Out-File -Append $MarkdownReportPath
    $HtmlBody += "<p class='warn'>$msg</p>`n"
} else {
    $Repos = Get-ChildItem -Path $Root -Directory
    if ($Repos.Count -eq 0) {
        $msg = "⚠️ No repositories found under '$Root'."
        Write-Host $msg
        $msg | Out-File -Append $MarkdownReportPath
        $HtmlBody += "<p class='warn'>$msg</p>`n"
    }

    foreach ($Repo in $Repos) {
        $Path = $Repo.FullName
        $Remote = ""
        $Branch = ""
        $HasChanges = $false
        $Missing = $false
        $Diff = ""

        if (Test-Path (Join-Path $Path ".git")) {
            Push-Location $Path

            try {
                $Remote = git remote get-url origin 2>$null
                $Branch = git rev-parse --abbrev-ref HEAD 2>$null
                $HasChanges = -not [string]::IsNullOrWhiteSpace((git status --porcelain))
                if ($HasChanges) {
                    $Diff = git diff --shortstat 2>$null
                }
            } catch {
                $Missing = $true
            }

            Pop-Location

            # Markdown Output
            $Status = @"
### Repository: $($Repo.Name)
- Path: $Path
- Remote: $Remote
- Branch: $Branch
- Has Uncommitted Changes: $HasChanges
- Git Data Missing/Invalid: $Missing

"@
            $Status | Out-File -Append $MarkdownReportPath -Encoding utf8

            # HTML Output
            $StatusClass = if ($Missing) { "error" } elseif ($HasChanges) { "warn" } else { "ok" }
            $HtmlBody += @"
<details>
<summary><span class='$StatusClass'>Repo: $($Repo.Name)</span></summary>
<ul>
  <li><strong>Path:</strong> $Path</li>
  <li><strong>Remote:</strong> $Remote</li>
  <li><strong>Branch:</strong> $Branch</li>
  <li><strong>Has Uncommitted Changes:</strong> <span class='$StatusClass'>$HasChanges</span></li>
  <li><strong>Git Data Missing:</strong> <span class='$StatusClass'>$Missing</span></li>
</ul>
"@

            if ($HasChanges -and $Diff) {
                $HtmlBody += "<details><summary>Inline Diff Summary</summary><pre>$Diff</pre></details>`n"
            }

            $HtmlBody += "</details>`n"
        } else {
            $msg = "⚠️ Skipping '$($Repo.Name)' — not a Git repository."
            Write-Host $msg
            $msg | Out-File -Append $MarkdownReportPath
            $HtmlBody += "<p class='warn'>$msg</p>`n"
        }
    }
}

$HtmlBody += "</body></html>"

# Write HTML output
$HtmlBody | Out-File -FilePath $HtmlReportPath -Encoding utf8

# Confirm output files exist
if (Test-Path $MarkdownReportPath) {
    Write-Host "✅ Markdown report saved to: $MarkdownReportPath"
} else {
    Write-Host "❌ Markdown report was NOT created."
}

if (Test-Path $HtmlReportPath) {
    Write-Host "✅ HTML report saved to: $HtmlReportPath"
} else {
    Write-Host "❌ HTML report was NOT created."
}
