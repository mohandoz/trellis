$ErrorActionPreference = 'Continue'

$gitBash = $null
foreach ($c in @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe"
)) {
    if (Test-Path $c) { $gitBash = $c; break }
}

if ($null -ne $gitBash) {
    & $gitBash "$PSScriptRoot\cli\conjure" @args
    exit $LASTEXITCODE
}

if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $drive = $PSScriptRoot.Substring(0, 1).ToLower()
    $rest  = $PSScriptRoot.Substring(2) -replace '\\', '/'
    wsl -- bash "/mnt/$drive$rest/cli/conjure" @args
    exit $LASTEXITCODE
}

Write-Error "conjure.ps1: Git Bash or WSL required. Install Git for Windows or enable WSL."
exit 2
