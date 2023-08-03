# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SAS-wsm: Script to Start/Stop Windows Services and validate MidTier Readiness
# Version: 2.0.0
# Author: Andy Foreman
# Much of the baseline code derived from previous work by Greg Wootton on 20AUG2020
# Special thanks to John Maxwell for auto-setup start/stop concept implemented in 2.0.0 on 12JUL2023.
####
# Revision History
# 1.0.0 - 16 May 2022
# 1.0.1 - 22 August 2022. Add check on null arrays during webappserver log reading due to rolled logs.
# 1.1.0 - 15 September 2022. Change to external cfg file for service definitions. Add search, input checking and validation functions. Code revisions to support cfg file, etc.
# 2.0.0 - 12 July 2023. Major revisions/rewrite. Merge with auto-setup start/stop script. Add supporting functions and parameters. Retain external cfg as optional support. Remove external cfg tester action.

### GET USER INPUTS
# Get user-specified action as input
# $action = <start|stop|status> [required]
# $saslev = ....\SASConfig\LevN path. Used to verify WebAppServer startup. Script will attempt to determine this if not specified. Example: C:\SAS\Config\Lev1
# $cfg = Custom startup order configuration file. Default order is defined in this file and will be used if not specified.
param([Parameter(Mandatory=$true)]$action,$saslev,$cfg)


#  define main function used to stop / start.  (called at end of script). 
FUNCTION STOPSTART-SASSERVICE ($action,$service,$waitforstate){
	$timeoutSeconds=300 #5 minutes timeout
	$serviceWaitTimeout = New-Object Timespan 0,0,$timeoutSeconds #define object to reference max allowed wait time (in seconds) for Windows to recieve notification that service completed action. This normally takes only a few seconds.
    Write-Host "`n"
    Write-Output '-------------------------------------'
    Write-Host $service.DisplayName "is currently --  " $service.status
    Write-Output '-------------------------------------'
    If ($service.status -NE $waitforstate){
        Write-Host "attempting to $action --  " $service.DisplayName
        Write-Output '-------------------------------------'
        If ($action -eq "stop"){
            Stop-Service -InputObject $service -WarningAction SilentlyContinue -ErrorAction Stop -NoWait #because -NoWait, will not hold here for Windows to report stopped. Check for actually stopped happens from $service.WaitForStatus
        }
        ElseIf ($action -eq "start"){
			Start-Service -InputObject $service -WarningAction SilentlyContinue -ErrorAction Stop #the -NoWait parameter is not available on START operation. If Windows hangs on starting the service, this will too. Can start as background job to avoid this but has major complexity in passing $service object.
        }        
        start-sleep -s 3
		Try {
			$service.WaitForStatus($waitforstate, $serviceWaitTimeout) #await service to report desired status $waitforstate (stop, if we are stopping), or time out after $serviceWaitTimeout timespan object is exceeded. This is equal to $timeoutSeconds seconds
			Write-Host $service.DisplayName "status is:-- " $service.status
			Write-Host "`n"
		}
		Catch {
			throw "ERROR: $action terminated due to $($service.DisplayName) failed to report $waitforstate within $timeoutSeconds seconds."
			#Exit 1 terminate inherent from throw
		}
    }
    else {
        Write-Host "skipping $action action because service is already $waitforstate"
        Write-Output '-------------------------------------'
    }
    start-sleep -s 1
}

