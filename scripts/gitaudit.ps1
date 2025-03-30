Write-Host "🛠️ Running GitOps audit script..."

$ReportDir = "output"
$MarkdownReportPath = Join-Path $ReportDir "GitRepoReport.md"
$HtmlReportPath     = Join-Path $ReportDir "GitRepoReport.html"
$OutputFlagPath     = "output/skipEmail.flag"
$Timestamp = Get-Date -Format "yyyy-MM-dd"

# Detect GitHub Actions mode
$mode = $env:GITHUB_EVENT_INPUTS_MODE
if (-not $mode) { $mode = "default" }

Write-Host "Run mode: $mode"

# Ensure fresh repos folder
if (Test-Path "repos") {
    Write-Host "🧹 Removing stale repos/"
    Remove-Item -Recurse -Force "repos"
}

# Ensure output directory exists
if (-Not (Test-Path $ReportDir)) {
    Write-Host "📁 Creating output directory: $ReportDir"
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

# Clone targets
if ($mode -eq "default") {
    $targets = @(
        "https://github.com/festion/homelab-gitops-auditor.git",
        "https://github.com/esphome/esphome.git"
    )

    foreach ($repoUrl in $targets) {
        $name = ($repoUrl -split '/')[-1] -replace '\.git$', ''
        $path = "repos/$name"
        Write-Host "📥 Cloning $repoUrl into $path"
        git clone --depth 1 $repoUrl $path | Out-Null
    }
}

# Test repo injection
if ($mode -eq "test") {
    $testRepo = "repos/testrepo/.git"
    if (-not (Test-Path $testRepo)) {
        Write-Host "🧪 Injecting test repo: $testRepo"
        New-Item -ItemType Directory -Path $testRepo -Force | Out-Null
    }
}

# Tags
$tags = @{
    "homelab-gitops-auditor" = "infra"
    "esphome" = "firmware"
    "testrepo" = "test"
}

# Summary counters
[int]$total = 0
[int]$changes = 0
[int]$missing = 0

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
    body {
      font-family: Arial, sans-serif;
      background-color: #f7f7f7;
      padding: 20px;
      color: #111;
    }
    h1, h2 { color: #333; }
    details {
      margin-bottom: 15px;
      border: 1px solid #ccc;
      background: #fff;
      padding: 10px;
      border-radius: 5px;
    }
    summary {
      font-weight: bold;
      font-size: 16px;
      cursor: pointer;
    }
    .ok { color: green; }
    .warn { color: orange; }
    .error { color: red; }
    pre {
      background: #eee;
      padding: 10px;
      overflow-x: auto;
    }
    @media (prefers-color-scheme: dark) {
      body { background-color: #1e1e1e; color: #ddd; }
      details { background-color: #2a2a2a; border-color: #555; }
      pre { background-color: #444; }
    }
  </style>
</head>
<body>
<h1>GitOps Repository Audit Report</h1>
<p><strong>Generated:</strong> $Timestamp</p>
"@

# Root folder
$Root = "repos"
if (-Not (Test-Path $Root)) {
    $msg = "⚠️ Directory '$Root' does not exist. No repositories to audit."
    Write-Host $msg
    $msg | Out-File -Append $MarkdownReportPath
    $HtmlBody += "<p class='warn'>$msg</p>`n"
    "$true" | Out-File $OutputFlagPath
} else {
    $Repos = Get-ChildItem -Path $Root -Directory
    if ($Repos.Count -eq 0) {
        $msg = "⚠️ No repositories found under '$Root'."
        Write-Host $msg
        $msg | Out-File -Append $MarkdownReportPath
        $HtmlBody += "<p class='warn'>$msg</p>`n"
        "$true" | Out-File $OutputFlagPath
    }

    foreach ($Repo in $Repos) {
        $total++
        $Path = $Repo.FullName
        $Name = $Repo.Name
        $Tag = $tags[$Name]
        $Remote = ""
        $Branch = ""
        $HasChanges = $false
        $IsMissing = $false
        $Diff = ""

        if (Test-Path (Join-Path $Path ".git")) {
            Push-Location $Path

            try {
                $Remote = git remote get-url origin 2>$null
                $Branch = git rev-parse --abbrev-ref HEAD 2>$null
                $HasChanges = -not [string]::IsNullOrWhiteSpace((git status --porcelain))
                if ($HasChanges) {
                    $Diff = git diff --shortstat 2>$null
                    $changes++
                }
            } catch {
                $IsMissing = $true
                $missing++
            }

            Pop-Location

            # Markdown output
            $Status = @"
### Repository: $Name
- Path: $Path
- Remote: $Remote
- Branch: $Branch
- Has Uncommitted Changes: $HasChanges
- Git Data Missing/Invalid: $IsMissing
"@
            $Status | Out-File -Append $MarkdownReportPath -Encoding utf8

            # HTML output
            $StatusClass = if ($IsMissing) { "error" } elseif ($HasChanges) { "warn" } else { "ok" }
            $TagText = if ($Tag) { "[$Tag] " } else { "" }
            $HtmlBody += @"
<details>
<summary><span class='$StatusClass'>Repo: $TagText$Name</span></summary>
<ul>
  <li><strong>Path:</strong> $Path</li>
  <li><strong>Remote:</strong> $Remote</li>
  <li><strong>Branch:</strong> $Branch</li>
  <li><strong>Has Uncommitted Changes:</strong> <span class='$StatusClass'>$HasChanges</span></li>
  <li><strong>Git Data Missing:</strong> <span class='$StatusClass'>$IsMissing</span></li>
</ul>
"@

            if ($HasChanges -and $Diff) {
                $HtmlBody += "<details><summary>Inline Diff Summary</summary><pre>$Diff</pre></details>`n"
            }

            $HtmlBody += "</details>`n"
        } else {
            $msg = "⚠️ Skipping '$Name' — not a Git repository."
            Write-Host $msg
            $msg | Out-File -Append $MarkdownReportPath
            $HtmlBody += "<p class='warn'>$msg</p>`n"
        }
    }
}

# Summary section
$HtmlBody = $HtmlBody.Insert(
    $HtmlBody.IndexOf("</p>") + 4,
@"
<h2>Audit Summary</h2>
<ul>
  <li><strong>Repositories audited:</strong> $total</li>
  <li><strong>With uncommitted changes:</strong> $changes</li>
  <li><strong>With Git issues:</strong> $missing</li>
</ul>
"@)

$HtmlBody += "</body></html>"

# Write HTML
$HtmlBody | Out-File -FilePath $HtmlReportPath -Encoding utf8

# Report status
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
