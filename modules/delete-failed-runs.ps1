# PowerShell Script: Delete Failed GitHub Actions Runs

# Configuration
$owner = "festion"
$repo = "homelab-gitops-auditor"

Write-Host "Fetching workflow runs from $owner/$repo..."

# Fetch all runs using GitHub CLI and parse the result
$runs = gh api "repos/$owner/$repo/actions/runs" --paginate | ConvertFrom-Json

$deletedCount = 0
$skippedCount = 0

# Process each workflow run
foreach ($run in $runs.workflow_runs) {
    $runId = $run.id
    $status = $run.status
    $conclusion = $run.conclusion
    $createdAt = $run.created_at

    if ($status -eq "in_progress" -or $status -eq "queued") {
        Write-Host "Skipping run $runId ($status)..."
        $skippedCount++
        continue
    }

    if ($conclusion -eq "failure") {
        Write-Host "Deleting failed run $runId from $createdAt..."
        gh api -X DELETE "repos/$owner/$repo/actions/runs/$runId"
        $deletedCount++
    } else {
        Write-Host "Keeping run $runId (conclusion: $conclusion)"
        $skippedCount++
    }
}

Write-Host "`nCleanup complete. Deleted: $deletedCount | Skipped: $skippedCount"
