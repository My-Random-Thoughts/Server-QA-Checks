<#
    DESCRIPTION: 
        Check binding order is set correctly for "Production" as the primary network adapter then as applicable for other interfaces.
        If no "Production" adapter is found, then "Management" should be first.

    REQUIRED-INPUTS:
        ManagementAdapterNames - List of names or partial names of Management network adapters
        ProductionAdapterNames - List of names or partial names of Production network adapters

    DEFAULT-VALUES:
        ManagementAdapterNames = ('Management', 'MGMT', 'MGT')
        ProductionAdapterNames = ('Production', 'PROD', 'PRD')

    RESULTS:
        PASS:
            Binding order correctly set
        WARNING:
        FAIL:
            No network adapters found
            Production or management adapters not listed
            Binding order incorrect, {name} should be first
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-04-binding-order
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-04-binding-order'

    #... CHECK STARTS HERE ...#

    Try
    {
        # Get binding order GUIDs from reg key
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\Tcpip\Linkage')
        If ($regKey) { $keyVal = $regKey.GetValue('Bind') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [array]$bindingorder = $null
    If ([string]::IsNullOrEmpty($keyVal) -eq $false)
    {
        ForEach ($bind In $keyVal)
        {
            Try
            {
                [string]$deviceid = ($bind -split '\\')[2]
                If ($deviceid -notlike '{*}')
                {
                    $result.result  = $script:lang['Fail']
                    $result.message = 'No network adapters found'
                    $result.data    = ''
                    Return $result
                }

                Try
                {
                    [string]$query   = 'SELECT NetConnectionID FROM Win32_NetworkAdapter WHERE GUID="{0}"' -f $deviceid
                    [array] $adapter = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object -ExpandProperty NetConnectionID
                }
                Catch { }
            }
            Catch
            {
                $result.result  = $script:lang['Error']
                $result.message = $script:lang['Script-Error']
                $result.data    = $_.Exception.Message
                Return $result
            }

            If ([string]::IsNullOrEmpty($adapter) -eq $false)
            {
                $bindingorder +=            $adapter
                $result.data  += '{0},#' -f $adapter
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Registry setting not found'
        $result.data    = ''
        Return $result
    }

    [boolean]$prodExists = $false
    [boolean]$mgmtExists = $false

    If ($bindingorder -eq $null)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Production or Management adapters not listed'
        $result.data    = ''
        Return $result
    }

    # Check if 'Production' actually exists
    ForEach ($p In $script:appSettings['ProductionAdapterNames'])
    {
        # Check if firstmost binding is 'Production'
        If ($bindingorder[0] -like '{0}*' -f $p )
        {
            $prodExists     = $true
            $result.result  = $script:lang['Pass']
            $result.message = 'Binding order correctly set'
            Break
        }
        ElseIf ($bindingorder -like '*{0}*' -f $p)
        {
            $prodExists     = $true
            $result.result  = $script:lang['Fail']
            $result.message = 'Binding order incorrect, {0} should be first' -f $script:appSettings['ProductionAdapterNames'][0]
            Break
        }
        Else
        {
            $prodExists = $false
        }
    }

    If ($prodExists -eq $false)
    {
        # No 'Production', check for 'Management'
        ForEach ($m In $script:appSettings['ManagementAdapterNames'])
        {
            # Check if firstmost binding is 'Management'
            If ($bindingorder[0] -like '{0}*' -f $m)
            {
                $mgmtExists     = $true
                $result.result  = $script:lang['Pass']
                $result.message = 'Binding order correctly set'
                Break
            }
            ElseIf ($bindingorder -like '*{0}*' -f $m)
            {
                $mgmtExists     = $true
                $result.result  = $script:lang['Fail']
                $result.message = 'Binding order incorrect, {0} should be first' -f $script:appSettings['ManagementAdapterNames'][0]
                Break
            }
            Else
            {
                $mgmtExists = $false
            }
        }
    }

    If (($prodExists -eq $false) -and ($mgmtExists -eq $false))
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Production or Management adapters not listed'
    }
    
    Return $result
}
