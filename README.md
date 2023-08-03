# SAS-wsm

## Overview

The SAS-wsm utility provides consistent management of SAS-related services for Windows deployments from a single script. Consistent management enables starting, stopping, status checking in a defined and consistent order. You can execute the script from the operating system command line, via a scheduled process, or via your operating system reboot facility.

### What's New

SAS-wsm 2.0 initial release:

* Default automatic configuration - environment-specific setup definition of start/stop services and control order no longer required
* Automatic SASConfig directory locator - uses properties of various Windows Services to determine SASConfig path. Manual override available.
* Partial service stack control - ability to stop a subset of services using a custom service configuration file. This feature also allows to retain legacy v.1.1 cfgfile compatibility.
* Environment-specific settings now fully externalized from base .ps1 script
* v.1.1 configfile validation functionality action removed (use status action to test a custom service configuration file)

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
