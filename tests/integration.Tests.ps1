param([string]$Version = '9.0.8')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('docker-mongodb-test-' + [Guid]::NewGuid().ToString('N'))
$project = 'mongo-test-' + [Guid]::NewGuid().ToString('N')
$variables = @('COMPOSE_PROJECT_NAME', 'COMPOSE_FILE', 'COMPOSE_ENV_FILES', 'COMPOSE_PROFILES', 'MONGO_VERSION', 'MONGO_PORT', 'MONGO_USER', 'MONGO_DATABASE', 'MONGO_PASSWORD')
$saved = @{}
foreach ($name in $variables) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}
function Invoke-TestJs([string]$Code) {
    $path = Join-Path $testRoot 'exercise.js'
    [IO.File]::WriteAllText($path, $Code, [Text.UTF8Encoding]::new($false))
    & ./dev.ps1 run $path
}
function Assert-Rejected([scriptblock]$Command) {
    $rejected = $false
    try { & $Command } catch { $rejected = $true; Write-Host ('Refus attendu : ' + $_.Exception.Message) }
    if (-not $rejected) { throw 'La commande aurait du echouer.' }
}
New-Item -ItemType Directory -Path $testRoot | Out-Null
Push-Location $testRoot
try {
    foreach ($file in @('compose.yaml', 'dev.ps1', '.env.example', 'docker')) { Copy-Item (Join-Path $root $file) $testRoot -Recurse }
    $env:COMPOSE_PROJECT_NAME = $project
    $env:MONGO_PORT = '0'
    & ./dev.ps1 init
    $initial = [IO.File]::ReadAllText((Join-Path $testRoot '.env'))
    if ($initial -notmatch 'MONGO_PASSWORD=[a-f0-9]{48}') { throw 'Mot de passe aleatoire absent.' }
    & ./dev.ps1 init
    if ([IO.File]::ReadAllText((Join-Path $testRoot '.env')) -cne $initial) { throw 'init a modifie .env.' }
    $defaultConfig = & docker compose config --format json
    if ($LASTEXITCODE -ne 0) { throw 'Configuration Compose invalide.' }
    if ((($defaultConfig -join "`n") | ConvertFrom-Json).services.mongodb.image -ne 'mongo:9.0.8') { throw 'Version par defaut incorrecte.' }
    $env:MONGO_VERSION = $Version
    $env:MONGO_DATABASE = 'student_lab'
    $env:MONGO_USER = 'teacher'
    [IO.File]::WriteAllText((Join-Path $testRoot 'docker/init/01-test.js'), 'db.init_probe.insertOne({_id: 1, value: "initialised"});', [Text.UTF8Encoding]::new($false))
    & ./dev.ps1 start
    $check = ((& ./dev.ps1 check) -join "`n") | ConvertFrom-Json
    if (-not $check.authenticated -or $check.version -ne $Version -or $check.database -ne 'student_lab') { throw 'Diagnostic incorrect.' }
    # Authentication must be enforced, including without credentials.
    & docker compose exec -T mongodb mongosh --quiet --eval 'try { db.getSiblingDB(''admin'').getCollectionNames(); quit(1); } catch (error) { if (error.code === 13) quit(0); throw error; }'
    if ($LASTEXITCODE -ne 0) { throw 'Le controle d''acces anonyme n''a pas retourne Unauthorized.' }
    Invoke-TestJs 'if (db.init_probe.findOne({_id:1}).value !== "initialised") throw new Error("init failed"); db.students.insertOne({_id:42, name:"Eleve", score:18}); db.students.createIndex({score:1});'
    & ./dev.ps1 stop
    & ./dev.ps1 start
    Invoke-TestJs 'if (db.students.findOne({_id:42}).score !== 18 || db.init_probe.countDocuments() !== 1) throw new Error("persistence failed");'
    Assert-Rejected { Invoke-TestJs 'throw new Error("intentional exercise error");' }
    & ./dev.ps1 backup
    $dump = @(Get-ChildItem backups/*.archive.gz)
    if ($dump.Count -ne 1 -or $dump[0].Length -eq 0) { throw 'Archive absente ou vide.' }
    $archive = $dump[0].FullName
    & ./dev.ps1 restore $archive restored
    Invoke-TestJs 'const restored = db.getSiblingDB("restored"); if (restored.students.findOne({_id:42}).score !== 18 || !restored.students.getIndexes().some(i => i.key.score === 1)) throw new Error("restore failed");'
    Assert-Rejected { & ./dev.ps1 restore $archive restored }
    Assert-Rejected { & ./dev.ps1 restore $archive admin }
    $metaPath = "$archive.json"
    $originalMeta = [IO.File]::ReadAllText($metaPath)
    $badMeta = $originalMeta | ConvertFrom-Json
    $badMeta.sha256 = 'invalid'
    [IO.File]::WriteAllText($metaPath, ($badMeta | ConvertTo-Json))
    Assert-Rejected { & ./dev.ps1 restore $archive damaged }
    [IO.File]::WriteAllText($metaPath, $originalMeta)
    Invoke-TestJs 'if (db.getSiblingDB("restored").students.findOne({_id:42}).score !== 18) throw new Error("existing data changed");'
    $env:MONGO_VERSION = 'latest'
    Assert-Rejected { & ./dev.ps1 start }
    $env:MONGO_VERSION = $Version
    Write-Host "Tests MongoDB $Version reussis : configuration, authentification, scripts, persistance, sauvegarde et restauration avec index."
} finally {
    $env:MONGO_VERSION = $Version
    & docker compose -p $project down --volumes --remove-orphans
    $cleanupCode = $LASTEXITCODE
    Pop-Location
    foreach ($name in $variables) {
        if ($null -eq $saved[$name]) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    }
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($cleanupCode -eq 0 -and $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'docker-mongodb-test-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    if ($cleanupCode -ne 0) { throw "Nettoyage Docker incomplet ; dossier conserve : $testRoot" }
}
