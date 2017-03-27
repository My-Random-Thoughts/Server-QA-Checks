<#
    DESCRIPTION: 
        Checks to see if the default webpage is present in IIS, it should be removed.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            IIS Installed, "iisstart.htm" not listed in default documents
        WARNING:
        FAIL:
            IIS Installed, default document "iisstart.htm" configured
        MANUAL:
        NA:
            IIS not Installed

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-sec-11-iis-default-page
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-11-iis-default-page'

    #... CHECK STARTS HERE ...#

    Try
    {
        If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\MicrosoftIISv2') -eq $true)
        {
            # IISv6
            [string]$query  = "SELECT DefaultDoc FROM IISWebServerSetting"
            [string]$chktmp = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\MicrosoftIISv2 | Select-Object -ExpandProperty DefaultDoc
            If ($chktmp -ne $null) { $check = $chktmp.Replace(',', ', ') }
        }
        ElseIf ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\WebAdministration') -eq $true)
        {
            # IISv7
            [string]$query  = "SELECT Files FROM DefaultDocumentSection"
            [array] $chktmp = (Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\WebAdministration).Files.Files | Select-Object -ExpandProperty Value
            If ($chktmp -ne $null) { [string]$check = [string]::Join(', ', $chktmp) }
        }
        Else
        {
            [string]$check = $null    # IIS not installed
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = 'SCRIPT ERROR 1'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($check) -eq $true)
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'IIS not Installed'
        $result.data    = ''
    }
    Else
    {
        $result.message = 'IIS Installed, '
        If ($check -like '*iisstart.htm*')
        {
            $result.result   = $script:lang['Fail']
            $result.message += 'default document "iisstart.htm" configured'
            $result.data     = '' + $check
        }
        Else
        {
            $result.result   = $script:lang['Pass']
            $result.message += '"iisstart.htm" not listed in default documents'
            $result.data     = '' + $check
        }
    }

    Return $result
}