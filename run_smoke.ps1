Set-Location 'E:\qs\ScreenSense\tools\smoke'
& 'D:\Pango\PDS_2025.2-SP3-EN-ads\bin\pds_shell.exe' -file 'E:\qs\ScreenSense\tools\smoke\flow_smoke.tcl' *> 'E:\qs\ScreenSense\tools\smoke\smoke.log'
Add-Content 'E:\qs\ScreenSense\tools\smoke\smoke.log' ('EXIT=' + $LASTEXITCODE)
