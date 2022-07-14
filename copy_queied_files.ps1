$ResourceGroup = 'InterlakeFunctions'
$StorageAccountName = 'interlake2'
$QueueName = 'syncfilesqueue'
$RunLocal = $false
$connection = $null
$destconnection = $null
$cred = $null

$startTime = Get-Date

# =============================================================================
# Get credential
# =============================================================================
if ($RunLocal) {
    $VerbosePreference = "Continue"
    if ($null -eq $cred) {
        $cred = Get-Credential -UserName "svcO365sync@interlake-steamship.com" -Message "Enter password"
    }
}
else {
    Write-Verbose "Getting AutomationPSCredential..."
    $cred = Get-AutomationPSCredential -Name 'SyncServiceAccount'
}

# =============================================================================
# Connect to Azure and SharePoint
# =============================================================================
try {
    # Connect to SharePoint
    Write-Verbose "Connecting to SharePoint Online with Username: $($cred.UserName)..."
    $connection = Connect-PnPOnline -Url "https://interlakesteamship.sharepoint.com" -Credentials $cred -ReturnConnection
}
catch {
    Write-Error "Error connecting to SharePoint Online: $($_.Exception.Message)"
    return
}
try {
    # Connect to the Azure Storage account
    if ($RunLocal) {
        Write-Verbose "Connecting to Azure with Username: $($cred.UserName)..."
        $azConnect = Connect-AzAccount -Subscription '8c397b3e-fc4a-4440-8d82-bf1e76203377' -Credential $cred 
    }
    else {
        Write-Verbose "Connecting to Azure using managed identity..."
        $azConnect = Connect-AzAccount -Identity 
    }

    # Getting Azure Storage Account.
    Write-Verbose "Getting Azure Storage Account..."
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
    $ctx = $storageAccount.Context
    $queue = Get-AzStorageQueue -Context $ctx -Name $QueueName
}
catch {
    Write-Error "Error connecting to Azure Storage Account: $($_.Exception.Message)"
    return
}

# =============================================================================
# Process the queue
# =============================================================================
$messagesProcessed = 0
$filesCopied = 0
# Set the amount of time you want to entry to be invisible after read from the queue
# If it is not deleted by the end of this time, it will show up in the queue again
$invisibleTimeout = [System.TimeSpan]::FromMinutes(30)
# Set the number of messages to get.
$messagesToFetch = 20

# Read a batch of messages from the queue.
$queueMessages = $queue.CloudQueue.GetMessages($messagesToFetch, $invisibleTimeout, $null, $null)
Write-Output "Messages fetched from the queue: $($queueMessages.Count)"

while ($queueMessages.Count -gt 0) {
    foreach ($msg in $queueMessages) {
        $messagesProcessed += 1
        Write-Verbose "Processing message: $($msg.AsString)"
        # Parse the message
        try {
            $item = ConvertFrom-Json $msg.AsString
        }
        catch {
            Write-Error "Error parsing message. Message ID: $($msg.Id) Exception: $($_.Exception.Message)"
            $null = $queue.CloudQueue.DeleteMessageAsync($msg.Id, $msg.popReceipt)
            continue
        }

        Write-Output $"Source document: $($item.SourceDoc) - Destination document: $($item.DestinationDoc)"

        # Get the destination folder path from the destination document Url.
        $targetFolder = Split-Path -Path $($item.DestinationDoc)
        $targetFolder = $targetFolder.Replace('\', '/')

        # Copy the file
        try {
            Write-Verbose "Connecting to destination site: $($item.DestinationSite)"
            $destConnection = Connect-PnPOnline $($item.DestinationSite) -Credentials $cred -ReturnConnection
            # Make sure the destination folder path exists before we copy the file.
            Write-Verbose "Resolving destination folder: $($item.Folder)"
            $null = Resolve-PnPFolder -SiteRelativePath $($item.Folder) -Connection $destConnection
            # Copy the file.
            Copy-PnPFile -SourceUrl $($item.SourceDoc) -TargetUrl $targetFolder -Overwrite -IgnoreVersionHistory -Force -Connection $connection -ErrorAction Stop
            $filesCopied += 1
        }
        catch {
            Write-Error "Error copying file. Message ID: $($msg.Id) Exception: $($_.Exception.Message)"
        }
        finally {
            Write-Verbose "Delete the message from the queue: $($msg.Id)"
            $null = $queue.CloudQueue.DeleteMessageAsync($msg.Id, $msg.popReceipt)
        }

        # Update the metadata
        # NOTE: Metadata is copied with documents if destination library has same columns.

        # Set file permissions
        # NOTE: We no longer set permissions on a single document but rely on the permissions of the ship library to control "read-only".
        
        # Delete the message from the queue

    }

    # Get the next batch of messages
    $queueMessages = $queue.CloudQueue.GetMessages($messagesToFetch, $invisibleTimeout, $null, $null)
    Write-Output "Messages fetched from the queue: $($queueMessages.Count)"
}

# =============================================================================
# Output run info
# =============================================================================
$endTime = Get-Date
$ts = New-TimeSpan -Start $startTime -End $endTime
Write-Output "Messages processed: $messagesProcessed"
Write-Output "Files copied: $filesCopied"
Write-Output "Runtime: $($ts.Hours):$($ts.Minutes):$($ts.Seconds).$($ts.Milliseconds)"  
