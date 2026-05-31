function Test-PendingWindowsFeature {
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'Wmi')]
        [Parameter(ParameterSetName = 'CimName')]
        [string]
        $ComputerName,

        [Parameter(ParameterSetName = 'Wmi', Mandatory)]
        [Switch]
        $Wmi,

        [Parameter(ParameterSetName = 'CimSession', Mandatory)]
        [CimSession]
        $CimSession,

        [Parameter(ParameterSetName = 'Wmi')]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $GetCallParameters = @{
        Namespace = 'ROOT/CIMV2'
        ClassName = 'Win32_OperatingSystem'
        Property  = 'WindowsDirectory'
    }
    $WindowsDirectoryWmiResult = if ($PSBoundParameters.ContainsKey('Wmi'))
    {
        $ComputerName = if ($PSBoundParameters.ContainsKey('ComputerName'))
        {
            $GetCallParameters.ComputerName
        }
        else
        {
            '.'
        }
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $GetCallParameters.Credential = $Credential
        }
        Get-WmiObject @GetCallParameters
    }
    else
    {
        if ($PSBoundParameters.ContainsKey('CimSession'))
        {
            $GetCallParameters.CimSession = $CimSession
        }
        else {
            if ($PSBoundParameters.ContainsKey('ComputerName') -and $ComputerName -notin ('.', 'localhost', $env:COMPUTERNAME))
            {
                $GetCallParameters.ComputerName = $ComputerName
            }
        }
        Get-CimInstance @GetCallParameters
    }
    $WindowsDirectoryPath = $WindowsDirectoryWmiResult.WindowsDirectory
    $PendindXMLFilePath = [System.IO.Path]::Combine($WindowsDirectoryPath, 'WinSxS\pending.xml')
    # https://github.com/DarwinJS/DevOpsAutomationCode/blob/master/CompactDevOpsRebootWindowsIfNeeded.ps1

    # https://gist.github.com/mattifestation/03079a38f23e0c94c8cd39779f88adf6
    # https://github.com/microsoft/Microsoft-Defender-for-Identity/blob/main/Test-MdiReadiness/Test-MdiReadiness.ps1#L226

    $PendindXMLFileFileContent = if ($PSBoundParameters.ContainsKey('Wmi'))
    {
        $PendindXMLFilePathFilter = $PendindXMLFilePath.Replace('\', '\\')
        $WMIPendindXMLFilePath = ('\\{0}\ROOT\Microsoft\Windows\Powershellv3:PS_ModuleFile.InstanceID="{1}"' -f $ComputerName, $PendindXMLFilePathFilter)
        $WMIPendindXMLFile = [System.Management.ManagementPath]::new($WMIPendindXMLFilePath)
        [System.Management.ManagementObject]::new($WMIPendindXMLFile).FileData
    }
    else
    {
        $PSModuleFileClass = Get-CimClass -Namespace 'ROOT/Microsoft/Windows/Powershellv3' -ClassName 'PS_ModuleFile'
        $InMemoryModuleFileInstance = New-CimInstance -CimClass $PSModuleFileClass -Property @{ InstanceID = $PendindXMLFilePath } -ClientOnly
        $GetCimInstanceParameters = @{
            InputObject = $InMemoryModuleFileInstance
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('CimSession'))
        {
            $GetCimInstanceParameters.CimSession = $CimSession
        }
        try
        {
            Get-CimInstance @GetCimInstanceParameters
        }
        catch
        {
            if ($_.CategoryInfo.Category -ne [System.Management.Automation.ErrorCategory]::ObjectNotFound)
            {
                throw $_
            }
        }
    }

    $Result = $false
    if ($PendindXMLFileFileContent)
    {
        $FileLengthBytes = $PendindXMLFileFileContent[0..3]
        [Array]::Reverse($FileLengthBytes)
        $FileLength = [BitConverter]::ToUInt32($FileLengthBytes, 0)
        $FileBytes = $PendindXMLFileFileContent[4..($FileLength - 1)]
        $PendindXMLFileFileString = ([System.Text.Encoding]::UTF8).GetString($FileBytes)
        if ($PendindXMLFileFileString | Select-String -Pattern 'postAction="reboot"' -Quiet)
        {
            $Result = $true
        }
    }
    $Result
}