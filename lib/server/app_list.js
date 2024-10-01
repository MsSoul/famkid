// filename: ../server/app_list.js
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('app_list.js module loaded and running.');

  router.post('/app-list', async (req, res) => {
    console.log('Received POST request at /app-list');
    const { childId, apps } = req.body;

    console.log('Received app list for childId:', childId);
    console.log('Number of apps received:', apps ? apps.length : 0);

    if (!childId || !apps || apps.length === 0) {
      console.log('No apps to insert');
      return res.status(400).json({ message: 'No apps to insert or missing childId' });
    }

    try {
      const appListCollection = db.collection('app_list');

      // Iterate over each app in the list
      for (const app of apps) {
        const query = {
          child_id: new ObjectId(childId),
          package_name: app.packageName
        };

        const update = {
          $set: {
            app_name: app.appName
          }
        };

        const options = { upsert: true }; // This option will insert a new document if no match is found

        // Update the existing document or insert a new one
        const result = await appListCollection.updateOne(query, update, options);

        console.log(`App ${app.appName} ${result.matchedCount > 0 ? 'updated' : 'inserted'}`);
      }

      console.log('App list processed successfully');
      res.status(200).json({ message: 'App list processed successfully' });
    } catch (error) {
      console.error('Error saving app list to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};


/*
// filename: ../server/app_list.js
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('app_list.js module loaded and running.');

  router.post('/app-list', async (req, res) => {
    console.log('Received POST request at /app-list');
    const { childId, apps } = req.body;

    console.log('Received app list for childId:', childId);
    console.log('Number of apps received:', apps ? apps.length : 0);

    if (!childId || !apps || apps.length === 0) {
      console.log('No apps to insert');
      return res.status(400).json({ message: 'No apps to insert or missing childId' });
    }

    try {
      const appListCollection = db.collection('app_list');

      // Iterate over each app in the list
      for (const app of apps) {
        const query = {
          child_id: new ObjectId(childId),
          package_name: app.packageName
        };

        const update = {
          $set: {
            app_name: app.appName
          }
        };

        const options = { upsert: true }; // This option will insert a new document if no match is found

        // Update the existing document or insert a new one
        const result = await appListCollection.updateOne(query, update, options);

        console.log(`App ${app.appName} ${result.matchedCount > 0 ? 'updated' : 'inserted'}`);
      }

      console.log('App list processed successfully');
      res.status(200).json({ message: 'App list processed successfully' });
    } catch (error) {
      console.error('Error saving app list to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};

*/
/*
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('app_list.js module loaded and running.');

  router.post('/app-list', async (req, res) => {
    console.log('Received POST request at /app-list');
    const { childId, apps } = req.body;

    console.log('Received app list for childId:', childId);
    console.log('Number of apps received:', apps ? apps.length : 0);

    if (!childId || !apps || apps.length === 0) {
      console.log('No apps to insert');
      return res.status(400).json({ message: 'No apps to insert or missing childId' });
    }

    try {
      const appManagementCollection = db.collection('app_management');

      // Iterate over each app in the list
      for (const app of apps) {
        const query = {
          child_id: new ObjectId(childId),
          package_name: app.packageName
        };

        const update = {
          $set: {
            app_name: app.appName,
            is_allowed: app.is_allowed ?? true
          }
        };

        const options = { upsert: true }; // This option will insert a new document if no match is found

        // Update the existing document or insert a new one
        const result = await appManagementCollection.updateOne(query, update, options);

        console.log(`App ${app.appName} ${result.matchedCount > 0 ? 'updated' : 'inserted'}`);
      }

      console.log('App list processed successfully');
      res.status(200).json({ message: 'App list processed successfully' });
    } catch (error) {
      console.error('Error saving app list to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};
*/
/*
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('app_list.js module loaded and running.');

  router.post('/app-list', async (req, res) => {
    console.log('Received POST request at /app-list');
    const { childId, apps } = req.body;

    console.log('Received app list for childId:', childId);
    console.log('Number of apps received:', apps ? apps.length : 0);

    if (!childId || !apps || apps.length === 0) {
      console.log('No apps to insert');
      return res.status(400).json({ message: 'No apps to insert or missing childId' });
    }

    try {
      const appManagementCollection = db.collection('app_management');
      const appDocuments = apps.map(app => ({
        child_id: new ObjectId(childId),
        app_name: app.appName, 
        package_name: app.packageName,
        is_allowed: app.is_allowed ?? true, 
      }));

      console.log('App documents to be inserted:', JSON.stringify(appDocuments, null, 2));

      await appManagementCollection.insertMany(appDocuments);

      console.log('App list saved successfully');
      res.status(200).json({ message: 'App list received and saved' });
    } catch (error) {
      console.error('Error saving app list to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};
*/