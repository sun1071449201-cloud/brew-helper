# Fetch CI run step conclusions + failure log excerpt
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tool\ci_debug.ps1 -RunId <id>
param([Parameter(Mandatory = $true)][string]$RunId)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$token = (Get-Content (Join-Path $root 'tool\github_token.txt') -Raw).Trim()
$headers = @{
  'Authorization'        = "Bearer $token"
  'Accept'               = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent'           = 'brew-helper-uploader'
}
$api = 'https://api.github.com'
$owner = 'sun1071449201-cloud'
$repoName = 'brew-helper'

$jobsResp = Invoke-RestMethod -Headers $headers -Uri "$api/repos/$owner/$repoName/actions/runs/$RunId/jobs"
foreach ($j in $jobsResp.jobs) {
  Write-Host "JOB: $($j.name) -> $($j.conclusion)"
  foreach ($s in $j.steps) {
    Write-Host ("  step: {0} = {1}" -f $s.name, $s.conclusion)
  }
}

$failedJob = $jobsResp.jobs | Where-Object { $_.conclusion -eq 'failure' } | Select-Object -First 1
if (-not $failedJob) { Write-Host 'No failed job found.'; exit 0 }

$logFile = Join-Path $root 'tool\build_log.txt'
Invoke-WebRequest -Headers $headers -Uri "$api/repos/$owner/$repoName/actions/jobs/$($failedJob.id)/logs" -OutFile $logFile
Write-Host "---- error lines from $logFile ----"
Select-String -Path $logFile -Pattern 'error - |Error:|FAILED|EXCEPTION|Exception|failed|Build failed' |
  Select-Object -First 40 | ForEach-Object { Write-Host $_.Line }
