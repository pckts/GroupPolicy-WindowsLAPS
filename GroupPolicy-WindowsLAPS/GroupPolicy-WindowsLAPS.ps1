$ProgressPreference = "SilentlyContinue"
$scriptPath = $psISE.CurrentFile.FullPath
$dirPath = Split-Path -Path $scriptPath -Parent

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false)
{
  Clear-Host
  write-host "Please run as admin..."
  sleep 1
  break
}

$OSVersion = Get-ComputerInfo | Select-Object OsName
if ($OSVersion -notmatch '2022' -and $OSVersion -notmatch '2019')
{
  Clear-Host
  write-host "This server does not support Windows LAPS..."
  write-host "For this server to be compatible, it must be upgraded to at least Windows Server 2019, preferably 2022."
  sleep 1
  break
}

$HotFixes = Get-Hotfix | Select-Object HotFixID
$HotFixInstalled = $false
foreach ($HotFix in $HotFixes) 
{
    if (($HotFix.HotFixID -match "KB5025230") -or ($HotFix.HotFixID -match "KB5025231")) 
    {
        $HotFixInstalled = $true
        break
    }
}
if ($HotFixInstalled -eq $false) 
{
    if ($OSVersion -match '2022')
    {
        Clear-Host
        Write-Host "KB5025230 will now be downloaded and installed..."
        Write-Host "Please be patient as this will take a while."
        $URL = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2023/04/windows10.0-kb5025230-x64_a73c874bf9a0f3a2c4df0b7bdeb29226c34ee9f0.msu"
        Invoke-WebRequest -Uri $URL -OutFile $dirPath\KB5025230.msu
        Start-Process -FilePath "wusa.exe" -ArgumentList "$dirPath\KB5025230.msu /quiet /norestart" -Wait
        Clear-Host
        Write-Host "KB5025230 is now installed..."
        Write-Host "The server will now restart to apply the changes."
        Write-Host ""
        Write-Host "Please re-run this script when the server is back online"
        pause
        Restart-Computer
    }
    else 
    {
        Clear-Host
        Write-Host "KB5025229 will now be downloaded and installed..."
        Write-Host "Please be patient as this will take a while."
        $URL = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2023/04/windows10.0-kb5025229-x64_51315f30dd290d51ba049760d7c107c4b90b27c7.msu"
        Invoke-WebRequest -Uri $URL -OutFile $dirPath\KB5025229.msu
        Start-Process -FilePath "wusa.exe" -ArgumentList "$dirPath\KB5025229.msu /quiet /norestart" -Wait
        Clear-Host
        Write-Host "KB5025229 is now installed..."
        Write-Host "The server will now restart to apply the changes."
        Write-Host ""
        Write-Host "Please re-run this script when the server is back online"
        pause
        Restart-Computer
    }
}

Update-LapsADSchema -Confirm:$false

$OUs = Get-ADOrganizationalUnit -Filter * -SearchScope OneLevel
foreach ($OU in $OUs)
{
    Set-LapsADComputerSelfPermission -Identity $OU
}

$DoesGPOExist = Get-GPO -All | Where-Object {$_.displayname -like "WindowsLAPS"}
if ($null -ne $DoesGPOExist)
{
    Remove-GPO -Name WindowsLAPS
}

$Partition = Get-ADDomainController | Select-Object DefaultPartition
$GPOSource = "$dirPath\WindowsLAPS"
import-gpo -BackupId 90CF6CF6-D8B8-4C60-9FFD-63169C98F4D9 -TargetName WindowsLAPS -path $GPOSource -CreateIfNeeded
Get-GPO -Name "WindowsLAPS" | New-GPLink -Target $Partition.DefaultPartition
Set-GPLink -Name "WindowsLAPS" -Enforced Yes -Target $Partition.DefaultPartition
$DisabledInheritances = Get-ADOrganizationalUnit -Filter * | Get-GPInheritance | Where-Object {$_.GPOInheritanceBlocked} | select-object Path 
Foreach ($DisabledInheritance in $DisabledInheritances) 
{
    New-GPLink -Name "WindowsLAPS" -Target $DisabledInheritance.Path
    Set-GPLink -Name "WindowsLAPS" -Enforced Yes -Target $DisabledInheritance.Path
}
