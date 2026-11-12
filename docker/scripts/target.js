const target = process.env.RESTORE_DATABASE;
if (!/^[a-z][a-z0-9_]{0,62}$/.test(target) || ['admin', 'config', 'local'].includes(target)) {
  throw new Error('Nom de base cible interdit.');
}
const databases = db.getSiblingDB('admin').runCommand({ listDatabases: 1, nameOnly: true });
if (databases.ok !== 1) throw new Error('Impossible de verifier les bases existantes.');
if (databases.databases.some(item => item.name === target)) {
  throw new Error('La base cible existe deja : restauration refusee.');
}