FUNCTION CHECK-WEBAPPSERVER-READY($servicename){
	# wait for webappservers to finish deploying webapps before considering them truly started

	If ($script:sasconfigpath.length -gt 0) {
		$webappsvrname =  $servicename | Where {$servicename -match '\b(SASServer\d+_\d+)\b'} | Foreach {$Matches[1]} #strange but functional command... split servicename into just webappserver name, such as SASServer1_1, using regex match looking for SASServer<digits>_<digits>
		Write-Host ("INFO: Checking if Web Application Server $webappsvrname has finished deploying web applications... (this may take a while)")

		$startchecks=0;
		$finishedstart=0;
		Do {
			#pull a list of line numbers from the WebAppServer's server log, matching string indicating server stop operation, then keep only the last member of the list (the latest matching line number)
			$laststop = Select-String -Path "$script:sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Stopping service \[Catalina\]' | select-object -ExpandProperty LineNumber
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
			$lastinit = Select-String -Path "$script:sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern '(Server initialization)|(Initialization processed)' | select-object -ExpandProperty LineNumber
			if ($null -eq $lastinit) {
				$lastinit=0
			}
			else {
				$lastinit = $lastinit[-1]
			}

			#same as laststop but for startup message (printed when the server has finished loading all webapps)
			$laststart = Select-String -Path "$script:sasconfigpath\Web\WebAppServer\$webappsvrname\logs\server.log" -Pattern 'Server startup' | select-object -ExpandProperty LineNumber
			if ($null -eq $laststart) {
				$laststart=0
			}
			else {
				$laststart = $laststart[-1]
			}

			if ($laststop -gt $lastinit){
				#if newest thing in log is stop, there was a problem
				write-host("ERROR: Server initialization does not appear to have started. Verify Web Application Server $webappsvrname is running.")
				Exit 1
			}
			elseif($laststart -gt $lastinit){
				#if newest thing in log is startup complete, the webappserver is ready
			   write-host("INFO: $webappsvrname startup detected.")
			   $finishedstart=1;
			   Continue
			}
			else {
				#wait a minute then check again
				Write-Host "Startup in progress. Checking again in 60 seconds..."
				Start-Sleep 60
				$startchecks++;
			}
		}
		while (($finishedstart -ne 1) -and ( $startchecks -le 30))
			if ($finishedstart -ne 1) {
					Write-Host ("WARN: Web Application Server $webappsvrname has still not completed startup operations. Some Web Applications may still be unavailable until the WebAppServer has fully completed startup.")
			}
	}
	Else {
		Write-Host "WARN: Unable to check Web Application Server's deployment of webapps."
		Write-Host "WARN: Web applications may load errors until this process has completed. Check web application server logs for a startup message to confirm."
		Write-Host "WARN: This message does NOT indicate an inherent problem with your web application servers. Ensure this script was able to determine SAS Configuration Directory path."
	}
}

FUNCTION DETERMINE-SASCONFIG-DIR ($potentialcfgsvc) {
	# Read properties of Windows Services that might reference the SASConfig path.
	# Attempt to determine this and set it so it can be used elsewhere in the script.
	# Enable user to manually specify in case they have nonstandard configuration or want to directly control locations used by other functions.
	
	$cfgfilter="Name='" + "$potentialcfgsvc" + "'" #build proper format for upcoming Get-CimInstance call
	#Write-Host "We built cfgfilter: $cfgfilter" #debug
	$cfgpathobj=Get-CimInstance -ClassName win32_service -Filter "$cfgfilter" | Select PathName | Out-String #obtains the 'PathName' object on the passed Windows Service.
	
	If ($cfgpathobj -match '(?<=-config ").*?Lev\d') {
		#METADATA SERVER. Regex match that takes anything after literal `-config "` and ending on `Lev#`, where # is any single numerical digit. This should result in, for example, C:\SAS\Config\Lev1 , from where the sasv9.cfg is specified in command.
			$script:sasconfigpath=$cfgpathobj -match '(?<=-config ").*?Lev\d' | Foreach {$matches[0]}
			Write-Host "INFO: Successfully determined the SAS Configuration Directory path: $script:sasconfigpath"
	}
	ElseIf ($cfgpathobj -match '\b.*?Lev\d') {
		#JMS BROKER AND/OR CACHE LOCATOR. Regex match that takes from beginning of word until `Lev#`. This match functions on both services, where the beginning of the PathName is the SASConfig dir. Note this actually returns multiple matches, take the first one (later ones have prepended junk)
			$script:sasconfigpath=$cfgpathobj -match '^.*?Lev\d' | Foreach {$matches[0]}
			Write-Host "INFO: Successfully determined the SAS Configuration Directory path: $script:sasconfigpath"
	}
	Else {
		Write-Host "WARN: Failed to locate using SAS Configuration Directory."
		Write-Host "WARN: If this message appears for every attempted service, please specify it manually in your command using -cfg option."
	}
}

