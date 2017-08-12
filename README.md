### Change Log At The End

# Server QA Checks

The QA Checks came about as a need to verify the build and configuration of any servers in several different environments.
All servers should be built from a standard gold build image; however this image still lacks many of the additional tools and configuration settings that are needed before a server can be taken in to support.

The manual process takes over 2 hours to complete, per server.  These scripts are completed in about 60 seconds.

They have been written using the Microsoft PowerShell scripting language, with a minimum supported version of 2.  This is due to Windows Server 2008 R2 (the lowest supported operating system) having this version installed by default.

The scripts can be run on any Windows operating system, either locally or remotely, as long as PowerShell version 2 or greater is installed, and the PowerShell command window is run with administrative privileges.  The only officially supported operating systems however are listed below...

### Supported Operating Systems
- Windows Server 2008 R2
- Windows Server 2012
- Windows Server 2012 R2
- Windows Server 2016

#### Also works, but not supported
- Windows 2003 Server

## Please read the documentation and Wiki before starting out

─────────────────────────────────────────────────────────────────────────────

# Quick Start:
1. Open a PowerShell console with administrative privileges
2. Change to the correct folder for where the scripts are held
3. Enter "Set-ExecutionPolicy Unrestricted –Force" to enable the script to run
4. Enter either:    
   - QA_(version).ps1 [-ComputerName] server01[, server02, server03, ...]
   - QA_(version).ps1 [-ComputerName] (Get-Content -Path c:\path\list.txt)
5. Wait for the script to complete
6. View the report(s) in the C:\QA\Results folder

─────────────────────────────────────────────────────────────────────────────

# Script Configuration For Your Specific Environment
To customise the configuration settings for your environment, use the **QA Settings Configuration Tool**.  This is a GUI form (written entirely in PowerShell) that makes it easier for you to enable/disable specific checks as well as configure the specific settings for each QA check.

More details can be found on the project wiki: https://github.com/My-Random-Thoughts/Server-QA-Checks/wiki/QA-Settings-Configuration-Tool


─────────────────────────────────────────────────────────────────────────────

# Basic Change Log

2017/08/12
- Lots of minor changes to files
- Larger changes to:

-- COM-12 - Added more default exclusions

-- DRV-05 - Now shows the location of any shared folders

-- NET-06 - Added check for 2012+ servers not needing native drivers

-- SYS-07 - Now showing any disabled devices

-- SYS-09 - Changed task author to show RunAs account

- Changed NET-09 to have a switch option of "AllMustExist".  This will allow you to have a range or static routes where only one or two may apply to a particular server.  Will still fail if none of them match.  Please add to your settings INI files the following line under the `[NET09]` section: `AllMustExist = 'False'`

2017/07/18
- New report layout and style.  I have created a new report style that I think looks much better than the old one.  Example reports are located in the root on this project.  Let me know what you think.  This report will hopefully become the new normal by the end of August 2017.  You can start using it by compiling your scripts with the `CompilerR2.ps1` script.

- Current Report : https://myrandomthoughts.co.uk/wp-content/uploads/2017/07/report-example-original.html
- New Report :     https://myrandomthoughts.co.uk/wp-content/uploads/2017/07/report-example-new.html

2017/07/05
- New Checks
- NET-13 - Check all adapters for NetBIOS Over TCP/IP settings
- SYS-22 - Check that all RAM is visable and usable to the OS

2017/07/04
- Update to the GUI configurator.  Never miss an update again with this update the settings screen will always show all the settings.  Any that may be missing from your INI file will be given the default script settings.  When saved, the INI file will have all the correct entries.

2017/07/01
- New Checks
- COM-10 - Software Installed - Checks to see if a list of products are installed
- COM-11 - Services Installed - Checks to see if a list of services are installed and running
 
2017/06/30
- SYS-08 - Custom Event Log - Similar to SYS-05/06, but allows you to enter a list of extra eventlogs to check
- SYS-21 - Gold Image - Checks up to three registry keys for gold image detection
- VMW-08 - Failover Clustering - Checks to see if clustering is installed on a VM
    
- Changed Checks
- HVH-02 - No Other Server Roles - Added method for 2012+ servers
- NET-06 - Network Agent - Added new dection method
- NET-09 - Static Routes - Fixed detection method
- NET-11 - DNS Settings - Fixed entire script.!
- SYS-05 - System Event Log - Added new options to check log size and rotation type.  Please make sure you update your settings.ini file for the new settings
- SYS-06 - Application Event Log - Added new options to check log size and rotation type.  Please make sure you update your settings.ini file for the new settings

2017/06/27
- Added functionality to allow checkbox and dropdown list options to have descriptions for each item.  An example of this is SEC-09 and SEC-15.
- Changed the default setting of SYS-04, as it's now covered by SYS-19
- Added new option to DRV-03 to allow you to specify page file location - Please make sure you update your INI settings.

Older
- Updated NET-01 check so that it now takes an option.  IPv6State = 'Enabled|Disabled'.  Will check to see if IPv6 is enalbed or disabled for the server being tested.  Please manually update your INI settings with the new entry.  default-settings.ini has the correct entry.
- New check: SEC-17 - Check SMBv1 Is Disabled
- New check: SEC-19 - Check HP SMH Version
- New check: SEC-20 - Check Dell OMA Version
- DRV-09 - New option to ignore unknown drive types

