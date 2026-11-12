# docker_mongodb

Environnement MongoDB autonome pour apprendre et développer sous Windows avec
Docker Desktop. Une instance simple (*standalone*), une version configurable,
des données persistantes et des commandes PowerShell pour travailler sans
installer MongoDB ni ses outils sur Windows. Aucun framework n'est nécessaire.

> [!WARNING]
> **Cet environnement est réservé au développement local et à l'apprentissage. Ne l'utilisez pas tel quel en production.**
> Le compte fourni est administrateur, son mot de passe est stocké dans `.env`,
> et aucune configuration TLS, réplication ou sauvegarde automatique n'est prévue.
> Un déploiement en production nécessite une configuration dédiée : droits limités,
> gestion des secrets, connexions sécurisées, disponibilité et sauvegardes vérifiées.

## Prérequis

- Docker Desktop démarré avec le moteur WSL2 et les conteneurs Linux.
- Docker Compose v2 récent avec `up --wait` et `config --format json`.
- Windows PowerShell 5.1 ou PowerShell 7.
- Internet pour télécharger les images, et suffisamment d'espace pour les données
  et les sauvegardes.
- Sur un PC x86-64, un processeur compatible avec les exigences de MongoDB,
  notamment AVX. Un ancien PC peut ne pas convenir, même si Docker fonctionne.

