#Requires -Version 5.1
<#
.SYNOPSIS
Regenerates image metadata, validates every post and its media, and (if
everything passes) commits and pushes to GitHub.

.DESCRIPTION
Runs the same checks as CI, repo-wide:
  1. Regenerates `_data/img-info.json` (gen-img-info.ps1).
  2. Validates every media manifest (test-media-manifests.ps1).
  3. Validates every post's front matter and media references (test-post.ps1).
  4. Builds the site (bundle exec jekyll build) and validates the generated
     HTML (test-site.ps1).

If all checks pass, stages all changes, commits, and pushes to the current
branch's remote. Any failed check stops the script before anything is
committed or pushed.

Does not regenerate AVIF/HLS derivatives by default (that requires
ImageMagick/ffmpeg and can be slow); pass -RegenerateDerivatives and/or
-RegenerateHls to opt in.

.EXAMPLE
.\publish.ps1

.EXAMPLE
.\publish.ps1 -Message "Add console-p2 photos" -Force

.EXAMPLE
.\publish.ps1 -NoCommit

.EXAMPLE
.\publish.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Message,
    [switch]$SkipMetadata,
    [switch]$RegenerateDerivatives,
    [switch]$RegenerateHls,
    [switch]$SkipBuild,
    [switch]$NoCommit,
    [switch]$NoPush,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step
{
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info
{
    param([string]$Message)
    Write-Host "[publish] $Message" -ForegroundColor Gray
}

function Write-Success
{
    param([string]$Message)
    Write-Host "[publish] $Message" -ForegroundColor Green
}

function Read-YesNo
{
    param(
        [string]$Prompt,
        [bool]$DefaultValue = $false
    )

    $suffix = "[y/N]"
    if ($DefaultValue)
    {
        $suffix = "[Y/n]"
    }

    $value = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($value))
    {
        return $DefaultValue
    }

    return $value.Trim().ToLowerInvariant().StartsWith("y")
}

function Invoke-Checked
{
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock
    )

    Write-Step $Description
    $global:LASTEXITCODE = 0
    & $ScriptBlock
    $succeeded = $?
    if (-not $succeeded -or $LASTEXITCODE -ne 0)
    {
        throw "$Description failed (exit code $LASTEXITCODE)."
    }
}

