const status = db.getSiblingDB('admin').runCommand({ connectionStatus: 1 });
if (status.ok !== 1 || status.authInfo.authenticatedUsers.length === 0) {
  throw new Error('Authentification MongoDB absente.');
}
print(JSON.stringify({ version: db.version(), database: db.getName(), authenticated: true }));
