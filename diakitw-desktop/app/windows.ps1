$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$r = @{}
try { $r.os = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 2 | Select-Object TotalVisibleMemorySize,FreePhysicalMemory } catch {}
try { $r.page = @(Get-CimInstance Win32_PageFileUsage -OperationTimeoutSec 2 | Select-Object CurrentUsage,AllocatedBaseSize) } catch {}
try { $r.net = @(Get-NetAdapterStatistics -ErrorAction Stop | Select-Object Name,ReceivedBytes,SentBytes) } catch {}
try { $r.battery = @(Get-CimInstance Win32_Battery -OperationTimeoutSec 2 | Select-Object EstimatedChargeRemaining,BatteryStatus) } catch {}
try { $r.routes = @(Get-NetRoute -ErrorAction Stop | Sort-Object InterfaceIndex,DestinationPrefix,NextHop,RouteMetric | Select-Object InterfaceIndex,DestinationPrefix,NextHop,RouteMetric) } catch {}
$r | ConvertTo-Json -Depth 4 -Compress
