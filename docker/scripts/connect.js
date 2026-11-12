// Keep credentials out of host command lines and PowerShell quoting rules.
const user = encodeURIComponent(process.env.MONGO_INITDB_ROOT_USERNAME);
const password = encodeURIComponent(process.env.MONGO_INITDB_ROOT_PASSWORD);
const connection = new Mongo(`mongodb://${user}:${password}@127.0.0.1:27017/?authSource=admin&directConnection=true`);
db = connection.getDB(process.env.MONGO_INITDB_DATABASE);
