#Required modules - run these commands if you don't have these modules installed
#Install-Module -Name MicrosoftPowerBIMgmt  - needed
#----------------------------------------

# Get token and create header.  There are multiple methods of getting an Azure token for authentication.  This example is using Power BI cmdlets to retrieve the token.
Login-PowerBIServiceAccount
$token = Get-PowerBIAccessToken -AsString

# Building Rest API header with authorization token
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'= $token}

$groupID = "f4daf155-afd0-4385-b8b2-9040068226f4" # the ID of the group that hosts the dataset. Use "me" if this is your My Workspace
$datasetID = "af0c4552-e915-465b-b0ed-f7deb6eaafd3" # the ID of the dataset that hosts the dataset

# properly format groups path
$groupsPath = ""
if ($groupID -eq "me") {
    $groupsPath = "myorg"
} else {
    $groupsPath = "myorg/groups/$groupID"
}

# Refresh the dataset
$uri = "https://api.powerbi.com/v1.0/$groupsPath/datasets/$datasetID/refreshes"
Invoke-RestMethod -Uri $uri –Headers $authHeader –Method POST –Verbose