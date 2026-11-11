# Build the scheduler firmware and turn it into a 8192-word IROM image.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$gcc  = 'E:\qs\toolchain\riscv\bin\riscv-none-elf-gcc.exe'
$objc = 'E:\qs\toolchain\riscv\bin\riscv-none-elf-objcopy.exe'
$ld   = ((Resolve-Path (Join-Path $here 'scheduler.ld')).Path) -replace '\\','/'
$out  = Join-Path $here 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null

& $gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -Os -nostdlib -nostartfiles -T $ld `
    -o (Join-Path $out 'scheduler.elf') (Join-Path $here 'start.S') (Join-Path $here 'scheduler.c')
if ($LASTEXITCODE -ne 0) { throw 'gcc failed' }

& $objc -O binary (Join-Path $out 'scheduler.elf') (Join-Path $out 'scheduler.bin')
if ($LASTEXITCODE -ne 0) { throw 'objcopy failed' }

$bin = [IO.File]::ReadAllBytes((Join-Path $out 'scheduler.bin'))
'binary: ' + $bin.Length + ' bytes'

$words = 8192
$sb = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt $words; $i++) {
    $w = 0x00000013   # nop for padding
    if (($i * 4 + 3) -lt $bin.Length) {
        $w = [BitConverter]::ToUInt32($bin, $i * 4)
    }
    [void]$sb.AppendLine(('{0:x8}' -f $w))
}
$dst = Join-Path $here '..\..\prj_pds\build\pipeline\irom.hex'
[IO.File]::WriteAllText($dst, $sb.ToString())
'wrote ' + $dst