Les exigences matérielles et du noyau Linux sont détaillées dans les
[notes officielles de plateforme](https://www.mongodb.com/docs/manual/administration/production-notes/).
Le noyau utilisé est celui de Docker Desktop/WSL2, pas celui d'une installation
MongoDB sur Windows. MongoDB Compass est facultatif ; `mongosh`, `mongodump`
et `mongorestore` sont déjà disponibles dans le conteneur.

## Récupérer le projet pour un cours

Téléchargez et extrayez entièrement l'archive du dépôt ou de la release fournie
par votre enseignant. Le dossier extrait contient `README.md`, `dev.ps1`,
`compose.yaml`, `.env.example` et le sous-dossier `docker/`. Git n'est pas requis
pour utiliser l'archive. Vous pouvez aussi cloner l'URL du dépôt fournie par
l'enseignant si vous utilisez Git.

Dans ce guide, `docker_mongodb` désigne la racine du dossier extrait, même si
celui-ci s'appelle `docker_mongodb-main` ou comporte un numéro de version.
`docker_mongodb/.env` désigne le fichier `.env` à cette racine, pas un second
dossier imbriqué. **Toutes les commandes PowerShell sont à lancer depuis cette
racine**, sauf indication contraire. Les commandes JavaScript sont à saisir
dans la console MongoDB, pas dans PowerShell.

## Installation

Ouvrez PowerShell dans le dossier contenant `dev.ps1` et lancez :

```powershell
.\dev.ps1 init
```

Cette commande crée **`docker_mongodb/.env`** à partir de `.env.example`, avec
un mot de passe aléatoire. Consultez-le à la ligne **`MONGO_PASSWORD`** de `.env`.
Un `.env` existant est conservé sans modification. Ne partagez pas ce fichier.

Avant le premier démarrage, vous pouvez ouvrir `docker_mongodb/.env` dans votre
éditeur pour modifier les lignes décrites ci-dessous. Enregistrez, puis lancez :

```powershell
.\dev.ps1 start
.\dev.ps1 check
```

`start` télécharge l'image si elle manque, démarre en arrière-plan et attend un
contrôle de santé authentifié, avec un délai maximum de 180 secondes. Vous pouvez
ensuite fermer le terminal. `check` affiche la version réelle, la base sélectionnée
et la confirmation d'authentification. Une base vide peut ne pas encore exister.

Si PowerShell bloque les scripts, utilisez ponctuellement, depuis le même dossier :

```powershell
powershell -ExecutionPolicy Bypass -File .\dev.ps1 init
powershell -ExecutionPolicy Bypass -File .\dev.ps1 start
powershell -ExecutionPolicy Bypass -File .\dev.ps1 check
```

Le même préfixe s'applique aux autres commandes du guide. Il ne change pas la
politique d'exécution permanente de votre poste.

## Configuration : quel fichier modifier ?

Modifiez les lignes existantes dans **`docker_mongodb/.env`**, à côté de
`compose.yaml`. N'ajoutez pas de doublons. `.env.example` reste le modèle : le
modifier après `init` n'actualise pas votre `.env`.

| Variable | Valeur par défaut | Rôle |
| --- | --- | --- |
| `MONGO_VERSION` | `9.0.8` | Version exacte `X.Y.Z` ou branche `X.Y` |
| `MONGO_PORT` | `27017` | Port publié sur Windows, uniquement sur `127.0.0.1` |
| `MONGO_USER` | `admin` | Administrateur initial, authentifié dans la base `admin` |
| `MONGO_PASSWORD` | générée par `init` | Mot de passe de cet administrateur |
| `MONGO_DATABASE` | `app` | Base de travail pour `shell`, `run`, `backup` et les scripts d'initialisation |
| `COMPOSE_PROJECT_NAME` | nom du dossier | Identité des conteneurs, du réseau et des volumes |

La version **9.0.8** est la dernière version stable vérifiée le **12 novembre 2026**
dans les [notes MongoDB](https://www.mongodb.com/docs/manual/release-notes/9.0/)
et le [catalogue de l'image officielle](https://github.com/docker-library/official-images/blob/master/library/mongo).
Elle est fixée pour éviter qu'un cours change de version sans décision explicite.
Pour suivre les correctifs d'une branche, utilisez par exemple `MONGO_VERSION=9.0`
et la procédure de mise à jour. `latest`, `stable`, les versions majeures seules
et les préversions sont refusés par `dev.ps1`. Le tag numérique demandé doit
exister dans l'image officielle `mongo` ; aucune ancienne version n'est choisie
automatiquement en cas d'erreur. Un tag exact ne constitue pas un verrou par digest.

Les variables définies dans votre terminal ont priorité sur `.env`. Si vous
définissez un mot de passe contenant `$`, entourez sa valeur d'apostrophes dans
`.env` pour éviter l'interpolation Compose. Celui généré par `init` est hexadécimal.
Une valeur vide de `MONGO_PASSWORD` bloque le démarrage.

Les noms de bases acceptés par le script contiennent de 1 à 63 caractères :
minuscules, chiffres et underscores, avec une lettre au début. `admin`, `config`
et `local` sont réservés au fonctionnement du serveur.

Les identifiants sont créés **uniquement lors de l'initialisation d'un volume vide**.
Modifier `MONGO_USER` ou `MONGO_PASSWORD` dans `.env` ne modifie pas un compte
existant. `MONGO_DATABASE` sélectionne une base ; elle ne crée ni utilisateur
supplémentaire ni données. MongoDB matérialise la base lors d'une première écriture.

## Premier exercice

Dans PowerShell, depuis `docker_mongodb` :

```powershell
.\dev.ps1 shell
```

Dans la console **mongosh** qui s'ouvre, saisissez :

```javascript
db.getName()
db.students.insertOne({ name: "Alice", course: "MongoDB", score: 18 })
db.students.find()
db.students.createIndex({ name: 1 })
show dbs
exit
```

`db` correspond à `MONGO_DATABASE` dans `.env`. `exit` revient à PowerShell.
À la fin du cours, lancez `.\dev.ps1 stop`. À la séance suivante,
`.\dev.ps1 start` puis `.\dev.ps1 shell` retrouvent les données.

Pour conserver un exercice dans un fichier, créez **`docker_mongodb/exercice.js`**
avec votre éditeur, par exemple :

```javascript
printjson(db.students.find().toArray());
```

Exécutez-le depuis PowerShell avec `.\dev.ps1 run exercice.js`. Le fichier est
copié temporairement dans le conteneur, exécuté avec la connexion authentifiée
et la variable `db` déjà préparées, puis la copie temporaire est supprimée.
Le fichier Windows reste en place. Les chemins sont relatifs à la racine du projet ;
un chemin absolu est aussi accepté. Une erreur JavaScript fait échouer la commande.

## Commandes du quotidien

```powershell
.\dev.ps1 start
.\dev.ps1 status
.\dev.ps1 check
.\dev.ps1 shell
.\dev.ps1 run exercice.js
.\dev.ps1 logs
.\dev.ps1 backup
.\dev.ps1 stop
```

`logs` suit les journaux ; Ctrl+C quitte leur affichage sans arrêter la base.
`stop` retire les conteneurs et le réseau, mais conserve les volumes.
Les commandes sont indépendantes ; il ne faut pas toutes les lancer à la suite.

Après `init`, Compose reste utilisable depuis ce même dossier :

```powershell
docker compose config --quiet
docker compose up -d --wait
docker compose down
```

`dev.ps1` apporte des validations supplémentaires. `docker compose config`
sans `--quiet` affiche notamment le mot de passe résolu : ne partagez pas sa sortie.

## Connexion depuis Windows ou MongoDB Compass

Dans les paramètres de connexion de votre client, utilisez les valeurs du fichier
**`docker_mongodb/.env`** :

- Hôte : `127.0.0.1` ; port : `MONGO_PORT` (`27017` par défaut).
- Utilisateur : `MONGO_USER` ; mot de passe : `MONGO_PASSWORD`.
- Base d'authentification : **`admin`**, même si votre base de travail est `app`.
- Connexion directe ; TLS non configuré ; aucun replica set à renseigner.

Si le client demande une URI, partez de cet exemple :

```text
mongodb://admin:MOT_DE_PASSE@127.0.0.1:27017/app?authSource=admin&directConnection=true
```

Remplacez le premier `admin` par `MONGO_USER`, `MOT_DE_PASSE` par `MONGO_PASSWORD`,
le port par `MONGO_PORT` et `app` par `MONGO_DATABASE`. Conservez `authSource=admin`.
Encodez les caractères réservés de l'utilisateur et du mot de passe si nécessaire ;
le mot de passe hexadécimal généré fonctionne directement. Aucun compte Atlas ni
accès à un service cloud n'est requis.

## Connexion depuis une application Docker

Dans le **fichier Compose de l'application**, à la racine de son propre projet,
fusionnez cet exemple avec les sections existantes. Remplacez `application` par
le vrai nom du service et conservez ses autres paramètres et réseaux :

```yaml
services:
  application:
    networks:
      - default
      - mongodb
networks:
  mongodb:
    external: true
    name: docker_mongodb_default
```

Le réseau indiqué existe après `start` si le dossier s'appelle `docker_mongodb`.
Si vous avez choisi `COMPOSE_PROJECT_NAME=cours-mongodb` dans **`docker_mongodb/.env`**,
mettez `name: cours-mongodb_default` dans le Compose de l'application.
Un autre nom de dossier change aussi le préfixe du réseau. Choisissez un nom de
projet explicite avant le premier démarrage pour une connexion prévisible.

Dans la configuration de connexion de votre application, utilisez l'hôte
**`mongodb`**, le port interne **`27017`**, vos identifiants et `authSource=admin`.
Le fichier applicatif à modifier dépend de cette application : consultez sa
documentation. Cet environnement n'impose aucune variable applicative particulière.
Démarrez MongoDB avant l'application. Pour tout arrêter, retirez d'abord les
conteneurs applicatifs raccordés au réseau avant `.\dev.ps1 stop` côté MongoDB.

## Données et scripts d'initialisation

Les volumes `mongodb_data` et `mongodb_config`, préfixés par le nom Compose,
restent dans Linux. Aucun dossier Windows ne sert de stockage aux fichiers de la
base. **`docker compose down -v` supprime définitivement ces volumes.**
Changer le nom du projet ou du dossier ne déplace pas les données : cela peut
désigner d'autres volumes, initialement vides.

Pour préparer un jeu de données au tout premier démarrage, créez par exemple
**`docker_mongodb/docker/init/01-data.js`** avant `start` :

```javascript
db.students.insertOne({ name: "Exemple", score: 12 });
```

Les fichiers `.js` et `.sh` de ce dossier sont exécutés dans l'ordre alphabétique
uniquement sur un volume neuf. Les scripts JavaScript utilisent la base choisie
par `MONGO_DATABASE`. Enregistrez les scripts shell avec des fins de ligne LF.
Si une initialisation échoue, consultez les journaux : un redémarrage ne rejoue
pas automatiquement les scripts déjà commencés. Pour une base existante, utilisez
`run` avec un script adapté ; les fichiers de `docker/init/` ne sont pas des migrations.

## Sauvegarde et restauration

Avec MongoDB démarré, **suspendez les écritures** de vos applications et des autres
consoles pendant une sauvegarde. Une instance simple ne fournit pas de sauvegarde
cohérente à un instant donné si les données changent pendant `mongodump`.

Depuis PowerShell, à la racine de `docker_mongodb` :

```powershell
.\dev.ps1 backup
# Remplacez DATE-IDENTIFIANT par le nom exact affiche par backup.
.\dev.ps1 restore backups/DATE-IDENTIFIANT.archive.gz app_restored
```

`backup` exporte la base sélectionnée par `MONGO_DATABASE`. Une base absente ou
sans collection est refusée. Deux fichiers sont créés dans **`docker_mongodb/backups/`** :

- `DATE-IDENTIFIANT.archive.gz` : archive binaire compressée, documents et index.
- `DATE-IDENTIFIANT.archive.gz.json` : nom de base source, version serveur et SHA-256.

**Conservez et copiez les deux ensemble**, sans modifier leurs contenus.
La copie binaire utilise `docker compose cp`, sans redirection texte PowerShell.
Ces fichiers sont ignorés par Git. Gardez également une copie hors de votre poste.
Les utilisateurs, les rôles et les autres bases ne font pas partie de cette
sauvegarde ; elle vise les exercices sur une seule base, pas la reconstruction
complète d'un serveur. N'importez que vos archives ou celles d'une source fiable :
la somme de contrôle détecte une altération accidentelle, pas une origine malveillante.

`restore` exige une **base cible inexistante**, vérifie l'archive et conserve
l'original. Il n'utilise jamais `--drop`. `app_restored` est le nom de cette nouvelle
base, pas un fichier ; vous pouvez le remplacer par un nom valide. Ne lancez pas
plusieurs restaurations simultanées et n'écrivez pas dans la base cible pendant
l'opération. La restauration n'est pas transactionnelle : un échec peut laisser
une base partielle. Inspectez-la et utilisez un autre nom pour réessayer ; aucune
suppression automatique n'est effectuée.

Le script exige la même branche serveur `X.Y` à la restauration (par exemple
9.0 vers 9.0). Cette règle volontairement conservatrice ne couvre pas les
migrations entre branches ni les collections chiffrées. Les limitations des
outils MongoDB continuent de s'appliquer.

Pour consulter la base restaurée, lancez `.\dev.ps1 shell` dans PowerShell,
puis `use app_restored` et `show collections` dans mongosh. Si elle devient votre
base de travail, définissez **`MONGO_DATABASE=app_restored` dans `docker_mongodb/.env`**,
puis lancez `.\dev.ps1 start`. Les prochains `shell`, `run` et `backup` utiliseront
cette base. Adaptez aussi la connexion de vos clients.

## Modifier le mot de passe

Avec les identifiants d'origine dans `docker_mongodb/.env` et le service démarré,
lancez `.\dev.ps1 shell`. Dans mongosh, pour l'utilisateur `admin` par défaut :

```javascript
use admin
db.changeUserPassword("admin", passwordPrompt())
exit
```

Remplacez le nom d'utilisateur dans la commande par celui de `MONGO_USER` si vous
l'aviez personnalisé ; la base d'authentification reste `admin`. Le nouveau mot
de passe est saisi à l'invite. Mettez ensuite à jour **`MONGO_PASSWORD` dans
`docker_mongodb/.env`**, enregistrez, puis lancez `.\dev.ps1 start` et `.\dev.ps1 check`.
Actualisez aussi vos clients. Modifier seulement `.env` ne change pas le compte.

## Modifier la version et la configuration du serveur

Pour changer de correctif dans la même branche, suspendez les écritures et
sauvegardez avec `.\dev.ps1 backup`. Modifiez ensuite **`MONGO_VERSION` dans
`docker_mongodb/.env`**, enregistrez, puis lancez :

```powershell
.\dev.ps1 pull
.\dev.ps1 start
.\dev.ps1 check
```

Avec une version exacte, `pull` ne sélectionne pas un numéro plus récent tout seul.
Avec `9.0`, il récupère le tag courant de cette branche. Le démarrage ordinaire ne
force pas un téléchargement si l'image est déjà disponible.

**Ne changez pas de branche ou de version majeure directement sur vos données de
cours.** Les chemins de mise à niveau et la *Feature Compatibility Version* (FCV)
ont des contraintes propres à MongoDB. Travaillez sur une copie avec une sauvegarde
vérifiée, suivez les notes officielles de la version cible et conservez l'ancien
environnement. `restore` n'est pas un outil de migration entre branches. Revenir
à une ancienne image ne garantit pas qu'un volume déjà mis à niveau reste lisible.

Pour régler le serveur, modifiez **`docker_mongodb/docker/mongod.conf`**.
Le fichier est monté en lecture seule dans le conteneur, mais reste modifiable
depuis votre éditeur Windows. Après modification, appliquez-le explicitement :

```powershell
docker compose up -d --force-recreate --wait mongodb
.\dev.ps1 check
```

Les scripts fournis supposent le port interne `27017`, l'authentification activée
et le stockage dans `/data/db`. Pour changer le port Windows, modifiez uniquement
`MONGO_PORT` dans `.env`. Ne désactivez pas l'authentification pour résoudre une erreur.

L'instance simple convient au CRUD, aux index et aux agrégations. Les transactions
multi-documents et les change streams demandent une autre topologie. Une évolution
vers un replica set nécessite notamment une configuration de réplication, une
authentification interne et une initialisation du replica set ; ajouter un seul
paramètre ne suffit pas. Ce dépôt ne propose pas de bascule automatique et sa suite
de tests valide le mode standalone. Consultez la
[procédure officielle de conversion](https://www.mongodb.com/docs/manual/tutorial/convert-standalone-to-replica-set/)
pour préparer cette évolution dans un environnement séparé.

## Plusieurs projets sur le même poste

Avant le premier `start`, dans le fichier **`.env` de chaque copie du projet**,
choisissez un nom de projet et un port distincts :

```dotenv
COMPOSE_PROJECT_NAME=cours-mongodb
MONGO_PORT=27018
```

Retirez le `#` devant la ligne `COMPOSE_PROJECT_NAME` déjà présente dans `.env`,
remplacez sa valeur et modifiez la ligne existante `MONGO_PORT`. Conservez ensuite
ce nom : le changer désigne d'autres volumes. Aucun nom de conteneur global n'est fixé.

## Tests et dépannage

Depuis la racine de `docker_mongodb`, pour vérifier la configuration locale ou
lancer les tests isolés :

```powershell
docker compose config --quiet
.\tests\integration.Tests.ps1
.\tests\integration.Tests.ps1 -Version 8.0.38
```

Les tests nécessitent Docker. Ils copient le projet dans un dossier temporaire,
créent un nom Compose unique et utilisent un port attribué automatiquement. Ils
vérifient l'initialisation, l'authentification, l'exécution de JavaScript, la
persistance, la restauration des documents et index et les refus des entrées
invalides. Leurs seuls volumes et conteneurs sont supprimés à la fin. Le workflow
`.github/workflows/test.yml` utilise la même suite sur 9.0.8 et 8.0.38.

- **Port occupé** : changez `MONGO_PORT` dans `docker_mongodb/.env`, puis relancez
  `.\dev.ps1 start` et adaptez le port dans vos clients Windows.
- **Authentification refusée** : vérifiez `authSource=admin` dans le client et
  les identifiants initiaux du volume. Suivez la procédure de mot de passe ci-dessus.
- **Base absente de la liste** : insérez un document dans mongosh ; sélectionner
  `app` sans écrire ne crée pas encore une base persistante.
- **Service non sain** : lancez `.\dev.ps1 logs`. Vérifiez notamment les scripts
  de `docker/init/`, la version et votre modification éventuelle de `docker/mongod.conf`.
- **Erreur CPU ou instruction illégale** : vérifiez les exigences matérielles MongoDB,
  notamment AVX. L'image ne peut pas ajouter une instruction absente du processeur.
- **Image introuvable** : vérifiez le tag numérique `MONGO_VERSION` dans `.env`.
- **Restauration refusée** : conservez le `.json` associé, choisissez une base neuve
  et utilisez la même branche `X.Y` que celle enregistrée dans les métadonnées.

## Distribution, Git et releases

Cette section concerne l'enseignant ou le mainteneur. Les étudiants n'ont pas besoin
de créer un dépôt ni de publier une release. Distribuez une archive de sources
issue de Git ; ne compressez pas votre dossier de travail avec son `.env`, ses
sauvegardes ou ses réglages IDE. Les fichiers `.env.example`, `docker/` et `LICENSE`
doivent rester présents. Chaque étudiant crée son propre mot de passe avec `init`.

Pour créer votre dépôt depuis `docker_mongodb` :

```powershell
git init
git branch -M main
git add .
git diff --cached --stat
git diff --cached
git commit -m "chore: initialize docker_mongodb repository"
```

Créez ensuite un dépôt distant vide et associez son URL avec `git remote add origin`
avant de pousser votre branche. Les commits suivent Conventional Commits :
`feat`, `fix`, `docs`, `test`, `ci`, `chore`, avec scope facultatif.

Après validation des tests, le push d'un tag stable `vMAJEUR.MINEUR.CORRECTIF`
déclenche `.github/workflows/release.yml`. Il génère les notes via `cliff.toml`
et joint `CHANGELOG.md` à la release GitHub. Ce fichier est généré dans le runner,
pas maintenu localement. Les releases déjà existantes sont conservées. Les actions
et git-cliff ont des versions fixées ; GitHub fournit les archives de sources.

## Références et licence

- [Image Docker officielle mongo](https://hub.docker.com/_/mongo).
- [Notes MongoDB 9.0](https://www.mongodb.com/docs/manual/release-notes/9.0/).
- [mongodump](https://www.mongodb.com/docs/database-tools/mongodump/) et
  [mongorestore](https://www.mongodb.com/docs/database-tools/mongorestore/).

Copyright © 2026 Nicolas Vauché. Les fichiers de cet environnement sont distribués
sous GNU GPL version 3 uniquement (`GPL-3.0-only`) ; voir [LICENSE](LICENSE).
Les composants tiers, dont MongoDB, conservent leurs propres licences.
