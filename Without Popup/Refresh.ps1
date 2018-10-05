#Login-AzureRmAccount
#Save-AzureRmContext -Path "AzureProfile.json"
#Save-AzureRmContext -Path "AzureProfile.json"
Import-AzureRmContext -Path "AzureProfile.json"

$groupID = "6cd823c6-6686-4375-a219-b1319b866d28" # the ID of the group that hosts the dataset. Use "me" if this is your My Workspace
$datasetID = "f41a11c2-1be8-497a-a909-0c2642322f04" # the ID of the dataset that hosts the dataset

#https://app.powerbi.com/groups/6cd823c6-6686-4375-a219-b1319b866d28/settings/datasets/f41a11c2-1be8-497a-a909-0c2642322f04
#AthenaQA Int Area Director > Base Product Trend report
#PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& 'C:\Powershell\Refresh.ps1'"
#.\Refresh.ps1

# AAD Client ID
# To get this, go to the following page and follow the steps to provision an app
# https://dev.powerbi.com/apps
# To get the sample to work, ensure that you have the following fields:
# App Type: Native app
# Redirect URL: https://login.microsoftonline.com/{contoso.onmicrosoft.com}/oauth2
#  Level of access: all dataset APIs
$clientId = "b17f24fb-8f4f-4224-9c6a-6329eb56b9e8" 

function GetAuthToken
{
    $adal = "${envrogramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
 
    $adalforms = "${envrogramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
 
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
 
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
 
    $redirectUri = "https://login.live.com/oauth20_desktop.srf"
 
    $resourceAppIdURI = "https://analysis.windows.net/powerbi/api"
 
    $authority = "https://login.windows.net/common/oauth2/authorize";
       
    $userName = "brendan.hines@stryker.com"

    $password = "#Br12hi35#"

    $creds = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential" -ArgumentList $userName,$password
 
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $creds)
   

    return $authResult

}


# Get the auth token from AAD
$token = GetAuthToken

# Building Rest API header with authorization token
$authHeader = @{
   'Content-Type'='application/json'
   'Authorization'=$token.CreateAuthorizationHeader()
}

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