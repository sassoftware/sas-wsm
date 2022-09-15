# SAS-wsm

## Overview

The SAS-wsm utility provides consistent management of SAS-related services for Windows deployments from a single script. Consistent management enables starting, stopping, status checking in a defined and consistent order. You can execute the script from the operating system command line, via a scheduled process, or via your operating system reboot facility.

### What's New

SAS-wsm 1.1 initial release:

* Change to external configuration file for service definitions
* Provide new setup validation functions via 'search' and 'validate' actions
* Updates to improve status action reporting output
* Move default WebAppServer messaging to expectations from newer hotfix levels

### Prerequisites

* PowerShell - Must be able to run .ps1 PowerShell script

### Installation

Download script and store in a location where it can be accessed. Modify the user-variables section at the top of the script to set the correct SAS Configuration Directory path for your environment. Create a configuration file defining the SAS services you wish to control.

Detailed setup documentation is provided in the file **SAS-wsmConfigurationGuide.pdf**.

### Running

Navigate to where the script is stored, then execute it.

Provide the following inputs as shown:

.\SAS-wsm.ps1 -action \<start|stop|status|search|validate\> -cfg \<configuration-file-path\>


### Examples

* Start services: `.\SAS-wsm.ps1 -action start -cfg example-servers.cfg`

* Stop services: `.\SAS-wsm.ps1 -action stop -cfg example-servers.cfg`

* Check service status: `.\SAS-wsm.ps1 -action status -cfg example-servers.cfg`

More examples are provided in the file **SAS-wsmConfigurationGuide.pdf**.

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
