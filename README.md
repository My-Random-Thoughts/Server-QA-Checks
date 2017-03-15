# Runspaces Proof Of Concept
I have included a separate compiler to build a POC check that uses Runspace Pools instead of Jobs to run each check.  Runspaces have the advantage of being extremely fast compared to Jobs.  A full scan drops from about 60 seconds to just 12.   However, it does not fully work correctly against remote servers, only locally checked ones.  Improvements will come, but slowly.!  



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

# QA Settings Configurator

This is a GUI form (written entirely in PowerShell) that makes it easier for you to enable/disable specific checks as well as configure the specific settings for each QA check.

http://myrandomthoughts.co.uk/2017/02/server-qa-scripts-settings-configuration-tool/
