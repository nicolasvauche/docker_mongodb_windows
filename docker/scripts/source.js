if (db.getCollectionNames().length === 0) {
  throw new Error('Base absente ou sans collection : inserez des documents avant backup.');
}
print(JSON.stringify({ database: db.getName(), version: db.version() }));
