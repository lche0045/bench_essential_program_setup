Function ConvertTo-Boolean {
    <#
        .SYNOPSIS
            Convert 'y' or 'Y' to be a boolean True. Else, False.

        .EXAMPLE
            ConvertTo-Boolean -Variable "Y"
    #>
    param($Variable)
    if (($Variable).ToLower() -eq "y") {
        $True
    }
    else {
        $False
    }
}

Function program_to_be_install_printout {
    <#
        .SYNOPSIS
            Print out programs to be installed in a formatted manner.

        .EXAMPLE
            program_to_be_install_printout -program_list $software_install_list
    #>
    param($program_list)
    Write-Verbose "Programs to be installed:" -Verbose
    foreach ($program in $program_list) {
        $index = $program_list.IndexOf($program) + 1
        Write-Verbose "($index) $program" -Verbose
    }
}

$host.ui.RawUI.WindowTitle = 'Test Bench Essential Program Setup'
# Start transciption for future debugging purposes
$LogPS = "${env:SystemRoot}" + "\Temp\ps_download.log"
Start-Transcript $LogPS

# Check for currently available drive capacity and show warning if no external drive is found.
Write-Verbose "Checking drive capacity on the system." -Verbose
[array]$a = Get-WmiObject Win32_Volume -Filter "DriveType='3'"
$total=0;Get-WmiObject Win32_Volume -Filter "DriveType='3'" | ForEach-Object {$total += [Math]::Round((($_.FreeSpace) / 1GB),2)};
$drive_count = $a.Length
Write-Output "$drive_count Drive(s) detected. TotalFreeSpace_GB : $total"

if ($drive_count -eq 1) {
    Write-Warning "No external storage drive detected."
}

# List of programs to check for
$software_list = New-Object -TypeName 'System.Collections.ArrayList';
$software_list.Add("Sublime Text 3") > $null
$software_list.Add("Microsoft VS Code") > $null
$software_list.Add("Git") > $null

$software_install_list = New-Object -TypeName 'System.Collections.ArrayList';

# Customize the directory path according to the user. Default = FTC
$default_user = "FTC"
$user_input = Read-Host "Who is this? Press enter to accept the default [$($default_user)]"
$user_input = ($default_user, $user_input)[[bool]$user_input]

$vs_code_path = "C:\Users\" + $user_input + "\AppData\Local\Programs\Microsoft VS Code"
$benchsync_check_path = "C:\Users\" + $user_input + "\Desktop\benchsync"
$benchsync_clone_path = "C:\Users\" + $user_input + "\Desktop"
$logical_path = "C:\Niagara\Logical"
$auto_code_downloader_check_path = "C:\Users\" + $user_input + "\Desktop\Automated CI Code Downloader"
$auto_code_downloader_clone_path = $benchsync_clone_path

foreach($software in $software_list)
{
    if("Microsoft VS Code" -eq $software)
    {
        $installed = (Test-Path -Path $vs_code_path)
    }
    else 
    {
        $installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -match $software }) -ne $null
    }

	If(-Not $installed) {
        Write-Host "'$software' is NOT installed.";
        $software_install_list.Add($software) > $null
	} else {
		Write-Host "'$software' is already installed."
	}
}

If ($software_install_list.count -gt 0) {
    program_to_be_install_printout -program_list $software_install_list
}

# Prompt to record user's decision on the installing and clonning process
$install_flag = Read-Host -Prompt "Do you wish to install the following program(s)? (Y/N)"
$clone_flag = Read-Host -Prompt "Do you wish to automatically CLONE or UPDATE useful repo (including Logical) (Y/N)?"
$install_flag = ConvertTo-Boolean -Variable $install_flag
$clone_flag = ConvertTo-Boolean -Variable $clone_flag

$StartDTM = (Get-Date)

