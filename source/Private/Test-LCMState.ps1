function Test-LCMState {
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'ComputerName')]
        [string]
        $ComputerName,

        [Parameter(ParameterSetName = 'CimSession', Mandatory)]
        [CimSession]
        $CimSession
    )

    $GetDscLocalConfigurationManagerParameters = @{}
    $GetDscLocalConfigurationManagerParameters.CimSession = if ($CimSession)
    {
        $CimSession
    }
    else
    {
        if ($PSBoundParameters.ContainsKey('ComputerName') -and $ComputerName -notin ('.', 'localhost', $env:COMPUTERNAME))
        {
            New-CimSession -ComputerName $ComputerName
        }
        else
        {
            New-CimSession
        }
    }

    $LCMState = (Get-DscLocalConfigurationManager @GetDscLocalConfigurationManagerParameters).LCMstate
    $Result = $false
    if ($LCMState -eq 'PendingReboot')
    {
        $Result = $true
    }
    $Result
}