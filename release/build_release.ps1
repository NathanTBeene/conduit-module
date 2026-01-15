#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build release packages for Conduit
.DESCRIPTION
    Reads version info from dist.info and builds release packages with various optimization levels
.PARAMETER Clean
    Remove existing release directory before building
.EXAMPLE
    .\build_release.ps1 -Clean
#>

param(
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script directory and project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Change to project root (where squish is located)
Push-Location $projectRoot

try {
    # Read dist.info
    Write-Host "Reading dist.info..." -ForegroundColor Cyan
    $distInfo = Get-Content "dist.info" -Raw

    # Parse version
    if ($distInfo -match 'version\s*=\s*"([^"]+)"') {
        $version = $Matches[1]
    } else {
        throw "Could not find version in dist.info"
    }

    # Parse name
    if ($distInfo -match 'name\s*=\s*"([^"]+)"') {
        $name = $Matches[1]
    } else {
        throw "Could not find name in dist.info"
    }

    Write-Host "Building $name version $version" -ForegroundColor Green

    # Create dist directory inside release folder
    $distDir = Join-Path $scriptDir "dist"
    if ($Clean -and (Test-Path $distDir)) {
        Write-Host "Cleaning dist directory..." -ForegroundColor Yellow
        Remove-Item $distDir -Recurse -Force
    }

    if (-not (Test-Path $distDir)) {
        New-Item -ItemType Directory -Path $distDir | Out-Null
    }

    # Build variants
    $variants = @(
        @{output="conduit.lua"; args=@(); desc="standard"; suffix=""},
        @{output="conduit.min.lua"; args=@("--minify", "-minify-level=full"); desc="minified"; suffix="-min"},
        @{output="conduit.ugl.lua"; args=@("--uglify", "-uglify-level=full"); desc="uglified"; suffix="-ugl"},
        @{output="conduit.min.ugl.lua"; args=@("--minify", "-minify-level=full", "--uglify", "-uglify-level=full"); desc="minified + uglified"; suffix="-min-ugl"}
    )

    # Additional files to include in each package
    $additionalFiles = @("README.md", "LICENSE", "dist.info")

    foreach ($variant in $variants) {
        $outputFile = $variant.output
        $variantArgs = $variant.args
        $desc = $variant.desc
        $suffix = $variant.suffix

        Write-Host "`nBuilding $outputFile ($desc)..." -ForegroundColor Cyan

        # Build squish command
        $squishArgs = @("squish", "--output=`"$outputFile`"") + $variantArgs
        $squishCmd = "lua " + ($squishArgs -join " ")

        Write-Host "  Running: $squishCmd" -ForegroundColor Gray
        Invoke-Expression $squishCmd

        if (-not (Test-Path $outputFile)) {
            Write-Host "  Warning: $outputFile was not created" -ForegroundColor Yellow
            continue
        }

        # Fix require paths for standalone module
        Write-Host "  Fixing require paths..." -ForegroundColor Gray
        $content = Get-Content $outputFile -Raw
        $content = $content -replace 'require\s*\(\s*"conduit\.server"\s*\)', 'require("server")'
        $content = $content -replace 'require\s*\(\s*"conduit\.templates"\s*\)', 'require("templates")'
        $content = $content -replace 'require\s*\(\s*"conduit\.console"\s*\)', 'require("console")'
        Set-Content $outputFile -Value $content -NoNewline

        # Create package for this variant
        $packageName = "$($name.ToLower())-$version$suffix"
        $packageDir = Join-Path $distDir $packageName

        if (Test-Path $packageDir) {
            Remove-Item $packageDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $packageDir | Out-Null

        # Copy built file
        Copy-Item $outputFile -Destination $packageDir

        # Copy additional files if they exist
        foreach ($file in $additionalFiles) {
            if (Test-Path $file) {
                Copy-Item $file -Destination $packageDir
            }
        }

        # Create archive
        $archiveName = "$packageName.zip"
        $archivePath = Join-Path $distDir $archiveName
        Write-Host "  Creating archive $archiveName..." -ForegroundColor Gray
        Compress-Archive -Path "$packageDir\*" -DestinationPath $archivePath -Force

        # Clean up package directory and built file
        Remove-Item $packageDir -Recurse -Force
        Remove-Item $outputFile -Force

        Write-Host "  Created $archiveName" -ForegroundColor Green
    }

    Write-Host "`nBuild complete!" -ForegroundColor Green
    Write-Host "`nPackages created:" -ForegroundColor Cyan
    Get-ChildItem $distDir -Filter "*.zip" | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }

} finally {
    Pop-Location
}