Push-Location $RepoRoot
try
{
    if (-not $SkipMetadata)
    {
        Invoke-Checked -Description "Regenerating image metadata (gen-img-info.ps1)" -ScriptBlock {
            ./gen-img-info.ps1 | Out-Host
        }
    }
    else
    {
        Write-Info "Skipping metadata regeneration (-SkipMetadata)."
    }

    if ($RegenerateDerivatives)
    {
        try
        {
            Invoke-Checked -Description "Regenerating AVIF derivatives (gen-derived-avif.ps1)" -ScriptBlock {
                ./gen-derived-avif.ps1 | Out-Host
            }
        }
        catch
        {
            Write-Info "Skipping AVIF derivative regeneration: $($_.Exception.Message)"
        }
    }

    if ($RegenerateHls)
    {
        try
        {
            Invoke-Checked -Description "Regenerating HLS video assets (gen-hls.ps1)" -ScriptBlock {
                ./gen-hls.ps1 | Out-Host
            }
        }
        catch
        {
            Write-Info "Skipping HLS regeneration: $($_.Exception.Message)"
        }
    }

    Invoke-Checked -Description "Validating media manifests (test-media-manifests.ps1)" -ScriptBlock {
        ./test-media-manifests.ps1
    }

    Write-Step "Validating every post (test-post.ps1)"
    $posts = @(Get-ChildItem -Path (Join-Path $RepoRoot "_posts") -Filter "*.MD" -File -Recurse | Sort-Object FullName)
    Write-Info "Found $($posts.Count) post(s)."
    $failedPosts = @()
    foreach ($post in $posts)
    {
        ./test-post.ps1 -PostPath $post.FullName | Out-Host
        if ($LASTEXITCODE -ne 0)
        {
            $failedPosts += $post.FullName
        }
    }
    if ($failedPosts.Count -gt 0)
    {
        $failedList = $failedPosts -join "`n  "
        throw "$($failedPosts.Count) post(s) failed validation:`n  $failedList"
    }
    Write-Success "All $($posts.Count) post(s) passed validation."

    if (-not $SkipBuild)
    {
        Invoke-Checked -Description "Building the site (bundle exec jekyll build --trace)" -ScriptBlock {
            bundle exec jekyll build --trace
        }

        Invoke-Checked -Description "Validating generated HTML (test-site.ps1)" -ScriptBlock {
            ./test-site.ps1
        }
    }
    else
    {
        Write-Info "Skipping Jekyll build and HTML validation (-SkipBuild)."
    }

    Write-Success "All checks passed."

    if ($NoCommit)
    {
        Write-Info "Validation-only run (-NoCommit). Nothing was committed or pushed."
        exit 0
    }

    Write-Step "Checking for changes to publish"
    $statusLines = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0)
    {
        throw "git status failed with exit code $LASTEXITCODE."
    }

    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($LASTEXITCODE -ne 0)
    {
        throw "Could not determine the current branch."
    }

    git fetch origin $branch 2>&1 | Out-Host
    $hasUpstream = $true
    $ahead = 0
    $aheadCountRaw = git rev-list --count "origin/$branch..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0)
    {
        $hasUpstream = $false
    }
    else
    {
        $ahead = [int]$aheadCountRaw
    }

    if ($statusLines.Count -eq 0 -and ($ahead -eq 0 -or -not $hasUpstream))
    {
        Write-Info "Nothing to commit and nothing to push. Repository is already up to date."
        exit 0
    }

    if ($statusLines.Count -gt 0)
    {
        Write-Info "Changes to publish:"
        $statusLines | ForEach-Object { Write-Host "  $_" }
    }
    else
    {
        Write-Info "No uncommitted changes, but the local branch is ahead of origin/$branch by $ahead commit(s)."
    }

    if (-not $Force -and -not $WhatIfPreference)
    {
        if (-not (Read-YesNo -Prompt "Commit and push these changes to origin/${branch}?" -DefaultValue $false))
        {
            Write-Info "Aborted by user. Nothing was committed or pushed."
            exit 0
        }
    }

    if ($statusLines.Count -gt 0)
    {
        if ([string]::IsNullOrWhiteSpace($Message))
        {
            if ($Force -or $WhatIfPreference)
            {
                $Message = "Publish site updates - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            }
            else
            {
                do
                {
                    $Message = Read-Host "Commit message"
                } while ([string]::IsNullOrWhiteSpace($Message))
            }
        }

        if ($PSCmdlet.ShouldProcess("working tree", "git add -A"))
        {
            git add -A
            if ($LASTEXITCODE -ne 0)
            {
                throw "git add failed with exit code $LASTEXITCODE."
            }
        }

        if ($PSCmdlet.ShouldProcess($RepoRoot, "git commit -m `"$Message`""))
        {
            git commit -m $Message
            if ($LASTEXITCODE -ne 0)
            {
                throw "git commit failed with exit code $LASTEXITCODE."
            }
        }
    }

    if ($NoPush)
    {
        Write-Info "Skipping push (-NoPush)."
        exit 0
    }

    if ($hasUpstream)
    {
        if ($PSCmdlet.ShouldProcess("origin/$branch", "git pull --rebase"))
        {
            git pull --rebase origin $branch
            if ($LASTEXITCODE -ne 0)
            {
                throw "git pull --rebase failed with exit code $LASTEXITCODE. Resolve the rebase manually (see 'git status'), then push."
            }
        }

        if ($PSCmdlet.ShouldProcess("origin/$branch", "git push"))
        {
            git push origin $branch
            if ($LASTEXITCODE -ne 0)
            {
                throw "git push failed with exit code $LASTEXITCODE."
            }
            Write-Success "Published to origin/$branch."
        }
    }
    else
    {
        if ($PSCmdlet.ShouldProcess("origin/$branch", "git push -u"))
        {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0)
            {
                throw "git push failed with exit code $LASTEXITCODE."
            }
            Write-Success "Published to origin/$branch."
        }
    }
}
finally
{
    Pop-Location
}
