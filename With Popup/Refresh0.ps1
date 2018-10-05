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

$groupID = "99835bb0-e22c-4594-9422-4875ef325dfb" # the ID of the group that hosts the dataset. Use "me" if this is your My Workspace
$datasetID = "3f43d1ad-9ea1-4fdb-ba81-c97233168831" # the ID of the dataset that hosts the dataset

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