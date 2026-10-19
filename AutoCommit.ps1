
# AutoCommit.ps1
# Create one Git commit per changed file, then push once.

$ErrorActionPreference = "Stop"

try {
    $root = git rev-parse --show-toplevel

    if ($LASTEXITCODE -ne 0 -or -not $root) {
        throw "Run this script inside a Git repository."
    }

    Set-Location $root.Trim()

    $branch = git branch --show-current

    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        throw "Could not determine the current branch."
    }

    $remote = git remote get-url origin 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $remote) {
        throw "GitHub remote 'origin' is not configured."
    }

    # Include tracked changes and untracked files.
    $status = @(git status --porcelain)

    if ($LASTEXITCODE -ne 0) {
        throw "Could not read Git status."
    }

    if ($status.Count -eq 0) {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        exit 0
    }

    # Collect unique changed paths.
    # Rename records are handled separately to avoid duplicate commits.
    $paths = @(
        git diff --name-only
        git diff --cached --name-only
        git ls-files --others --exclude-standard
    ) | Where-Object { $_ } | Sort-Object -Unique

    if ($LASTEXITCODE -ne 0) {
        throw "Could not list changed files."
    }

    foreach ($path in $paths) {
        Write-Host "`nProcessing: $path" -ForegroundColor Cyan

        # Stage only this file.
        git add -A -- "$path"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stage: $path"
        }

        # Skip if this file has no staged changes.
        git diff --cached --quiet -- "$path"

        if ($LASTEXITCODE -eq 0) {
            continue
        }

        # Generate a readable commit message from the file path.
        $fileName = Split-Path $path -Leaf
        $message = "Update $fileName"

        git commit -m $message -- "$path"

        if ($LASTEXITCODE -ne 0) {
            throw "Commit failed for: $path"
        }
    }

    # Push all newly created commits in one operation.
    git push -u origin $branch

    if ($LASTEXITCODE -ne 0) {
        throw "Push failed. Check git status and your remote."
    }

    Write-Host "`nAll file commits pushed successfully!" `
        -ForegroundColor Green
}
catch {
    Write-Host "`nError: $($_.Exception.Message)" `
        -ForegroundColor Red
    exit 1
}
