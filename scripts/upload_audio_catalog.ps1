param(
    [string]$StagePath = 'Audio Assets\Derived Staging\2026-08-17',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$projectURL = $env:SPC_SUPABASE_URL
$serviceRoleKey = $env:SPC_SUPABASE_SERVICE_ROLE_KEY
if (-not $DryRun -and ([string]::IsNullOrWhiteSpace($projectURL) -or
    [string]::IsNullOrWhiteSpace($serviceRoleKey))) {
    throw 'Set SPC_SUPABASE_URL and SPC_SUPABASE_SERVICE_ROLE_KEY in the process environment. Never commit or print the service-role key.'
}

$projectURL = if ($DryRun) { 'https://dry-run.invalid' } else { $projectURL.TrimEnd('/') }
$stage = (Resolve-Path -LiteralPath $StagePath).Path
$deliveryManifestPath = Join-Path $stage 'delivery_manifest.json'
$deliveryManifest = Get-Content -Raw -LiteralPath $deliveryManifestPath | ConvertFrom-Json

$uploads = @(
    @{ record = 'quick-unwind'; path = 'catalog/quick-unwind/v1/full.m4a' },
    @{ record = 'quick-unwind-preview'; path = 'previews/quick-unwind/v1/preview.m4a' },
    @{ record = 'second-sleep'; path = 'catalog/second-sleep/v1/full.m4a' },
    @{ record = 'second-sleep-preview'; path = 'previews/second-sleep/v1/preview.m4a' },
    @{ record = 'slow-unwind'; path = 'catalog/slow-unwind/v1/full.m4a' },
    @{ record = 'slow-unwind-preview'; path = 'previews/slow-unwind/v1/preview.m4a' },
    @{ record = 'morning-stillness'; path = 'system-sounds/morning-stillness/v1/full.caf'; mime = 'audio/x-caf' },
    @{ record = 'morning-stillness-catalog-preview'; path = 'previews/morning-stillness/v1/preview.m4a'; mime = 'audio/mp4' },
    @{ record = 'morning-echoes'; path = 'system-sounds/morning-echoes/v1/full.caf'; mime = 'audio/x-caf' },
    @{ record = 'morning-echoes-catalog-preview'; path = 'previews/morning-echoes/v1/preview.m4a'; mime = 'audio/mp4' },
    @{ record = 'stone-echoes'; path = 'system-sounds/stone-echoes/v1/full.caf'; mime = 'audio/x-caf' },
    @{ record = 'stone-echoes-catalog-preview'; path = 'previews/stone-echoes/v1/preview.m4a'; mime = 'audio/mp4' },
    @{ record = 'morning-meadow-radiance'; path = 'system-sounds/morning-meadow-radiance/v1/full.caf'; mime = 'audio/x-caf' },
    @{ record = 'morning-meadow-radiance-catalog-preview'; path = 'previews/morning-meadow-radiance/v1/preview.m4a'; mime = 'audio/mp4' }
)

function Get-GeneratedRecord([string]$id) {
    $record = @($deliveryManifest.generated_files | Where-Object { $_.id -eq $id }) | Select-Object -First 1
    if ($null -eq $record) {
        throw "No generated delivery record exists for $id."
    }
    return $record
}

function Encode-StoragePath([string]$path) {
    return (($path -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

$headers = @{
    apikey = $serviceRoleKey
    Authorization = "Bearer $serviceRoleKey"
    'x-upsert' = 'true'
    'cache-control' = 'public, max-age=31536000, immutable'
}

$uploaded = 0
foreach ($upload in $uploads) {
    $record = Get-GeneratedRecord $upload.record
    if ($record.verification_pass -ne $true) {
        throw "Refusing to upload an unverified delivery: $($upload.record)."
    }

    $relativePath = [string]$record.relative_path
    $stageRelativePath = $relativePath -replace '^Audio Assets/Derived Staging/[^/]+/', ''
    $filePath = Join-Path $stage $stageRelativePath.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Generated delivery is missing: $filePath"
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $filePath).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$record.sha256).ToLowerInvariant()) {
        throw "SHA-256 mismatch for $filePath."
    }

    if ($DryRun) {
        Write-Output "Validated $($upload.path) ($($record.size_bytes) bytes; $actualHash)"
        continue
    }

    $encodedPath = Encode-StoragePath $upload.path
    $uri = "$projectURL/storage/v1/object/audio-catalog/$encodedPath"
    $contentType = if ($upload.mime) { $upload.mime } else { 'audio/mp4' }
    Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -ContentType $contentType -InFile $filePath -UseBasicParsing | Out-Null
    $uploaded++
    Write-Output "Uploaded $($upload.path) ($($record.size_bytes) bytes; $actualHash)"
}

Write-Output "Uploaded $uploaded verified audio catalog objects to the private audio-catalog bucket."