### MAIN START HERE
If ($saslev) {
	#user specified a SASConfig path using the -saslev parameter, so try to validate it
	If (Test-Path -Path $saslev\ConfigData\status.xml -PathType leaf) { #status.xml is used by other SAS deployment services and thus should always be in this relative path under sasconfig dir
		$script:sasconfigpath="$saslev" #set the user input to script-scope var used elsewhere
		Write-Host "INFO: Verified SAS Configuration Directory path, using $script:sasconfigpath for this run."
	}
	Else {
		# If the status.xml file does not exist under provided sasconfigdir path, probably not actually a sasconfig dir
		Write-Host "ERROR: Unable to determine if provided folder path contains a SAS Configuration Directory."
		Write-Host "ERROR: Verify that the provided path is correct and includes the LevN."
		Write-Host "ERROR: Example: C:\SAS\Config\Lev1"
		Write-Host "ERROR: Also verify the user running this script has read permissions to the location and subfolders."
		Write-Host "`n"
		Write-Host "ERROR: Alternatively you may leave the -saslev paramater unspecified and the script will attempt to determine it automatically from Windows Services on this host."
		Write-Host "`n"
		Exit 1	
	}
}
Else {
	#user did not specify a SASConfig path when calling script
	$script:sasconfigpath="" #init empty string to store sasconfig path, this will flag later processes to try and determine it using service properties
}

If ($cfg) {
	#user specified a custom startup configuration file using the -cfg parameter, so use that file to build service startup order
	If (Test-Path -Path $cfg -PathType leaf) { #make sure the file exists before trying to parse it
		$StaticStartOrder=@()
		[string[]]$StaticStartOrder = Get-Content -Path "$cfg" #inherent for loop; read each line of $cfg file and load into array $StaticStartOrder as string
		Write-Host "NOTE: Loaded custom startup order from file $cfg"
		$script:UserOrder=1 #set flag to mark this run as using custom user-specified order file (affects matching logic to avoid user-specified file being forced to adhere to regex literal cleansing)
		$StaticStartOrder
	}
	Else {
		Write-Host "ERROR: A custom startup order file was set but the file could not be read. Verify path and permissions."
		Exit 1
	}
}
Else {
	#user did not specify a startup configuration file. Use the "standard" startup order and regex to capture all known possiblities and all known SAS services. Default behavior.
	
	# define the order SAS services order in an array using regular experision. 
	# some experssions will match more than one service
	$StaticStartOrder=@()
	$StaticStartOrder = @(
		".*Metadata Server",  
		".*Web Infrastructure Platform Data Server",
		".*DataServer",
		".*Data Server",
		".*OLAP Server",
		".*object spawner",
		".*SHARE server",
		".*CONNECT spawner",
	   #".*Deployment Tester server", #typically not started unless testing your deployment
		".*JobRunner", #Distributed In-Process Scheduler Job Runner
		".*Launcher"
		".*Workload Orchestrator",
		".*JMS Broker",
		".*Cache Locator",
		".*Information Retrieval Studio",
		".*httpd-WebServer",
		".*httpd - WebServer",
	   #".*Remote Services", # Deprecated Functionality in SAS 9.4
		".*SASServer1_1", #SASServer1_1 must be before other remaining WebServers, Web Application Server
		".*WebAppServer", #Remaining Web Application Servers in any order
		"(?!agent).*Environment Manager", #get EvMgr the server before the agent  (string does not contain 'agent')
		".*Environment Manager Agent", #now get the agent
		".*PC Files",
		".*Deployment Agent",
		".*LSF Process Manager",
		".*LSF LIM",
		".*LSF RES",
		".*LSF SBD"
		#,".*" #start everything -- will launch anything that $GetSASServices locates, even if not defined in this list. Also means things in this list but commented out will be launched. Can be useful for setup, but recommend defining actual names for regular use.
		)

	$script:UserOrder=0 #set flag to designate user did not specify custom startup order
}

# create  an object that holds all Windows Services with SAS in the name -  it is unordered 
# exclude services set to disabled starttype unless service is running
$GetSASServices = Get-Service | 
    where-object {$_.displayname -Match "^SAS*|^IBM Spectrum"-and
    ($_.starttype -NE 'Disabled' -or 
     $_.status -EQ 'running') }

