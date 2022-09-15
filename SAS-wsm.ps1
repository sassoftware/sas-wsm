# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SAS-wsm: Script to Start/Stop Windows Services and validate MidTier Readiness
# Version: 1.1.0
# Author: Andy Foreman
# Much of the baseline code derived from previous work by Greg Wootton on 20AUG2020
####
# Revision History
# 1.0.0 - 16 May 2022
# 1.0.1 - 22 August 2022. Add check on null arrays during webappserver log reading due to rolled logs.
# 1.1.0 - 15 September 2022. Change to external cfg file for service definitions. Add search, input checking and validation functions. Code revisions to support cfg file, etc.

# Get action and config file as arguments
param($action, $cfg)

######## USER-DEFINED VARIABLES ########

# SAS Configuration Directory folder path, including Lev#, in quotes.
# $sasconfigpath="C:\SAS\Config\Lev1\"
$sasconfigpath = "C:\SAS\SASConfig\Lev1\"

##### DO NOT EDIT BELOW THIS LINE ######

# Define a Stop SAS function to stop sas services in order. This list can be augmented, just be sure the order is correct.
function Stop-SAS {
    Get-SAS
	$stoparray = Get-Content -Path $cfg
	[array]::Reverse($stoparray) #user cfg file has services in start order, so reverse it
	$stoparray | ForEach-Object {

        # Check if the service is running
        $service=Get-WMIObject -Class Win32_Service -filter "Name = '$_' AND State != 'Stopped'"

        if (!$service) {
            Write-Host "NOTE: $_ is not running or doesn't exist on this host. Moving to the next service."
        }
        else {
            # if it is running, stop it.
            Write-Host "NOTE: $_ is running. Stopping it."
            $status = $service.stopservice()

            # Check the return code of the attempt.
            if ($status.ReturnValue -eq 0) {
                Write-Host "NOTE: Stop command returned successfully for $_."
            }
            else {
                Write-Host "ERROR: Failed to stop $_. Stop command returned a non-zero code. Return code: " $status.ReturnValue
                Write-Host "NOTE: Here is the current state of services."
                Get-SAS
                exit
            }
            # Wait until it's stopped successfully before moving on (or until 30 seconds have elapsed).
            Write-Host "NOTE: Checking status of $_ to confirm it has stopped before moving on."
            $i = 0
            do {
                Start-Sleep -s 5
                $state=Get-WMIObject -Class Win32_Service -filter "Name = '$_'"
                write-host "Current status: " $state.State                
                $i++
            } while (($state.State -ne "Stopped") -and ( $i -le 24))
            if ( $state.State -ne "Stopped") {
                Write-Host "ERROR: Service $_ never stopped. Exiting."
                exit
            }
        }
    }
    Get-SAS
}

function Start-SAS {
Get-SAS
$startarray = Get-Content -Path $cfg	
$startarray | ForEach-Object {

        # Check if the service is stopped
        $service=Get-WMIObject -Class Win32_Service -filter "Name = '$_' AND State != 'Running'"

        if (!$service) {
            Write-Host "NOTE: $_ is not in a state other than 'Running' or doesn't exist on this host."
        }
        else {
            # if it is stopped, start it.
            Write-Host "NOTE: $_ is not in a Running state. Starting it."
            $status = $service.startservice()
            # Sleep before continuing to give time for graceful startup.
            if ($status.ReturnValue -eq 0) {
                Write-Host "NOTE: Start command returned successfully for $_."
            }
            else {
                Write-Host "ERROR: Start command for  $_ gave a non-zero return code. Exiting. Return code: " $status.ReturnValue
                Get-SAS
                exit
            }
            # Wait until it's stopped successfully before moving on (or until 30 seconds have elapsed).
            Write-Host "NOTE: Checking status of $_ to confirm it has started before moving on."
            $i = 0
            do {
                Start-Sleep -s 5
                $state=Get-WMIObject -Class Win32_Service -filter "Name = '$_'"
                write-host "Current status: " $state.State                
                $i++
            } while (($state.State -ne "Running") -and ( $i -le 24))
            if ($state.State -ne "Running") {
            Write-Host "ERROR: Service $_ never finished starting. Exiting."
            exit
            }
			if ($_ -like '*SASServer*') {
			Check-WebAppServer-Ready $_
			}
        }
    }
    Get-SAS
}

function Get-SAS {
    $statusarray = Get-Content -Path $cfg
	Write-Host ""
    Write-Host "Current services status:"
	#Use array contents as WHERE so that we only need to make one Get-WmiObject call, to allow the Format-Table creation of an easy-to-read table.
	#Inspired by https://social.technet.microsoft.com/Forums/en-US/43b1f971-e1ad-44ae-a98a-8667248a0fde/getwmiobject-win32service-for-a-list-of-services?forum=winserverpowershell
	#Only issue with this method is that we don't seem to be able to control the order of services listed in the output... it operates the same way Search-SAS-IBM does,
	#it would be nice if we could display in the user-defined order instead.
	Get-WmiObject Win32_Service | Where { ($statusarray) -Contains $_.Name} | Format-Table DisplayName, State
	
	#original method for checking service status is retained below
	#this method works and displays in user-defined order, but produces a "new" table for each entry as we iteratively call Get-WMIObject. Hard to read.
	#$statusarray | ForEach-Object {
	#	Get-WMIObject -Class Win32_Service -filter "Name = '$_'" | Format-Table -HideTableHeaders -Property DisplayName,State
	#}
}

function Search-SAS-IBM {
    Write-Host ""
    Write-Host "Here are all the SAS and IBM Services present:"
    
    # Get a list of services and their status
    Get-WMIObject -Class Win32_Service -filter "Name LIKE 'SAS%' OR DisplayName LIKE 'IBM%'" | Format-Table -Property DisplayName,State,StartMode
    
}

