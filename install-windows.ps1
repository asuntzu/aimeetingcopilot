# AI Meeting Copilot - Windows installer (Windows 10/11, x64 or ARM64)   [BETA]
# Run from the repository folder in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Dir = (Get-Location).Path
function Step($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") }
function Write-Json($path, $obj) { [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false)) }
function Need($cmd, $id) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Host "Installing $id ..."
    winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    Refresh-Path
  }
}

Step "1/7  Checking requirements"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "winget (App Installer) is required. Install 'App Installer' from the Microsoft Store, then run this again."; exit 1
}

Step "2/7  Installing tools (Node.js, uv, ripgrep)"
Need node "OpenJS.NodeJS.LTS"
Need uv "astral-sh.uv"
Need rg "BurntSushi.ripgrep.MSVC"

Step "3/7  Setting up Python packages"
uv venv --quiet --allow-existing --python 3.12 .venv
uv pip install --quiet --python .venv\Scripts\python.exe -r requirements.txt

Step "4/7  Downloading whisper.cpp and speech models (about 230 MB, one time)"
New-Item -ItemType Directory -Force -Path models, bin | Out-Null
$ProgressPreference = "SilentlyContinue"
# Download a file and refuse it unless its SHA-256 matches the known-good value.
function Fetch($url, $out, $sha) {
  if ((Test-Path $out) -and ((Get-FileHash $out -Algorithm SHA256).Hash -eq $sha.ToUpper())) { return }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest $url -OutFile "$out.part" -UseBasicParsing
  if ((Get-FileHash "$out.part" -Algorithm SHA256).Hash -ne $sha.ToUpper()) {
    Remove-Item "$out.part"; Write-Host "SECURITY: $out failed its integrity check and was deleted. Try again later."; exit 1
  }
  Move-Item -Force "$out.part" $out
}
$arm = $env:PROCESSOR_ARCHITECTURE -eq "ARM64"
$cli = Get-ChildItem -Path bin\whisper -Recurse -Filter whisper-cli.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cli) {
  if ($arm) { Fetch "https://github.com/ggml-org/whisper.cpp/releases/download/b5130/whisper-bin-win-cpu-arm64.zip" bin\whisper.zip "799543b926ab5b6c2d60cab269a2092e0ae8d27820e9e15429e59de3699546fc" }
  else { Fetch "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.2/whisper-bin-x64.zip" bin\whisper.zip "49dcc16de826f20bd53d44f947a1ae49dfa81f86cad67a64d80820cb192d674a" }
  Expand-Archive bin\whisper.zip -DestinationPath bin\whisper -Force
  Remove-Item bin\whisper.zip
  $cli = Get-ChildItem -Path bin\whisper -Recurse -Filter whisper-cli.exe | Select-Object -First 1
}
if (-not $cli) { Write-Host "Couldn't find whisper-cli.exe in the whisper.cpp download."; exit 1 }
Fetch "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin" models\ggml-small.en-q5_1.bin "bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30"
Fetch "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34.onnx" models\wespeaker_en_voxceleb_resnet34.onnx "5ef208a9da1453335308a6b6f4e6dfbd7e183a38b604de0a57664f45d257fe94"

Step "5/7  Your name"
$cfg = @{}
if (Test-Path config.json) { (Get-Content config.json -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } }
$current = $cfg["hostName"]
$name = Read-Host "How should your lines appear in transcripts?$(if ($current) { " [$current]" })"
if (-not $name) { $name = if ($current) { $current } else { "Me" } }
$cfg["hostName"] = $name
$cfg["whisperCli"] = $cli.FullName
$cfg["whisperModel"] = "models/ggml-small.en-q5_1.bin"
$cfg["ripgrep"] = (Get-Command rg -ErrorAction SilentlyContinue).Source
Write-Json (Join-Path $Dir "config.json") $cfg

Step "6/7  Checking microphone access"
Write-Host "If transcripts stay empty, open Settings > Privacy & security > Microphone and turn on"
Write-Host "'Microphone access' and 'Let desktop apps access your microphone'."

Step "7/7  Connecting the helper to the Claude app"
$node = (Get-Command node).Source
$claudeCfg = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
New-Item -ItemType Directory -Force -Path (Split-Path $claudeCfg) | Out-Null
$conf = if (Test-Path $claudeCfg) { Copy-Item $claudeCfg "$claudeCfg.bak-ai-meeting-copilot"; Get-Content $claudeCfg -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
if (-not $conf.PSObject.Properties["mcpServers"]) { $conf | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) }
$entry = [pscustomobject]@{ command = $node; args = @((Join-Path $Dir "server.mjs")) }
if ($conf.mcpServers.PSObject.Properties["meeting-copilot"]) { $conf.mcpServers."meeting-copilot" = $entry }
else { $conf.mcpServers | Add-Member -NotePropertyName "meeting-copilot" -NotePropertyValue $entry }
Write-Json $claudeCfg $conf
# Security: the helper is registered only with the Claude desktop app (which can ask you to confirm actions),
# not with Claude Code, so no coding session can start your microphone.


Write-Host @"

Done. Next steps:
  1. Quit Claude completely (right-click its icon in the system tray > Quit) and reopen it.
  2. Publish your own copy of the page: open Claude Code in this folder and say
       Publish artifact/meeting-copilot.html as an artifact with the capabilities in artifact/capabilities.json
  3. Open it from Artifacts in the Claude app, go to Setup > Record my voice, then press Start.
"@