# ---- add each service in $GetSASServices into order into $startorder ----
$startorder=@()
foreach($DefinedService in $StaticStartOrder) { #"outer loop" -> check each object defined in list $StaticStartOrder
	#Write-Host "StaticStartOrder value check: $DefinedService" #debug
	
	
    foreach($service in $GetSASServices){ #"inner loop" -> loop through each service matching SAS in the name (from where-object query that made $GetSASServices)
		#$debugsvcname = $service.DisplayName #debug
		#Write-Host "GetSASServices value check: $debugsvcname" #debug
		If ($script:UserOrder -eq 1) {
			#behavior to use if user provided custom startup order file. USES LITERAL MATCHING.
			if($service.DisplayName -eq "$DefinedService"){ #compare the current service (inner loop) to the current static service order (outer loop)
		
			if ($service -cnotin $StartOrder) { # if there is a match, and it does not already exist in the ordered-list-of-services $StartOrder
				#Write-Host "Literal name $DefinedService matched to service name $debugsvcname , so adding to start order!" #debug
				$StartOrder+=$service
				}
			else { # if there is a match, BUT it's already in the ordered-list-of-services $StartOrder.
				#Write-Host "Literal name $DefinedService matched to service name $debugsvcname , but already exists in StartOrder list. Skipping..." #debug\
				continue
				}
			
			}
		}
        Else {
			#default behavior to run when user did not provide custom startup order file. USES REGEX MATCHING.

			if($service.DisplayName -match "$DefinedService"){ #compare the current service (inner loop) to the current static service order (outer loop)
		
			if ($service -cnotin $StartOrder) { # if there is a match, and it does not already exist in the ordered-list-of-services $StartOrder
				#Write-Host "Regex name $DefinedService matched to service name $debugsvcname , so adding to start order!" #debug
				$StartOrder+=$service
				}
			else { # if there is a match, BUT it's already in the ordered-list-of-services $StartOrder.
				#Write-Host "Regex name $DefinedService matched to service name $debugsvcname , but already exists in StartOrder list. Skipping..." #debug\
				continue
				}
			
			}
		}
		#if here -> not a match, so do nothing... just go to the next service (inner loop)
    }
	
	# This function could use improvement for theoretical efficiency. It is currently highly inefficient.
	# This function in reality completes in a fraction of a second, so the objective effort of changing it is probably not worthwhile.
	#
	# The current function could best be described as a selection sort mixed with a gnome sort? There is no logic to ignore already selected/sorted values.
	# Whenever a match is found, it is checked against the current output (sorted list). If already in the sorted list, it is treated the same as if there was no match at all.
	# The result is you check everything against everything else, but only allow it into the sorted list once, so in the end you have a sorted list of unique values.
	# You just do a lot of unnecessary checks to get there.
	#
	# THE BASIC LOGIC OF THIS FUNCTION AS IT STANDS IS AS FOLLOWS:
	# 1. Get the static list value #1 from position 0 of the array $StaticStartOrder, which is either user-defined (-cfg flag) or from a 'standard' order defined in this file.
	# 		> The example outlined here will reference define values used when checking the SAS Metadata Server
	# 2. Compare to the first value in the located list of services that contain 'SAS' ($GetSASServices).
	#	a.	If the user specified their own startup order configuraton, perform a literal check. 
	#			> Is "Metadata Server" = "randomserviceSAS" ?
	#			> No
	#	b.  If no startup order configuration was specified, perform a regex-based matching check referencing default startup order defined within this file.
	#		Examples past this step use literal ( = ), but regex match is very similar logically.
	#			> Is ".*Metadata Server" a regex match to "randomserviceSAS" ?
	#			> No
	# 3. Is "Metadata Server" = "SAS [Config-Lev1] Connect Spawner" ?
	#		> No
	# 4. Is "Metadata Server" = "SAS [Config-Lev1] SASMeta - Metadata Server" ?
	#		> Yes
	#		> Add "SAS [Config-Lev1] SASMeta - Metadata Server" to position 0 of list/array $StartOrder
	# 5. Is "Metadata Server" = "SAS [Config-Lev1] OLAP Server" ?
	#		> No
	# 6. Continue until checked all values we located on the machine that contain 'SAS' ($GetSASServices)
	# 7. Change static list value to the next position of the static list ($StaticStartOrder position 1). This is "Web Infrastructure Platform Data Server"
	# 8. Is "Web Infrastructure Platform Data Server" = "SAS [Config-Lev1] SASMeta - Metadata Server" ?
	#		> No
	# 9. Is "Web Infrastructure Platform Data Server" = "SAS [Config-Lev1] Web Infrastructure Platform Data Server" ?
	#		> Yes
	#		> Add "SAS [Config-Lev1] Web Infrastructure Platform Data Server" to position 1 of list/array $StartOrder
	# 10. Basically step 6 again. This all continues (7, 8, 9...) until we have looped through the entirety of $StaticStartOrder.
	
	
}