function Check-Input {
    Write-Host ""
	#make sure sas config dir exists
	if (Test-Path -Path $sasconfigpath) {
		Write-Host "Using SAS Configuation Directory path $sasconfigpath."
    } else {
		Write-Host "ERROR: Unable to access SAS Configuration Directory at path $sasconfigpath."
		Write-Host "Ensure the defined SAS Configuration Directory inside SAS-wsm.ps1 is correct."
		Write-Host "Exiting..."
		exit
    }
	#make sure user cfg file contains something that is probably SAS services (this is a loose determination at best)
	if ($cfg.Length -gt 0) {
		if (Select-String -SimpleMatch -Path $cfg -Pattern "SAS [") {
			Write-Host "Using input configuration file $cfg."
		} else {
			Write-Host "ERROR: Unable to determine if any SAS services are defined in configuration file $cfg."
			Write-Host "Verify the contents of this file is accurate using the -action validate flag."
			Write-Host "Exiting..."
			exit
		}
	} else {
		Write-Host ""
		Write-Host "ERROR: Configuration file is missing, empty, or undefined."
		Write-Host "Verify that the specified -cfg flag's filepath is correct and readable."
		Write-Host "Exiting..."
		exit
	}
	Write-Host ""
}

function Validate-Cfg {
	Write-Host ""
	#check sas config dir
	if (Test-Path -Path $sasconfigpath) {
		Write-Host "SAS Configuration Directory exists."
		Write-Host "SAS Configuation Directory path: $sasconfigpath."
    } else {
		Write-Host "ERROR: SAS Configuration Directory could not be accessed."
		Write-Host "SAS Configuation Directory path: $sasconfigpath."
    }
	
	#check user cfg file contents
	if ($cfg.Length -gt 0) {
		Write-Host ""
		Write-Host "Configuration file exists."
		Write-Host "Listing contents read from configuration file $cfg :"
		Write-Host ""
		$vcount=1
		$validatearray = Get-Content -Path $cfg
		$validatearray | ForEach-Object {
				Write-Host "$vcount) $_"
				$vcount++
			}
		Write-Host ""
		Write-Host "End list of configuration file contents. Verify all expected services appeared above!"
		}
	else {
		Write-Host ""
		Write-Host "ERROR: Configuration file is missing, empty, or undefined."
		Write-Host "Verify that the specified -cfg flag's filepath is correct and readable."
	}
}
	

function Check-WebAppServer-Ready($servicename){ #call function using $_ to send the name of the service we are calling

$webappsvrname =  $servicename | Where {$servicename -match '\b(SASServer\d+_\d+)\b'} | Foreach {$Matches[1]} #strange but functional command... split servicename into just webappserver name, such as SASServer1_1, using regex match looking for SASServer<digits>_<digits>


Write-Host ("Checking if Web Application Server $webappsvrname has finished startup...")


$startchecks=0;
$finishedstart=0;
Do {

#pull a list of line numbers from the WebAppServer's server log, matching string indicating server stop operation, then keep only the last member of the list (the latest matching line number)
$laststop = Select-String -Path "$sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Stopping service \[Catalina\]' | select-object -ExpandProperty LineNumber
if ($null -eq $laststop) {
	#Enter here if we did not find any matches on the Pattern search, which can happen if the log file is new or rolled.
	#In this instance, just consider the last action as line 0 for logic. lastinit should always be line 1 in this case. This prevents assigning on null arrays.
	$laststop=0
}
else {
	$laststop = $laststop[-1]
}

#same as laststop but for initialization message (printed when the server starts loading its webapps)
#message changes depending on hotfix level... old is 'Initialization processed' , new is 'Server initialization'
#if lastinit never finds a match, probably still on old version and need to change the string after -Pattern below to use the old syntax as shown above
$lastinit = Select-String -Path "$sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Server initialization' | select-object -ExpandProperty LineNumber
if ($null -eq $lastinit) {
	$lastinit=0
}
else {
	$lastinit = $lastinit[-1]
}

#same as laststop but for startup message (printed when the server has finished loading all webapps)
$laststart = Select-String -Path "$sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Server startup' | select-object -ExpandProperty LineNumber
if ($null -eq $laststart) {
	$laststart=0
}
else {
	$laststart = $laststart[-1]
}

if ($laststop -gt $lastinit){
	#if newest thing in log is stop, there was a problem
	write-host("Server initialization does not appear to have started. Verify Web Application Server $webappsvrname is running.")
	Break
}
elseif($laststart -gt $lastinit){
	#if newest thing in log is startup complete, the webappserver is ready
   write-host("$webappsvrname startup detected.")
   $finishedstart=1;
   Continue
}
else {
	#wait a minute then check again
	Write-Host "Waiting 60 seconds..."
    Start-Sleep 60
    $startchecks++;
}
}while (($finishedstart -ne 1) -and ( $startchecks -le 30))
if ($finishedstart -ne 1) {
            Write-Host ("Web Application Server $webappsvrname has not completed startup operations. Some Web Applications may still be unavailable until the WebAppServer has fully completed startup.")
            }
}


If ( $action -eq 'stop' ) {
    Check-Input
	Stop-SAS
}
ElseIf ( $action -eq 'start' ) {
    Check-Input
	Start-SAS
}
ElseIf ($action -eq 'status') {
    Get-SAS
}
ElseIf ($action -eq 'validate') {
    Validate-Cfg
}
ElseIf ($action -eq 'search') {
Search-SAS-IBM
}
Else {
    Write-Host "Acceptable actions are 'search', 'start', 'status', 'stop', and 'validate'."
    exit
}