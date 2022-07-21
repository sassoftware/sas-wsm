# SAS-wsm

## Overview

The SAS-wsm utility provides consistent management of SAS-related services for Windows deployments from a single script. Consistent management enables starting, stopping, status checking in a defined and consistent order. You can execute the script from the operating system command line, via a scheduled process, or via your operating system reboot facility.

### What's New

SAS-wsm 1.0 initial release:

* Define start and stop order for Windows services
* Allow user to check status of SAS services from local machine (as well as start/stop them)
* Enable validation of WebAppServer startup including deployment of actual WebApps in startup time

### Prerequisites

* PowerShell - Must be able to run .ps1 PowerShell script

### Installation

Download script and store in a location where it can be accessed. Open the script and set required values:

1) Define SAS services to stop. In the function Stop-SAS, set a list of Windows Services you wish to control, following the tag #DEFINE-VARIABLE.
2) Define SAS services to start. In the function Start-SAS, set a list of Windows Services you wish to control, following the tag #DEFINE-VARIABLE.
3) Define the location of the SAS Configuration Directory. In the function Check-WebAppServer-Ready, set this location on the line tagged #DEFINE-VARIABLE.

Detailed setup documentation is provided in the file **SAS-wsmConfigurationGuide.pdf**.

### Running

Navigate to where the script is stored, then execute it.

Provide the following inputs as shown:

.\SAS-wsm.ps1 -servername \<FQDN of server host\> -action \<start|stop|status\>


### Examples

* Start services: `.\SAS-wsm.ps1 -servername myserver.sas.com -action start`

* Stop services: `.\SAS-wsm.ps1 -servername myserver.sas.com -action stop`

* Check service status: `.\SAS-wsm.ps1 -servername myserver.sas.com -action status`

## Contributing

We welcome your contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit contributions to this project.

## License

This project is licensed under the [Apache 2.0 License](LICENSE).

## Additional Resources

For Linux/UNIX users, see the SAS-lsm project:
* [SAS Note 58231](http://support.sas.com/kb/58/231.html)
* [SAS_lsm Demo Blog](https://communities.sas.com/t5/SAS-Communities-Library/The-SAS-lsm-Utility-Makes-it-Easy-to-Control-SAS-Servers-in-a/ta-p/418165)
* [SGF 2017 Proceedings](http://support.sas.com/resources/papers/automating-management-unix-linux-multi-tiered-sas-services.pdf)
* [SGF 2018 Proceedings](https://www.sas.com/content/dam/SAS/support/en/sas-global-forum-proceedings/2018/1921-2018.pdf)
