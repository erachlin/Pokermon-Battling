[CmdletBinding()]
param(
    [string]$ModsRoot = (Join-Path $env:APPDATA "Balatro\Mods"),
    [string]$PokermonSource = "",
    [switch]$Copy
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ElementalTarget = Join-Path $ModsRoot "ElementalEditions"
$PokermonTarget = Join-Path $ModsRoot "Pokermon"

function Remove-ExistingTarget {
    param([string]$PathToRemove)

    if (Test-Path -LiteralPath $PathToRemove) {
        Remove-Item -LiteralPath $PathToRemove -Recurse -Force
    }
}

function Install-Path {
    param(
        [string]$Source,
        [string]$Target
    )

    Remove-ExistingTarget -PathToRemove $Target

    if (-not $Copy) {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
            Write-Host "Linked $Target -> $Source"
            return
        }
        catch {
            Write-Warning "Symlink failed for $Target. Falling back to copy mode."
        }
    }

    Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
    Write-Host "Copied $Source -> $Target"
}

New-Item -ItemType Directory -Force -Path $ModsRoot | Out-Null
Install-Path -Source $RepoRoot -Target $ElementalTarget

if ($PokermonSource) {
    if (-not (Test-Path -LiteralPath $PokermonSource)) {
        throw "Pokermon source path does not exist: $PokermonSource"
    }
    Install-Path -Source $PokermonSource -Target $PokermonTarget
}
