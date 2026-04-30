param(
  [string]$BuildDir = "build",
  [string]$Generator = "",
  [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
  [string]$BuildType = "Release",
  [ValidateSet("auto", "on", "off")]
  [string]$MPI = "auto",
  [switch]$RunTests,
  [switch]$Clean
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "required command '$Name' was not found in PATH"
  }
}

function Invoke-Native([string]$Name, [string[]]$Arguments) {
  & $Name @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "'$Name' failed with exit code $LASTEXITCODE"
  }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildPath = Join-Path $RepoRoot $BuildDir

Require-Command "cmake"

$UseNinja = $false
if ([string]::IsNullOrWhiteSpace($Generator)) {
  if (Get-Command ninja -ErrorAction SilentlyContinue) {
    $Generator = "Ninja"
    $UseNinja = $true
  }
} elseif ($Generator -eq "Ninja") {
  $UseNinja = $true
}

if ($UseNinja) {
  Require-Command "ninja"
}

if ($Clean -and (Test-Path $BuildPath)) {
  Remove-Item -LiteralPath $BuildPath -Recurse -Force
}

$CMakeArgs = @("-S", $RepoRoot, "-B", $BuildPath)
if (-not [string]::IsNullOrWhiteSpace($Generator)) {
  $CMakeArgs += @("-G", $Generator)
}
if ($UseNinja -or (-not [string]::IsNullOrWhiteSpace($Generator) -and $Generator -notlike "Visual Studio*")) {
  $CMakeArgs += "-DCMAKE_BUILD_TYPE=$BuildType"
}
switch ($MPI) {
  "on" { $CMakeArgs += "-DSTRACK_ENABLE_MPI=ON" }
  "off" { $CMakeArgs += "-DSTRACK_ENABLE_MPI=OFF" }
}

Write-Host "Configuring strack in $BuildPath"
Invoke-Native "cmake" $CMakeArgs

$MultiConfig = $false
$CachePath = Join-Path $BuildPath "CMakeCache.txt"
if (Test-Path $CachePath) {
  $MultiConfig = (Get-Content $CachePath -Raw) -match "CMAKE_CONFIGURATION_TYPES"
}

$BuildArgs = @("--build", $BuildPath)
if ($MultiConfig) {
  $BuildArgs += @("--config", $BuildType)
}

Write-Host "Building strack"
Invoke-Native "cmake" $BuildArgs

if ($RunTests) {
  Write-Host "Running validation"
  $CTestArgs = @("--test-dir", $BuildPath, "--output-on-failure")
  if ($MultiConfig) {
    $CTestArgs += @("-C", $BuildType)
  }
  Invoke-Native "ctest" $CTestArgs
}

$ExampleCase = Join-Path $RepoRoot "validation\\homogeneous_cube_1g\\homogeneous_cube_1g.xml"
$ExecutablePath = if ($MultiConfig) {
  Join-Path $BuildPath (Join-Path $BuildType "strack.exe")
} else {
  Join-Path $BuildPath "strack.exe"
}
Write-Host ""
Write-Host "Build complete."
Write-Host "Example run:"
Write-Host "  $ExecutablePath $ExampleCase"
