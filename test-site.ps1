[CmdletBinding()]
param(
    [string]$SiteDirectory = (Join-Path $PSScriptRoot "_site")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedSiteDirectory = Resolve-Path -LiteralPath $SiteDirectory -ErrorAction Stop
$htmlProoferSiteDirectory = $resolvedSiteDirectory.Path.Replace("\", "/")
$hadDebugEnvironmentVariable = Test-Path Env:DEBUG
$previousDebugValue = $env:DEBUG
$previousPath = $env:PATH
$hadRubyDllPath = Test-Path Env:RUBY_DLL_PATH
$previousRubyDllPath = $env:RUBY_DLL_PATH
$temporaryLibraryDirectory = $null
$exitCode = 1

try {
    # HTMLProofer treats any non-empty DEBUG value as a request to load its
    # optional Ruby debugger. The host uses DEBUG=release for an unrelated
    # purpose, so keep it out of this child process.
    Remove-Item Env:DEBUG -ErrorAction SilentlyContinue

    if ($env:OS -eq "Windows_NT") {
        $rubyCommand = Get-Command ruby -ErrorAction Stop
        $rubyRoot = Split-Path (Split-Path $rubyCommand.Source -Parent) -Parent
        $ucrtBin = Join-Path $rubyRoot "msys64\ucrt64\bin"
        $versionedLibcurl = Join-Path $ucrtBin "libcurl-4.dll"

        if (Test-Path -LiteralPath $versionedLibcurl) {
            # Ethon asks Windows for libcurl.dll, while RubyInstaller's MSYS2
            # package provides libcurl-4.dll. Supply a process-local alias and
            # keep its dependent UCRT DLLs available on PATH.
            $temporaryLibraryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "htmlproofer-libcurl-$PID"
            New-Item -ItemType Directory -Path $temporaryLibraryDirectory -ErrorAction Stop | Out-Null
            Copy-Item -LiteralPath $versionedLibcurl `
                -Destination (Join-Path $temporaryLibraryDirectory "libcurl.dll") `
                -ErrorAction Stop
            $env:PATH = "$temporaryLibraryDirectory;$ucrtBin;$previousPath"
            $env:RUBY_DLL_PATH = "$temporaryLibraryDirectory;$ucrtBin"
        }
    }

    Push-Location $PSScriptRoot
    try {
        & bundle exec htmlproofer $htmlProoferSiteDirectory `
            --disable-external `
            --checks html `
            --allow-hash-href
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:PATH = $previousPath
    if ($hadRubyDllPath) {
        $env:RUBY_DLL_PATH = $previousRubyDllPath
    }
    else {
        Remove-Item Env:RUBY_DLL_PATH -ErrorAction SilentlyContinue
    }

    if ($temporaryLibraryDirectory) {
        $temporaryLibcurl = Join-Path $temporaryLibraryDirectory "libcurl.dll"
        if (Test-Path -LiteralPath $temporaryLibcurl) {
            Remove-Item -LiteralPath $temporaryLibcurl -Force
        }
        if (Test-Path -LiteralPath $temporaryLibraryDirectory) {
            Remove-Item -LiteralPath $temporaryLibraryDirectory -Force
        }
    }

    if ($hadDebugEnvironmentVariable) {
        $env:DEBUG = $previousDebugValue
    }
    else {
        Remove-Item Env:DEBUG -ErrorAction SilentlyContinue
    }
}

if ($exitCode -ne 0) {
    Write-Error "HTMLProofer failed with exit code $exitCode."
}

Write-Host "HTMLProofer passed." -ForegroundColor Green
