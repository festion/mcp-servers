# scripts/GitAudit.ps1

# Determine paths
$outputDir = Join-Path $PSScriptRoot "..\output"
$mdPath = Join-Path $outputDir "GitRepoReport.md"
$htmlPath = Join-Path $outputDir "GitRepoReport.html"
$skippedPath = Join-Path $outputDir "SkippedReleases.txt"

# Detect local or CI environment
if ($env:GITHUB_ACTIONS -eq "true") {
    $repoRoot = Resolve-Path "$PSScriptRoot\.."
} else {
    $repoRoot = "C:\GIT"
}

Write-Host "Output directory: $outputDir"
Write-Host "Markdown path: $mdPath"
Write-Host "HTML path: $htmlPath"
Write-Host "Repo root: $repoRoot"

# Ensure output directory exists
if (-not (Test-Path $outputDir)) {
    Write-Host "Creating output directory..."
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Start Markdown report
try {
    $today = Get-Date -Format "yyyy-MM-dd"
    "## GitOps Repository Audit Summary - $today" | Out-File $mdPath -Encoding utf8
    Write-Host "Markdown header written"
} catch {
    Write-Error "Failed to write markdown header: $_"
    exit 1
}

# Loop over repositories
try {
    Get-ChildItem $repoRoot -Directory | Where-Object { $_.Name -ne "homelab-gitops-auditor" } | ForEach-Object {
        $repoName = $_.Name
        $repoPath = $_.FullName

        if (Test-Path "$repoPath\.git") {
            Add-Content $mdPath "`n### Repository: $repoName"
            Add-Content $mdPath "- Path: $repoPath"

            $lastCommit = git -C $repoPath log -1 --pretty=format:"%h %an %ad %s" 2>$null
            if (-not $lastCommit) { $lastCommit = "(no commits)" }
            Add-Content $mdPath "- Last Commit: $lastCommit"

            $branch = git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null
            if (-not $branch) { $branch = "(unknown branch)" }
            Add-Content $mdPath "- Branch: $branch"

            $status = git -C $repoPath status --porcelain
            if ($status) {
                Add-Content $mdPath "- Uncommitted changes:"
                $status | ForEach-Object { Add-Content $mdPath "  - $_" }
            } else {
                Add-Content $mdPath "- Clean working directory"
            }

            Add-Content $mdPath "`n---"
        }
    }
    Write-Host "Repository audit section completed"
} catch {
    Write-Error "Failed during repository audit: $_"
    exit 1
}

# Append skipped releases if present
if (Test-Path $skippedPath) {
    try {
        Add-Content $mdPath "`n## Skipped Releases"
        Get-Content $skippedPath | ForEach-Object { Add-Content $mdPath "- $_" }
        Write-Host "Appended skipped releases to markdown"
    } catch {
        Write-Warning "Failed to append skipped releases: $_"
    }
}

# Convert Markdown to HTML
try {
    $markdown = Get-Content $mdPath -Raw

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>GitOps Audit Report</title>
    <style>
        body { font-family: Consolas, monospace; background: #f9f9f9; padding: 1rem; }
        pre { background: #fff; padding: 1rem; border: 1px solid #ddd; border-radius: 8px; white-space: pre-wrap; }
    </style>
</head>
<body>
<h2>GitOps Repository Audit Report</h2>
<pre>
$markdown
</pre>
</body>
</html>
"@

    $htmlContent | Out-File $htmlPath -Encoding utf8
    Write-Host "HTML report generated at: $htmlPath"
} catch {
    Write-Error "Failed to generate HTML report: $_"
    exit 1
}
