# Deploy Privacy / Terms to Firebase Hosting (run in YOUR terminal).
# Usage from project root:
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy_hosting.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Project folder: $(Get-Location)" -ForegroundColor Cyan

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host "Installing firebase-tools..." -ForegroundColor Yellow
  npm install -g firebase-tools
}

Write-Host ""
Write-Host "Step 1/2: Browser login will open. Use the Google account that owns TapDodge." -ForegroundColor Yellow
Write-Host "If asked about Gemini in Firebase, type n and press Enter." -ForegroundColor Yellow
firebase login --reauth

Write-Host ""
Write-Host "Step 2/2: Deploying Hosting..." -ForegroundColor Yellow
firebase use tapdodge-294f4
firebase deploy --only hosting

Write-Host ""
Write-Host "Done. Verify these links:" -ForegroundColor Green
Write-Host "  Privacy: https://tapdodge-294f4.web.app/privacy/"
Write-Host "  Terms:   https://tapdodge-294f4.web.app/terms/"
Write-Host "  Home:    https://tapdodge-294f4.web.app/"
