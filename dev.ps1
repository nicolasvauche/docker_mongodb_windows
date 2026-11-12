param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'start', 'stop', 'status', 'logs', 'shell', 'run', 'check', 'pull', 'backup', 'restore')]
    [string]$Action = 'start',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Docker {
    param([string[]]$DockerArgs)
    & docker @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw "Docker a echoue (code $LASTEXITCODE)." }
}
function Assert-DatabaseName([string]$Name) {
    if ($Name -notmatch '^[a-z][a-z0-9_]{0,62}$' -or $Name -in @('admin', 'config', 'local')) {
        throw 'Base : 1 a 63 caracteres minuscules, chiffres ou underscores, commencant par une lettre ; admin, config et local sont reserves.'
    }
}
function Invoke-MongoFile([string]$File) {
    Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'mongosh', '--quiet', '--nodb', '--file', '/opt/mongodb-tools/connect.js', '--file', $File)
}

Push-Location $PSScriptRoot
try {
    $expectedArgs = 0
    if ($Action -eq 'run') { $expectedArgs = 1 }
    if ($Action -eq 'restore') { $expectedArgs = 2 }
    if ($CommandArgs.Count -ne $expectedArgs) {
        throw 'Utilisation : ./dev.ps1 action ; run fichier.js ; restore backups/fichier.archive.gz nouvelle_base'
    }
    if ($Action -eq 'init') {
        if (Test-Path -LiteralPath .env) {
            Write-Host '.env existe deja : conserve sans modification.'
        } else {
            $bytes = New-Object byte[] 24
            $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
            try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
            $password = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
            $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '.env.example'))
            $template = $template.Replace('MONGO_PASSWORD=', "MONGO_PASSWORD=$password")
            [IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $template, [Text.UTF8Encoding]::new($false))
            Write-Host '.env cree. Mot de passe enregistre dans .env, a la ligne MONGO_PASSWORD. Adaptez version et port avant start.'
        }
        return
    }
    $os = & docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0 -or $os -ne 'linux') { throw 'Demarrez Docker Desktop en mode conteneurs Linux.' }
    # Allow stopping even when local configuration contains an invalid preference.
    if ($Action -eq 'stop') { Invoke-Docker @('compose', 'down'); return }
    $json = & docker compose config --format json
    if ($LASTEXITCODE -ne 0) { throw 'Configuration invalide : lancez init et verifiez .env.' }
    $config = ($json -join "`n") | ConvertFrom-Json
    $service = $config.services.mongodb
    if ($service.image -notmatch '^mongo:[1-9][0-9]*\.[0-9]+(\.[0-9]+)?$') {
        throw 'MONGO_VERSION doit etre une branche X.Y ou une version exacte X.Y.Z, sans latest ni prerelease.'
    }
    Assert-DatabaseName ([string]$service.environment.MONGO_INITDB_DATABASE)
    switch ($Action) {
        'start' { Invoke-Docker @('compose', 'up', '-d', '--wait', '--wait-timeout', '180', 'mongodb') }
        'pull' { Invoke-Docker @('compose', 'pull', 'mongodb') }
        'status' { Invoke-Docker @('compose', 'ps') }
        'logs' { Invoke-Docker @('compose', 'logs', '-f', '--tail', '100', 'mongodb') }
        'shell' { Invoke-Docker @('compose', 'exec', 'mongodb', 'mongosh', '--quiet', '--nodb', '--shell', '--file', '/opt/mongodb-tools/connect.js') }
        'check' { Invoke-MongoFile '/opt/mongodb-tools/check.js' }
        'run' {
            $source = (Resolve-Path -LiteralPath $CommandArgs[0]).Path
            if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or [IO.Path]::GetExtension($source) -ne '.js') { throw 'Indiquez un fichier JavaScript .js existant.' }
            $remote = '/tmp/exercise-' + [Guid]::NewGuid().ToString('N') + '.js'
            try {
                Invoke-Docker @('compose', 'cp', $source, "mongodb:$remote")
                Invoke-MongoFile $remote
            } finally {
                Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'rm', '-f', $remote)
            }
        }
        'backup' {
            $details = ((Invoke-MongoFile '/opt/mongodb-tools/source.js') -join "`n") | ConvertFrom-Json
            $id = [Guid]::NewGuid().ToString('N')
            $remote = "/tmp/backup-$id.archive.gz"
            $local = Join-Path $PSScriptRoot ("backups/{0}-{1}.archive.gz" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $id)
            New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'backups') | Out-Null
            try {
                Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'sh', '/opt/mongodb-tools/transfer.sh', 'backup', $remote)
                Invoke-Docker @('compose', 'cp', "mongodb:$remote", $local)
                $metadata = [ordered]@{ format = 1; database = $details.database; version = $details.version; sha256 = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash }
                [IO.File]::WriteAllText("$local.json", ($metadata | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
                Write-Host "Sauvegarde : $local (conservez aussi le fichier .json associe)."
            } finally {
                Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'rm', '-f', $remote)
            }
        }
        'restore' {
            $source = (Resolve-Path -LiteralPath $CommandArgs[0]).Path
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Archive introuvable.' }
            $target = $CommandArgs[1]
            Assert-DatabaseName $target
            if (-not (Test-Path -LiteralPath "$source.json" -PathType Leaf)) { throw 'Fichier de metadonnees .json associe manquant.' }
            $metadata = [IO.File]::ReadAllText("$source.json") | ConvertFrom-Json
            if ($metadata.format -ne 1) { throw 'Format de sauvegarde inconnu.' }
            Assert-DatabaseName ([string]$metadata.database)
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $metadata.sha256) { throw 'Archive modifiee ou incomplete : SHA-256 incorrect.' }
            $server = ((Invoke-MongoFile '/opt/mongodb-tools/check.js') -join "`n") | ConvertFrom-Json
            # Conservative restore policy; cross-version migration needs a dedicated procedure.
            if ($metadata.version -notmatch '^([0-9]+\.[0-9]+)\.') { throw 'Version source invalide.' }
            $branch = $Matches[1]
            if (-not ([string]$server.version).StartsWith("$branch.")) { throw 'Restaurez sur la meme branche X.Y ; une migration de version demande une procedure dediee.' }
            $remote = '/tmp/restore-' + [Guid]::NewGuid().ToString('N') + '.archive.gz'
            try {
                Invoke-Docker @('compose', 'exec', '-T', '-e', "RESTORE_DATABASE=$target", 'mongodb', 'mongosh', '--quiet', '--nodb', '--file', '/opt/mongodb-tools/connect.js', '--file', '/opt/mongodb-tools/target.js')
                Invoke-Docker @('compose', 'cp', $source, "mongodb:$remote")
                Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'sh', '/opt/mongodb-tools/transfer.sh', 'restore', $remote, ([string]$metadata.database), $target)
                Write-Host "Restauration terminee dans $target."
            } finally {
                Invoke-Docker @('compose', 'exec', '-T', 'mongodb', 'rm', '-f', $remote)
            }
        }
    }
} finally { Pop-Location }
