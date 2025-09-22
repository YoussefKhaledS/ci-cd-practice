<#
.SYNOPSIS
This PowerShell script deploys a Node.js application to Azure App Service.

.DESCRIPTION
The script performs the following actions:
1.  Prompts for necessary parameters if they are not provided.
2.  Checks for an active Azure login session.
3.  Creates an Azure Resource Group if it doesn't exist.
4.  Creates an Azure App Service Plan.
5.  Creates a Web App with a specified Node.js runtime.
6.  Compresses the local application source code into a zip file.
7.  Deploys the zip file to the created App Service.
8.  Cleans up the local zip file after deployment.
9.  Outputs the URL of the deployed application.

.PARAMETER resourceGroupName
The name of the Azure Resource Group.

.PARAMETER appName
The unique name for the Azure App Service. A random string will be appended if not unique.

.PARAMETER location
The Azure region where the resources will be created (e.g., 'EastUS', 'WestEurope').

.PARAMETER appPath
The local file path to your Node.js application's root directory.

.EXAMPLE
.\deploy-nodejs-app.ps1 -resourceGroupName "MyNodeAppRG" -appName "my-unique-node-app-123" -location "EastUS" -appPath "C:\path\to\my\app"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$appName,

    [Parameter(Mandatory=$true)]
    [string]$location,

    [Parameter(Mandatory=$true)]
    [string]$appPath
)

# --- 1. PRE-DEPLOYMENT CHECKS ---

# Check if the user is logged into Azure
try {
    Write-Host "Checking Azure login status..."
    $azContext = Get-AzContext
    Write-Host "Successfully logged in as $($azContext.Account.Id) to tenant $($azContext.Tenant.Id)." -ForegroundColor Green
}
catch {
    Write-Error "You are not logged in to Azure. Please run 'Connect-AzAccount' and try again."
    return
}

# Check if the application path exists
if (-not (Test-Path -Path $appPath -PathType Container)) {
    Write-Error "The specified application path '$appPath' does not exist or is not a directory."
    return
}

# --- 2. DEFINE VARIABLES ---

$appServicePlanName = "$($appName)-plan"
$sku = "F1" # Basic tier. Use "F1" for Free, "S1" for Standard, etc.
$nodeVersion = "18-lts" # Specify the Node.js runtime version

# Append a random string to the app name to increase chances of uniqueness
$randomString = -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
$appName = "$($appName)-$($randomString)".ToLower()

# --- 3. CREATE AZURE RESOURCES ---

# Create Resource Group
try {
    Write-Host "Checking for Resource Group '$resourceGroupName' in location '$location'..."
    Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop | Out-Null
    Write-Host "Resource Group '$resourceGroupName' already exists." -ForegroundColor Yellow
}
catch {
    Write-Host "Creating Resource Group '$resourceGroupName'..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Host "Resource Group created successfully." -ForegroundColor Green
}

# Create App Service Plan
Write-Host "Creating App Service Plan '$appServicePlanName' with SKU '$sku'..."
New-AzAppServicePlan -Name $appServicePlanName -ResourceGroupName $resourceGroupName -Location $location -Tier $sku

# Create Web App (App Service)
Write-Host "Creating Web App '$appName' with Node version '$nodeVersion'..."
$webApp = New-AzWebApp -Name $appName -ResourceGroupName $resourceGroupName -Location $location -Plan $appServicePlanName -Runtime "NODE|$($nodeVersion)"

# --- 4. PREPARE AND DEPLOY APPLICATION ---

# Path for the temporary zip file
$zipFileName = "$($appName)-deployment.zip"
$zipFilePath = Join-Path -Path $env:TEMP -ChildPath $zipFileName

# Remove old zip file if it exists
if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath
}

Write-Host "Compressing application files from '$appPath'..."
Compress-Archive -Path "$($appPath)\*" -DestinationPath $zipFilePath -Force

Write-Host "Deploying '$zipFilePath' to Web App '$appName'..."
Publish-AzWebApp -WebApp $webApp -ResourceGroupName $resourceGroupName -Slot "production" -Type Zip -SourcePath $zipFilePath

# --- 5. CLEANUP AND OUTPUT ---

Write-Host "Cleaning up temporary file '$zipFilePath'..."
Remove-Item $zipFilePath

$appUrl = "https://$($webApp.DefaultHostName)"
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Your application is available at: $appUrl" -ForegroundColor Green
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
