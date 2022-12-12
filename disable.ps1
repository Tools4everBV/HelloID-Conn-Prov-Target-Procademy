#####################################################
# HelloID-Conn-Prov-Target-Procademy-Disable
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
# Note that the users array at this point is unclear what kind of string[] must be send to the 'deactivate' endpoint.
# The assumption is that its the internal Procademy user_id but could also be the 'externalId'.
$account = [PSCustomObject]@{
    users = @({procademy_user_id = $aRef})

    # User is only allowed to be deactivated when the user is created with the same channel as the channel given in the request
    channel_id = ''
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Resolve-ProcademyError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = ''
            FriendlyMessage  = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -eq $ErrorObject.Exception.Response) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
                $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message
            }
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            $httpErrorObj.ErrorDetails = $streamReaderResponse
        }
        Write-Output $httpErrorObj
    }
}
#endregion

# Begin
try {
    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] Disable Procademy account for: [$($p.DisplayName)] will be executed during enforcement"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        Write-Verbose 'Adding authentication header'
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Authorization', "Bearer $($config.AuthenticationKey)")
        $headers.Add('Accept', 'application/json')

        Write-Verbose 'Disabling Procademy account'
        $splatRestParams = @{
            Uri     = "$($config.BaseUrl)/api/v2/users/deactivate"
            Method  = 'POST'
            Headers = $Headers
            Body    = @($account)
        }
        $null = Invoke-RestMethod @splatRestParams -Verbose:$false
        $success = $true
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ProcademyError -ErrorObject $ex
        $auditMessage = "Could not disable Procademy account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not disable Procademy account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
# End
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
