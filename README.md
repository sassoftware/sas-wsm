# SAS-wsm

## Overview

The SAS-wsm utility provides consistent management of SAS-related services for Windows deployments from a single script. Consistent management enables starting, stopping, status checking in a defined and consistent order. You can execute the script from the operating system command line, via a scheduled process, or via your operating system reboot facility.

### What's New

SAS-wsm 2.1.1 release:

* Merge audit-logging function contributed by Dustin Polk (PR #4)
* SAS-wsm project has been un-archived
* SAS-wsm was tested and validated to confirm operations on modern SAS 9.4 maintenace releases (latest version tested: SAS 9.4 Maintenance Release 9)
* Minor revisions to default startup order (improves startup automation of critical services in environments where some non-critical services may be unable to start)

### Prerequisites

* PowerShell - Must be able to run .ps1 PowerShell script

### Installation

Download script and store in a location where it can be accessed. No modifications are required to run the script in base configuration (full start/stop of SAS services in the environment). Simply run script as the SAS Installation User (user who owns SAS deployment files).

Refer to setup documentation for details on advanced configuration options.

### Running

Navigate to where the script is stored, then execute it.

Provide the following input parameters as shown:

.\SAS-wsm.ps1 -action \<start|stop|status\>

Additional input parameters are available for optional/extended functionality. Refer to setup documentation for details.

### Examples

* Start services: `.\SAS-wsm.ps1 -action start`

* Stop services: `.\SAS-wsm.ps1 -action stop`

* Check service status: `.\SAS-wsm.ps1 -action status`

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
