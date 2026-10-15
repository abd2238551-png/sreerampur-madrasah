/* Public Appwrite client identifiers. Never put an Appwrite server API key here. */
window.MadrasahAppwriteConfig = Object.freeze({
  endpoint: 'https://fra.cloud.appwrite.io/v1',
  projectId: '6ad01c2400399eaf6362',
  databaseId: '6ad01db200392a309d8c',
  tableId: '6ad01dd0002c91ff7e69',
  sdkVersion: '28.3.0'
});

const appwriteClient = new Appwrite.Client()
  .setEndpoint(MadrasahAppwriteConfig.endpoint)
  .setProject(MadrasahAppwriteConfig.projectId);

window.MadrasahAppwrite = Object.freeze({
  client: appwriteClient,
  account: new Appwrite.Account(appwriteClient),
  tables: new Appwrite.TablesDB(appwriteClient),
  ID: Appwrite.ID,
  Query: Appwrite.Query,
  Permission: Appwrite.Permission,
  Role: Appwrite.Role
});
