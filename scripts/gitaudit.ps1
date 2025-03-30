# gitaudit.ps1
$ReportPath = "scripts/output/GitRepoReport.md"
$Timestamp = Get-Date -Format "yyyy-MM-dd"
$Header = @"
# GitOps Repository Audit Report

## GitOps Repository Audit Summary - $Timestamp
"@

$Header | Out-File -FilePath $ReportPath -Encoding utf8

# Define the root folder to scan
$Root = "repos"
if (-Not (Test-Path $Root)) {
    "Directory '$Root' does not exist. Skipping audit." | Out-File -Append $ReportPath
    exit
}

$Repos = Get-ChildItem -Path $Root -Directory
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
- Remote: $Remote
- Branch: $Branch
- Has Uncommitted Changes: $HasChanges
- Git Data Missing/Invalid: $Missing
"@

        $Status | Out-File -Append $ReportPath -Encoding utf8
    }
}