# setup variables needed by custom function, "StopStart-SASService"  
If ($action -eq "stop"){
    $waitforstate='stopped'
    $services=$StartOrder[$StartOrder.count..0] #reverse startup order
    }
ElseIf ($action -eq "start"){
    $waitforstate='running'
    $services=$StartOrder
    }
ElseIf ($action -eq "status"){
	$services=$StartOrder
	}
Else {
    Write-Host -ForegroundColor Red "ERROR: Unknown command defined as action. Valid actions: start , stop , status"
    Exit 1
}

# --- Main Action in Script --- 
# Loop over the function for each service to stop or start 
TRY
{
	If ($action -eq "status"){
		Write-Host "`n"
		Write-Host -ForegroundColor Green "Current Status of SAS services:"
		$services | Format-Table -Property Status, Displayname -AutoSize
	}
	Else {
    Write-Output '-------------------------------------'
    $services | Format-Table -Property Status, Displayname -AutoSize
    Write-Output '-------------------------------------'
    Write-Host "change the state to $action for:"
    Foreach ($service in $services) {
        StopStart-SASService -action $action -service $service -waitforstate $waitforstate -verb $verb
		
		#catch webappservers and check if really started
		If ("$($service.DisplayName)" -match 'WebAppServer' -And $action -eq "start") {
			Check-WebAppServer-Ready -servicename "$($service.DisplayName)" #run webappserver startup validation
		}
		
		#catch various services that could tell us the sasconfig path, if match then check if we already set sasconfig path; attempt to set it if we have not
		If ("$($service.DisplayName)" -match 'Metadata Server' -Or "$($service.DisplayName)" -match 'JMS Broker' -Or "$($service.DisplayName)" -match 'Cache Locator') {
			Write-Host "INFO: Attempting to determine SAS Configuration Directory..."
			If ($script:sasconfigpath.length -gt 0) {
				Write-Host "INFO: SAS Configuration Directory is already set. Current value: $script:sasconfigpath"
			}
			ElseIf ("$($service.DisplayName)" -match 'Metadata Server') {
				Write-Host "Note: Attempting to automatically determine using Metadata Server..."
				Determine-SASConfig-Dir -potentialcfgsvc "$($service.DisplayName)"
			}
			ElseIf ("$($service.DisplayName)" -match 'JMS Broker') {
				Write-Host "INFO: Attempting to automatically determine using JMS Broker..."
				Determine-SASConfig-Dir -potentialcfgsvc "$($service.DisplayName)"
			}
			ElseIf ("$($service.DisplayName)" -match 'Cache Locator') {
				Write-Host "INFO: Attempting to automatically determine using Cache Locator..."
				Determine-SASConfig-Dir -potentialcfgsvc "$($service.DisplayName)"
			}
			Else {
				Write-Host "ERROR: Unexpected condition. Entered the sasconfig determination function but failed to match a service displayname that could potentially tell us the sasconfig."
			}
		}
		
    }
    Write-Host "`n"
    Write-Output '-------------------------------------'
    Write-Host -ForegroundColor Green " Script Finished - Current Status of SAS services in order they were $waitforstate :"
    Write-Output '-------------------------------------'
    $services | Format-Table -Property Status, Displayname -AutoSize
	}
}
CATCH
{
    Write-Output "An error has occurred. Printing latest error to console:"
	Write-Host -ForegroundColor Red "$($Error[0])"
	#Write-Host -ForegroundColor Red "$Error" #DEBUG . Print entire ps error log array, will shows repeats of errors if run multiple times.
}    