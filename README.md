# Server QA Checks

The QA Checks (aka scripts) came about as a need to verify the build of new servers into different environments.
All servers should be built from a standard gold build image; however this image still lacks many of the additional tools and configuration settings that are needed before a server can be taken in to support.

The scripts are written using the Microsoft PowerShell scripting language, with a minimum version of 2.
This is due to Windows Server 2008 R2 (the lowest supported operating system) having this version installed by default.

The scripts can be run on any Windows operating system as long as PowerShell version 2 is installed, and the PowerShell command window is run with administrative privileges.  The only officially supported operating systems however are listed below...

## Supported Operating Systems
- Windows Server 2008 R2
- Windows Server 2012
- Windows Server 2012 R2

### Also works, but not supported
- Windows 2003 Server
- Windows Server 2016 Technical Preview    (no known errors or issues so far)

─────────────────────────────────────────────────────────────────────────────

# Quick Start:
1. Open a PowerShell console with administrative privileges
2. Change to the correct folder for where the scripts are held
3. Enter "Set-ExecutionPolicy Unrestricted –Force" to enable the script to run
4. Enter either:    
     QA_(version).ps1 [-ComputerName] server01[, server02, server03, ...]
   or
     QA_(version).ps1 [-ComputerName] (Get-Content -Path c:\path\list.txt)
5. Wait for the script to comlplete
6. View the report(s) in the C:\QA\Results folder

─────────────────────────────────────────────────────────────────────────────

## Please read the documentation before starting out
