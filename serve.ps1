#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced Jekyll development server for steveng57.github.io

.DESCRIPTION
    This script provides a comprehensive development environment for the Jekyll site.
    It can optionally regenerate image assets before serving and provides various
    serving options for different development scenarios.

.PARAMETER RegenerateImages
    Regenerate thumbnails and image captions before serving

.PARAMETER NoDrafts
    Exclude drafts from the build

.PARAMETER NoFuture
    Exclude future-dated posts from the build

.PARAMETER NoLiveReload
    Disable live reload functionality

.PARAMETER Port
    Specify the port to serve on (default: 4000)

.PARAMETER HostAddress
    Specify the host to bind to (default: localhost)

.PARAMETER Clean
    Clean the _site directory before building

.PARAMETER Production
    Serve in production mode (disables drafts, future posts, and live reload)

.PARAMETER CheckOnly
    Only check if dependencies are available, don't serve

.EXAMPLE
    .\serve.ps1
    Serves the site with default options (drafts, future posts, live reload)

.EXAMPLE
    .\serve.ps1 -RegenerateImages
    Regenerates image assets then serves the site

.EXAMPLE
    .\serve.ps1 -Production
    Serves the site in production mode

.EXAMPLE
    .\serve.ps1 -Port 3000 -HostAddress 0.0.0.0
    Serves on port 3000, accessible from other machines
#>

[CmdletBinding()]
param(
    [switch]$RegenerateImages,
    [switch]$NoDrafts,
    [switch]$NoFuture,
    [switch]$NoLiveReload,
    [int]$Port = 4000,
    [string]$HostAddress = "localhost",
    [switch]$Clean,
    [switch]$Production,
    [switch]$CheckOnly
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "🔄 $Message" -ForegroundColor Magenta
}

# Check if required tools are available
function Test-Dependencies {
    Write-Step "Checking dependencies..."
    
    $dependencies = @{
        "bundle" = "Ruby Bundler"
        "jekyll" = "Jekyll"
    }
    
    $missing = @()
    
    foreach ($dep in $dependencies.GetEnumerator()) {
        try {
            $null = Get-Command $dep.Key -ErrorAction Stop
            Write-Success "$($dep.Value) is available"
        }
        catch {
            Write-Error "$($dep.Value) is not available"
            $missing += $dep.Value
        }
    }
    
    if ($RegenerateImages) {
        $imageTools = @{
            "ffmpeg" = "FFMPEG"
            "magick" = "ImageMagick"
        }
        
        foreach ($tool in $imageTools.GetEnumerator()) {
            try {
                $null = Get-Command $tool.Key -ErrorAction Stop
                Write-Success "$($tool.Value) is available"
            }
            catch {
                Write-Warning "$($tool.Value) is not available - image regeneration may fail"
            }
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missing -join ', ')"
        Write-Info "Please install the missing dependencies and try again."
        exit 1
    }
    
    # Check if Gemfile exists
    if (-not (Test-Path "Gemfile")) {
        Write-Error "Gemfile not found. Are you in the correct directory?"
        exit 1
    }
    
    Write-Success "All dependencies are available"
}

# Clean the _site directory
function Clear-SiteDirectory {
    if (Test-Path "_site") {
        Write-Step "Cleaning _site directory..."
        try {
            Remove-Item "_site" -Recurse -Force
            Write-Success "Cleaned _site directory"
        }
        catch {
            Write-Warning "Could not clean _site directory: $_"
        }
    }
}

# Regenerate image assets
function Update-ImageAssets {
    Write-Step "Regenerating image assets..."
    
    # Generate thumbnails
    if (Test-Path "gen-thumbnails.ps1") {
        Write-Info "Generating thumbnails..."
        try {
            & ".\gen-thumbnails.ps1"
            Write-Success "Thumbnails generated"
        }
        catch {
            Write-Warning "Thumbnail generation failed: $_"
        }
    } else {
        Write-Warning "gen-thumbnails.ps1 not found"
    }
    
    # Generate image captions
    if (Test-Path "gen-imagecaptions.ps1") {
        Write-Info "Generating image captions..."
        try {
            & ".\gen-imagecaptions.ps1"
            Write-Success "Image captions generated"
        }
        catch {
            Write-Warning "Image caption generation failed: $_"
        }
    } else {
        Write-Warning "gen-imagecaptions.ps1 not found"
    }
}

# Build the Jekyll command
function Build-JekyllCommand {
    $cmd = @("bundle", "exec", "jekyll", "serve")
    
    # Add port and host
    $cmd += "--port", $Port.ToString()
    $cmd += "--host", $HostAddress
    
    # Add conditional flags
    if (-not $NoLiveReload -and -not $Production) {
        $cmd += "--livereload"
    }
    
    if (-not $NoDrafts -and -not $Production) {
        $cmd += "--drafts"
    }
    
    if (-not $NoFuture -and -not $Production) {
        $cmd += "--future"
    }
    
    return $cmd
}

# Display startup information
function Show-StartupInfo {
    Write-Host ""
    Write-Host "🚀 Jekyll Development Server" -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
    Write-Info "Site URL: http://$HostAddress`:$Port"
    Write-Info "Mode: $(if ($Production) { 'Production' } else { 'Development' })"
    
    if (-not $Production) {
        Write-Info "Features enabled:"
        if (-not $NoDrafts) { Write-Host "  • Draft posts" -ForegroundColor Gray }
        if (-not $NoFuture) { Write-Host "  • Future posts" -ForegroundColor Gray }
        if (-not $NoLiveReload) { Write-Host "  • Live reload" -ForegroundColor Gray }
    }
    
    Write-Host ""
    Write-Info "Press Ctrl+C to stop the server"
    Write-Host ""
}

# Main execution
try {
    Write-Host "🌟 Jekyll Site Server - steveng57.github.io" -ForegroundColor Blue
    Write-Host "=============================================" -ForegroundColor Blue
    Write-Host ""
    
    # Check dependencies
    Test-Dependencies
    
    if ($CheckOnly) {
        Write-Success "Dependency check complete. Ready to serve!"
        exit 0
    }
    
    # Clean if requested
    if ($Clean) {
        Clear-SiteDirectory
    }
    
    # Regenerate images if requested
    if ($RegenerateImages) {
        Update-ImageAssets
    }
    
    # Build Jekyll command
    $jekyllCmd = Build-JekyllCommand
    
    # Show startup information
    Show-StartupInfo
    
    # Start Jekyll server
    Write-Step "Starting Jekyll server..."
    Write-Info "Command: $($jekyllCmd -join ' ')"
    Write-Host ""
    
    # Execute Jekyll
    & $jekyllCmd[0] $jekyllCmd[1..($jekyllCmd.Length-1)]
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
} finally {
    Write-Host ""
    Write-Info "Jekyll server stopped."
}