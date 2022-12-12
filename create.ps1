#####################################################
# HelloID-Conn-Prov-Target-Procademy-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
$account = [PSCustomObject]@{
    users = @({
        email       = $p.Accounts.MicrosoftActiveDirectory.mail
        username    = $p.UserName
        first_name  = $p.Name.GivenName
        last_name   = $p.Name.FamilyName
        name        = $p.DisplayName
        external_id = $p.ExternalId

        # Optional properties
        group_ids = @()

        # User is only allowed to be deactivated when the user is created with the same channel as the channel given in the request
        channel_id = ''
    })
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
    # Add a warning message showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] 'create or update' Procademy account for: [$($p.DisplayName)], will be executed during enforcement"
    }

    # Process
    Write-Verbose 'Adding authentication header'
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($config.AuthenticationKey)")
    $headers.Add('Accept', 'application/json')

    Write-Verbose 'Creating (or updating) and correlating Procademy account'
    $splatRestParams = @{
        Uri     = "$($config.BaseUrl)/api/v2/users/store/bulk"
        Method  = 'POST'
        Headers = $Headers
        Body    = $account
    }
    $response = Invoke-RestMethod @splatRestParams -Verbose:$false

    # The documentation at this point differs from what we've heard from the Procademy developers.
    # The docs state that, the response when creating a user or users is a JSON payload containing a message.
    # The developers have informed us that the response is an array of objects where each object
    # contains the internal 'procademy_user_id' property. This is what's being used in the code.
    # Correlation is based on the 'procademy_user_id' instead of the 'externalId'.
    $accountReference = $response[0].procademy_user_id
    $success = $true
    $auditLogs.Add([PSCustomObject]@{
            Message = "Create (or update) account was successful. AccountReference is: [$accountReference]"
            IsError = $false
        })
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ProcademyError -ErrorObject $ex
        $auditMessage = "Could not create (or update) Procademy account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create (or update) Procademy account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
# End
} finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
