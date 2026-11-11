# Flash a bitstream over JTAG.  Usage: program.ps1 <path-to.sbit>
param([Parameter(Mandatory=$true)][string]$Bitstream)
$ErrorActionPreference = 'Stop'
$bin = 'D:\Pango\PDS_2025.2-SP3-EN-ads\bin'
$here = $PSScriptRoot
if (-not (Test-Path $Bitstream)) { throw "bitstream not found: $Bitstream" }
$abs = (Resolve-Path $Bitstream).Path
'bitstream: ' + $abs

# start the JTAG server if it is not already listening
$js = Get-Process cdt_js -ErrorAction SilentlyContinue
if (-not $js) {
    Start-Process -FilePath (Join-Path $bin 'cdt_js.exe') -ArgumentList '-port','65420' -WindowStyle Hidden
    Start-Sleep -Seconds 3
    'started cdt_js on port 65420'
} else { 'cdt_js already running' }

& (Join-Path $bin 'cdt_cfg.exe') -file (Join-Path $here 'program.tcl') -args $abs
'exit: ' + $LASTEXITCODE
