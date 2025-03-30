# gitaudit.ps1

$ReportDir = "scripts/output"
$MarkdownReportPath = Join-Path $ReportDir "GitRepoReport.md"
$HtmlReportPath     = Join-Path $ReportDir "GitRepoReport.html"
$Timestamp = Get-Date -Format "yyyy-MM-dd"

# Ensure output directory exists
if (-Not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

# Header for Markdown
$Header = @"
# GitOps Repository Audit Report

## GitOps Repository Audit Summary - $Timestamp
"@
$Header | Out-File -FilePath $MarkdownReportPath -Encoding utf8

# Define the root folder to scan
$Root = "repos"
if (-Not (Test-Path $Root)) {
    "⚠️ Directory '$Root' does not exist. No repositories to audit." | Out-File -Append $MarkdownReportPath
} else {
    $Repos = Get-ChildItem -Path $Root -Directory
    if ($Repos.Count -eq 0) {
        "⚠️ No repositories found under '$Root'." | Out-File -Append $MarkdownReportPath
    }

    foreach ($Repo in $Repos) {
        $Path = $Repo.FullName
        $Remote = ""
        $Branch = ""
        $HasChanges = $false
        $Missing = $false

        if (Test-Path (Join-Path $Path ".git")) {
            Push-Location $Path

            try {
                $Remote = git remote get-url origin 2>$null
                $Branch = git rev-parse --abbrev-ref HEAD 2>$null
                $HasChanges = -not [string]::IsNullOrWhiteSpace((git status --porcelain))
            } catch {
                $Missing = $true
            }

            Pop-Location

            $Status = @"
### Repository: $($Repo.Name)
- Path: $Path
- Remote: $Remote
- Branch: $Branch
- Has Uncommitted Changes: $HasChanges
- Git Data Missing/Invalid: $Missing
"@

            $Status | Out-File -Append $MarkdownReportPath -Encoding utf8
        } else {
            "⚠️ Skipping '$($Repo.Name)' — not a Git repository." | Out-File -Append $MarkdownReportPath
        }
    }
}

# Generate HTML report from the Markdown
$MarkdownContent = Get-Content $MarkdownReportPath -Raw
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>GitOps Audit Report</title>
    <style>
        body { font-family: monospace; background-color: #f9f9f9; padding: 20px; }
        pre { background: #fff; border: 1px solid #ccc; padding: 15px; }
    </style>
</head>
<body>
<h1>GitOps Repository Audit Report</h1>
<pre>
$MarkdownContent
</pre>
</body>
</html>
"@

$HtmlContent | Out-File -FilePath $HtmlReportPath -Encoding utf8

Write-Host "✅ Markdown report saved to: $MarkdownReportPath"
Write-Host "✅ HTML report saved to: $HtmlReportPath"
