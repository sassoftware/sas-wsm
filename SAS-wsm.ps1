# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SAS-wsm: Script to Start/Stop Windows Services and validate MidTier Readiness
# Version: 1.0.1
# Author: Andy Foreman
# Much of the baseline code derived from previous work by Greg Wootton on 20AUG2020
####
# Revision History
# 1.0.0 - 16 May 2022
# 1.0.1 - 22 August 2022. Add check on null arrays during webappserver log reading due to rolled logs.


# Get server name and action as arguments
param($servername,$action)

# Define a Stop SAS function to stop sas services in order. This list can be augmented, just be sure the order is correct.
function Stop-SAS {

    Get-SAS
	#DEFINE-VARIABLE
    "SAS Deployment Agent",
    "SAS [Config-Lev1] SAS Environment Manager Agent",
    "SAS [Config-Lev1] SAS Environment Manager",
    "SAS [config-Lev1] Information Retrieval Studio",
    "SAS [Config-Lev1] SASServer12_1 - WebAppServer",
    "SAS [Config-Lev1] SASServer2_1 - WebAppServer",
    "SAS [Config-Lev1] SASServer1_1 - WebAppServer",
    "SAS[Config-Lev1]httpd-WebServer", #httpd/Web Server intentionally missing spaces, Windows will not detect it otherwise
    "SAS [Config-Lev1] httpd - WebServer",
    "SAS [Config-Lev1] Cache Locator on port 41415",
    "SAS [Config-Lev1] JMS Broker on port 61616",
    "SAS [Config-Lev1] DIP JobRunner",
    "SAS [Config-Lev1] Deployment Tester Server",
    "SAS [Config-Lev1] Object Spawner",
    "SAS [Config-Lev1] SASApp - OLAP Server",
    "SAS [Config-Lev1] Remote Services",
    "SAS [Config-Lev1] Web Infrastructure Platform Data Server",
    "SAS [Config-Lev1] SASMeta - Metadata Server" | ForEach-Object {

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
                Get-WMIObject -Class Win32_Service -filter "Name LIKE 'SAS%' OR DisplayName LIKE 'IBM%'" | Format-Table -Property DisplayName,State,StartMode
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
	#DEFINE-VARIABLE
    "SAS [Config-Lev1] SASMeta - Metadata Server",
    "SAS [Config-Lev1] Web Infrastructure Platform Data Server",
	"SAS [Config-Lev1] Remote Services",
	"SAS [Config-Lev1] SASApp - OLAP Server",
	"SAS [Config-Lev1] Object Spawner",
    "SAS [Config-Lev1] Deployment Tester Server",
	"SAS [Config-Lev1] DIP JobRunner",
    "SAS [Config-Lev1] JMS Broker on port 61616",
	"SAS [Config-Lev1] Cache Locator on port 41415",
	"SAS[Config-Lev1]httpd-WebServer",
	"SAS [Config-Lev1] httpd - WebServer",
	"SAS [Config-Lev1] SASServer1_1 - WebAppServer",
	"SAS [Config-Lev1] SASServer2_1 - WebAppServer",
	"SAS [Config-Lev1] SASServer12_1 - WebAppServer",
	"SAS [config-Lev1] Information Retrieval Studio",
	"SAS [Config-Lev1] SAS Environment Manager",
	"SAS [Config-Lev1] SAS Environment Manager Agent",
	"SAS Deployment Agent" | ForEach-Object {

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
                Get-WMIObject -Class Win32_Service -filter "Name LIKE 'SAS%' OR DisplayName LIKE 'IBM%'" | Format-Table -Property DisplayName,State,StartMode
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
    Write-Host ""
    Write-Host "Here are the SAS and IBM Services present:"
    
    # Get a list of services and their status
    Get-WMIObject -Class Win32_Service -filter "Name LIKE 'SAS%' OR DisplayName LIKE 'IBM%'" | Format-Table -Property DisplayName,State,StartMode
    
}


function Check-WebAppServer-Ready($servicename){ #call function using $_ to send the name of the service we are calling

$sasconfigpath = "D:\SAS\Config\Lev1\" #DEFINE-VARIABLE: SAS Configuration Path, including Lev#, in quotes. Example: "D:\SAS\Config\Lev1\"
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
$lastinit = Select-String -Path "$sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Initialization processed' | select-object -ExpandProperty LineNumber
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
    Stop-SAS
}
ElseIf ( $action -eq 'start' ) {
    Start-SAS
}
ElseIf ($action -eq 'status') {
    Get-SAS
}
Else {
    Write-Host "Acceptable actions are 'start', 'status' and 'stop'."
    exit
}