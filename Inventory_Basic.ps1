$script:root = 'D:\AdminScripts'

$ProductionServers = Get-Content (Join-Path $script:root -ChildPath 'Production.txt')

$AliasList = Get-Content (Join-Path $script:root -ChildPath 'AliasList.txt') | Select @{Name= "Instance";Expression={$_.ToString().Split(';')[0]}},@{Name= "Alias";Expression={$_.ToString().Split(';')[1]}}

$systemDBs = "master","model","msdb","tempdb", "ReportServer","ReportServerTempDB"

$rawData = $ProductionServers | Connect-DbaInstance | Sort Computername | Select ComputerName,

 # map the SQL version

@{Name="SQL Version";Expression={ if ($_.VersionMajor -eq "11") {"SQL 2012"} elseif ($_.VersionMajor -eq "12") {"SQL 2014"} elseif ($_.VersionMajor -eq "13") {"SQL 2016"} 

elseif ($_.VersionMajor -eq "14") {"SQL 2017"} elseif ($_.VersionMajor -eq "15") {"SQL 2019"} elseif ($_.VersionMajor -lt "11") {"SQL 2008R2 or older"} else {"unknown"}}}, 

ProductLevel, Edition, 

# RAM

@{Name= "Memory (GB)";Expression={[math]::Round(($_.PhysicalMemory) / 1024)}},

Processors, InstanceName, 

# total count of user dbs

@{Name= "User DBs";Expression={($_.Databases | Where {$_.Name -notin $systemDBs} | Measure).Count}},

# total db size for all user dbs

@{Name= "Total DB Size (GB)";Expression={[math]::Round(($_.Databases | Where {$_.Name -notin $systemDBs} | Select size | Measure -Property Size -sum | Select sum).sum / 1024)}}, 

# biggest DB (name, Size(GB)

@{Name= "Biggest DB (GB)";Expression={"$($_.Databases | Where {$_.Name -notin $systemDBs} | Sort Size -Descending | Select -ExpandProperty Name -First 1) 

($([math]::Round(($_.Databases | Where {$_.Name -notin $systemDBs} | Sort Size -Descending | Select -ExpandProperty Size -First 1)/1024)) GB)"}},

# add the name of the Availability Group (if any)

@{Name= "AG (s)";Expression={$_ | Select -ExpandProperty AvailabilityGroups | Select -ExpandProperty AvailabilityGroupListeners}}, 

# add the current role of the server in the Availability Group (if any)

@{Name= "Role (s)";Expression={$_ | Select -ExpandProperty AvailabilityGroups | Select -ExpandProperty LocalReplicaRole}}, ClusterName | Sort ComputerName

# add the alias to the rawdata

$rawData | % {

$v = $_.ComputerName

if ('' -ne $_.InstanceName){$v +="\$($_.InstanceName)"}

$alias = $AliasList | Where {$_.Instance -eq $v } | Select -ExpandProperty Alias -First 1

$_ | Add-Member -MemberType NoteProperty -Name AliasName -Value $alias

} 

$css = Get-Content (Join-Path $script:root -ChildPath 'css.txt')

$html = $rawData | ConvertTo-Html -Fragment -PreContent "$($css)&lt;h2&gt;Instance KPI Summary&lt;/h2&gt;" -PostContent "This summary has been generated with the help of the awesome PSTools!" | Out-File (Join-Path $script:root -ChildPath 'result.html')