# Installation block
if ($install_flag) {
    If (!(Test-Path -Path "Installer") -and ($software_install_list.count -gt 0)) {
        New-Item -ItemType directory -Path "Installer"
        Push-Location -Path "Installer"
    }

    foreach($software in $software_install_list)
    {
        Write-Verbose "Installing $software" -Verbose
        if ( "Sublime Text 3" -eq $software )
        {
            Write-Verbose "Setting Arguments" -Verbose
            $Vendor = "sublime"
            $Product = "Sublime Text"
            $Version = "3"
            $PackageName = "Sublime_Text_Build_3211_x64_Setup"
            $InstallerType = "exe"
            $Source = "$PackageName" + "." + "$InstallerType"

            $UnattendedArgs = '/verysilent /suppressmsgboxes /mergetasks=!runcode'
            $url = "https://download.sublimetext.com/Sublime%20Text%20Build%203211%20x64%20Setup.exe"
            $ProgressPreference = 'SilentlyContinue'

            Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
            If (!(Test-Path -Path $Source)) {
                Invoke-WebRequest -Uri $url -OutFile $Source
            }
            Else {
                Write-Verbose "File exists. Skipping Download." -Verbose
            }

            Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
            Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru
        }
        elseif ("Microsoft VS Code" -eq $software)
        {
            Write-Verbose "Setting Arguments" -Verbose
            $Vendor = "Microsoft"
            $Product = "Visual Studio Code"
            $Version = "1.23.3"
            $PackageName = "VSCode_x64"
            $InstallerType = "exe"
            $Source = "$PackageName" + "." + "$InstallerType"

            $UnattendedArgs = '/verysilent /suppressmsgboxes /mergetasks=!runcode'
            $url = "https://aka.ms/win32-x64-user-stable"
            $ProgressPreference = 'SilentlyContinue'

            Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
            If (!(Test-Path -Path $Source)) {
                Invoke-WebRequest -Uri $url -OutFile $Source
            }
            Else {
                Write-Verbose "File exists. Skipping Download." -Verbose
            }

            Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
            Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru
        }
        elseif ("Git" -eq $software)
        {
            Write-Verbose "Setting Arguments" -Verbose
            $Vendor = "git"
            $Product = "Git"
            $Version = "4"

            # get latest download url for git-for-windows 64-bit exe
            $git_url = "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $asset = Invoke-RestMethod -Method Get -Uri $git_url | % assets | where name -like "*64-bit.exe"

            # download installer
            $installer = "$env:temp\$($asset.name)"
            Write-Verbose "Downloading $installer" -Verbose
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer

            # run installer
            Write-Verbose "Starting Installation" -Verbose
            $git_install_inf = "git.inf"
            $install_args = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NOCANCEL /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /LOADINF=""$git_install_inf"""
            Start-Process -FilePath $installer -ArgumentList $install_args -Wait
        }
    }
}

# Clonning block
if ($clone_flag) {
    Write-Verbose "Clonning useful repo for bench setup." -Verbose
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    If (!(Test-Path -Path $benchsync_check_path)) {
        Push-Location -Path $benchsync_clone_path
        Write-Verbose "Trying to clone from Raja's repo for Benchsync_TM" -Verbose
        git clone "https://bitbucket.wdc.com/scm/~raja.ahmad.asyraf.raja.idris_wdc.com/benchsync.git"
    }
    Else {
        Write-Verbose "Benchsync_TM exists. Skipping clone." -Verbose
        Write-Verbose "Proceed to update Benchsync_TM to the latest version." -Verbose
        Push-Location -Path $benchsync_check_path
        git reset --hard
        git checkout master
        git pull
    }

    If (!(Test-Path -Path $logical_path)) {
        Push-Location -Path "C:\Niagara\"
        Write-Verbose "Trying to clone FWTEST_Logical" -Verbose
        git clone "https://svc-fwtest-general%40wdc.com@urc-epasc02.hgst.com/a/FWTEST_Logical"
        Rename-Item "FWTEST_Logical" "Logical"
    }
    Else {
        Write-Verbose "Logical exists in Niagara. Skipping clone." -Verbose
        Write-Verbose "Proceed to update Logical to the latest version." -Verbose
        Push-Location -Path $logical_path
        git reset --hard
        git checkout master
        git pull
    }

    If (!(Test-Path -Path $auto_code_downloader_check_path)) {
        Push-Location -Path $auto_code_downloader_clone_path
        Write-Verbose "Trying to clone from LikSiang's repo for Automated CI Code Downloader" -Verbose
        git clone "https://bitbucket.wdc.com/scm/~lik.siang.chew_wdc.com/automated-ci-code-downloader.git"
    }
    Else {
        Write-Verbose "Automated CI Code Downloader exists. Skipping clone." -Verbose
        Write-Verbose "Proceed to update Automated CI Code Downloader to the latest version." -Verbose
        Push-Location -Path $auto_code_downloader_check_path
        git reset --hard
        git checkout master
        git pull
    }
}

Write-Verbose "Stop logging" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
pause
Stop-Transcript