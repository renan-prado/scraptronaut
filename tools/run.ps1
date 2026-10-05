<#
.SYNOPSIS
    Runs Scraptronaut from the command line, without opening the Godot editor.

.DESCRIPTION
    Three modes:
      (default)    opens the game in a window, like the editor Play button
      -Headless    loads the project with no window and exits; smoke test
      -Screenshot  runs the scene, saves a PNG of the viewport and exits

.PARAMETER Scene
    Scene to run (e.g. res://cenas/estacao.tscn). Defaults to the project main scene.

.PARAMETER Headless
    Smoke test with no window. Exits 1 if the output contains a script or scene error.

.PARAMETER Screenshot
    Saves a PNG of the viewport. Needs a window, so it cannot be combined with -Headless.

.PARAMETER Fullscreen
    Opens the game window in fullscreen. Play mode only: -Headless has no window and
    -Screenshot captures the viewport, not the window.

.PARAMETER Output
    PNG path. Defaults to screenshots/shot-<timestamp>.png

.PARAMETER Frames
    Frames to run before quitting. Defaults to 60 for -Headless, 30 for -Screenshot.

.PARAMETER Script
    Runs a tool script with `--headless --script` and exits with its code. Used by
    the generators and the test scripts in tools/, which are not scenes and so have
    no place in the other three modes.

.PARAMETER Zoom
    Screenshot only: overrides the camera zoom. Below 1 pulls back; 0.15 fits the
    whole station. Zero keeps whatever zoom the scene set.

.PARAMETER Godot
    Executable path. Overrides $env:GODOT_BIN and the automatic lookup.

.EXAMPLE
    ./tools/run.ps1
.EXAMPLE
    ./tools/run.ps1 -Headless
.EXAMPLE
    ./tools/run.ps1 -Screenshot -Output screenshots/station.png
.EXAMPLE
    ./tools/run.ps1 -Scene res://cenas/estacao.tscn
.EXAMPLE
    ./tools/run.ps1 -Fullscreen
#>
[CmdletBinding()]
param(
    [string]$Scene = "",
    [switch]$Headless,
    [switch]$Screenshot,
    [switch]$Fullscreen,
    [string]$Output = "",
    [int]$Frames = 0,
    [string]$Script = "",
    [double]$Zoom = 0,
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"

$Project = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    param([string]$Explicit)

    $candidates = @()
    if ($Explicit) { $candidates += $Explicit }
    if ($env:GODOT_BIN) { $candidates += $env:GODOT_BIN }
    $candidates += "C:/tools/godot/godot_console.exe"
    $candidates += "C:/tools/godot/godot.exe"

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
    }

    foreach ($name in @("godot_console", "godot")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    throw 'Godot not found. Install it under C:/tools/godot/, set $env:GODOT_BIN, or pass -Godot <path>.'
}

function Sync-Imports {
    # Running with --path does NOT reimport changed assets: only the editor
    # rescans. So after a generator in tools/ rewrites a PNG, the engine keeps
    # drawing the previous import. That is not a subtle failure -- a sheet whose
    # frame count changed renders sliced at the old width, showing pieces of two
    # frames at once.
    #
    # Staleness is decided by the md5 Godot itself records next to each imported
    # file, not by timestamps: --import leaves the .ctex untouched when the
    # content did not actually change, so a file whose mtime moved would look
    # stale forever and reimport on every single run.
    param([string]$Project, [string]$Exe)

    $sources = @("assets", "recursos") |
        ForEach-Object { Join-Path $Project $_ } |
        Where-Object { Test-Path $_ }
    if (-not $sources) { return }

    $stale = $null

    # A file that was never imported has no .import companion at all, so the
    # md5 loop below would never look at it. preload() on it fails outright
    # ("no resource loaders"), which is how a brand new sheet breaks the build.
    $importable = @(".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".wav", ".mp3", ".ttf", ".otf")
    $missing = Get-ChildItem -Path $sources -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $importable -contains $_.Extension.ToLower() } |
        Where-Object { -not (Test-Path -LiteralPath ($_.FullName + ".import")) } |
        Select-Object -First 1
    if ($missing) { $stale = $missing.Name }

    foreach ($meta in Get-ChildItem -Path $sources -Recurse -File -Filter "*.import" -ErrorAction SilentlyContinue) {
        if ($stale) { break }
        $source = $meta.FullName.Substring(0, $meta.FullName.Length - ".import".Length)
        if (-not (Test-Path -LiteralPath $source)) { continue }

        $dest = (Get-Content -LiteralPath $meta.FullName) |
            Where-Object { $_ -match '^dest_files=' } |
            ForEach-Object { if ($_ -match 'res://([^"]+)') { $Matches[1] } } |
            Select-Object -First 1
        if (-not $dest) { continue }

        $record = Join-Path $Project ([System.IO.Path]::ChangeExtension($dest, ".md5"))
        if (-not (Test-Path -LiteralPath $record)) { $stale = $meta.Name; break }

        $recorded = (Get-Content -LiteralPath $record) |
            Where-Object { $_ -match '^source_md5="' } |
            ForEach-Object { ($_ -split '"')[1] } |
            Select-Object -First 1
        $actual = (Get-FileHash -LiteralPath $source -Algorithm MD5).Hash.ToLower()
        if ($recorded -ne $actual) { $stale = (Split-Path $source -Leaf); break }
    }

    if ($stale) {
        Write-Host "Reimporting assets ($stale is new or changed since the last import)" -ForegroundColor DarkYellow
        $previous = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $Exe --path $Project --headless --import 2>&1 | Out-Null
        $ErrorActionPreference = $previous
    }
}

if ($Headless -and $Screenshot) {
    throw "-Headless and -Screenshot do not mix: with no window the renderer is a dummy and the PNG comes out blank."
}

if ($Fullscreen -and ($Headless -or $Screenshot)) {
    throw "-Fullscreen only applies to play mode: -Headless has no window, and -Screenshot captures the viewport instead."
}

if ($Scene -and -not $Scene.EndsWith(".tscn")) {
    throw ("-Scene must point at a .tscn (got: " + $Scene + "). " +
           "Note: npm run swallows flags like -Frames and leaves the bare value, which lands here. " +
           "To pass flags, call the script directly: ./tools/run.ps1 -Frames 30")
}

$exe = Resolve-Godot -Explicit $Godot
Sync-Imports -Project $Project -Exe $exe

# ----------------------------------------------------------------- script ---
if ($Script) {
    Write-Host "Running $Script" -ForegroundColor Cyan

    # Same PS 5.1 stderr trap as the headless mode below: a generator that
    # prints a warning would otherwise terminate before reporting anything.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $exe --path $Project --headless --script $Script
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous

    exit $code
}

# ------------------------------------------------------------- screenshot ---
if ($Screenshot) {
    if ($Frames -le 0) { $Frames = 30 }
    if (-not $Scene) { $Scene = "res://cenas/estacao.tscn" }
    if (-not $Output) {
        $Output = Join-Path $Project ("screenshots/shot-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".png")
    } elseif (-not [System.IO.Path]::IsPathRooted($Output)) {
        $Output = Join-Path $Project $Output
    }
    $Output = $Output.Replace([char]92, [char]47)

    Write-Host "Capturing $Scene -> $Output ($Frames frames)" -ForegroundColor Cyan
    & $exe --path $Project -s "tools/capture.gd" -- $Scene $Output $Frames $Zoom
    exit $LASTEXITCODE
}

# --------------------------------------------------------------- headless ---
if ($Headless) {
    if ($Frames -le 0) { $Frames = 60 }

    $arguments = @("--path", $Project, "--headless", "--quit-after", $Frames)
    if ($Scene) { $arguments += $Scene }

    Write-Host "Headless smoke test ($Frames frames)" -ForegroundColor Cyan

    # PS 5.1 wraps native stderr in ErrorRecord; under "Stop" that turns into a
    # terminating error before we can report anything. Relax it just for the call.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $outputText = & $exe @arguments 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previous

    $outputText | ForEach-Object { Write-Host $_ }

    $problems = $outputText | Where-Object { $_ -match "SCRIPT ERROR|^ERROR:|Failed to load|Cannot open file" }
    if ($problems) {
        Write-Host ""
        Write-Host "FAILED: $($problems.Count) error(s) in the output." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "OK: project loaded with no errors." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------------------- play ---
$arguments = @("--path", $Project)
if ($Fullscreen) { $arguments += "--fullscreen" }
if ($Frames -gt 0) { $arguments += @("--quit-after", $Frames) }
if ($Scene) { $arguments += $Scene }

if ($Fullscreen) {
    Write-Host "Running the game in fullscreen. Press Alt+F4 or Ctrl+C to quit." -ForegroundColor Cyan
} else {
    Write-Host "Running the game. Close the window or press Ctrl+C to quit." -ForegroundColor Cyan
}
& $exe @arguments
exit $LASTEXITCODE
