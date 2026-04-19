#!/usr/bin/env pwsh
# Changes the public/private visibility of a Docker Hub repository via the Docker Hub API.
# Usage:
#   .\set_dockerhub_visibility.ps1 -Namespace freistli -Repository docaihub -Visibility public
#   .\set_dockerhub_visibility.ps1 -Namespace freistli -Repository docaihub -Visibility private

param(
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "freistli",

    [Parameter(Mandatory = $false)]
    [string]$Repository = "docaihub",

    [Parameter(Mandatory = $true)]
    [ValidateSet("public", "private")]
    [string]$Visibility,

    [Parameter(Mandatory = $false)]
    [string]$Username = $env:DOCKERHUB_USERNAME,

    [Parameter(Mandatory = $false)]
    [string]$Password = $env:DOCKERHUB_PASSWORD
)

# Prompt for credentials if not provided via params or environment variables
if (-not $Username) {
    $Username = Read-Host "Docker Hub username"
}
if (-not $Password) {
    $securePassword = Read-Host "Docker Hub password or access token" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

# Step 1: Authenticate and retrieve a JWT token
$loginBody = @{ username = $Username; password = $Password } | ConvertTo-Json
try {
    $loginResponse = Invoke-RestMethod `
        -Uri "https://hub.docker.com/v2/users/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody
} catch {
    Write-Error "Authentication failed: $($_.Exception.Message)"
    exit 1
}

$token = $loginResponse.token
if (-not $token) {
    Write-Error "Failed to retrieve authentication token."
    exit 1
}

Write-Host "Authenticated successfully."

# Step 2: Patch the repository visibility
$isPrivate = ($Visibility -eq "private")
$patchBody = @{ is_private = $isPrivate } | ConvertTo-Json

$headers = @{ Authorization = "Bearer $token" }

try {
    $patchResponse = Invoke-RestMethod `
        -Uri "https://hub.docker.com/v2/repositories/$Namespace/$Repository/" `
        -Method PATCH `
        -ContentType "application/json" `
        -Headers $headers `
        -Body $patchBody
} catch {
    Write-Error "Failed to update visibility: $($_.Exception.Message)"
    exit 1
}

$currentVisibility = if ($patchResponse.is_private) { "private" } else { "public" }
Write-Host "Repository '$Namespace/$Repository' visibility is now: $currentVisibility"
