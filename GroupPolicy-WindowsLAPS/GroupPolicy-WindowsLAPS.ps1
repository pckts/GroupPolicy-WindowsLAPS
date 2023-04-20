$ProgressPreference = "SilentlyContinue"

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
    if (($HotFix.HotFixID -match "KB5025230") -or ($HotFix.HotFixID -match "KB5025231")) {
        $HotFixInstalled = $true
        break
    }
}
if ($HotFixInstalled -eq $false) 
{
    if ($OSVersion -match '2022')
    {
        $scriptPath = $psISE.CurrentFile.FullPath
        $dirPath = Split-Path -Path $scriptPath -Parent
        Clear-Host
        Write-Host "KB5025230 will now install..."
        Write-Host "Please be patient as this will take a while."
        Start-Process -FilePath "wusa.exe" -ArgumentList "$dirPath\KB5025230.msu /quiet /norestart" -Wait
        Clear-Host
        Write-Host "KB5025230 is now installed..."
        Write-Host "The server will restart in 30 seconds to apply the changes."
        sleep 5
        Restart-Computer
        exit
    }
    else 
    {
        $scriptPath = $psISE.CurrentFile.FullPath
        $dirPath = Split-Path -Path $scriptPath -Parent
        Clear-Host
        Write-Host "KB5025229 will now install..."
        Write-Host "Please be patient as this will take a while."
        Start-Process -FilePath "wusa.exe" -ArgumentList "$dirPath\KB5025229.msu /quiet /norestart" -Wait
        Clear-Host
        Write-Host "KB5025229 is now installed..."
        Write-Host "The server will restart in 30 seconds to apply the changes."
        sleep 5
        Restart-Computer
        exit
    }
}

Update-LapsADSchema

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
import-gpo -BackupId 2B7ED803-C83D-4F74-8BD9-5690D0C0251F -TargetName WindowsLAPS -path $GPOSource -CreateIfNeeded
Get-GPO -Name "WindowsLAPS" | New-GPLink -Target $Partition.DefaultPartition
Set-GPLink -Name "WindowsLAPS" -Enforced Yes -Target $Partition.DefaultPartition
$DisabledInheritances = Get-ADOrganizationalUnit -Filter * | Get-GPInheritance | Where-Object {$_.GPOInheritanceBlocked} | select-object Path 
Foreach ($DisabledInheritance in $DisabledInheritances) 
{
    New-GPLink -Name "WindowsLAPS" -Target $DisabledInheritance.Path
    Set-GPLink -Name "WindowsLAPS" -Enforced Yes -Target $DisabledInheritance.Path
}
