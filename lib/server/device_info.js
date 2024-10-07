// filename: ../server/device_info.js

const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('device_info.js module loaded and running.');

  router.post('/device-info', async (req, res) => {
    console.log('Received POST request at /device-info');
    const { childId, deviceName, macAddress, androidId } = req.body; // Now includes androidId
    console.log('Received device info:', { childId, deviceName, macAddress, androidId });

    if (!childId || !deviceName || !macAddress || !androidId) {
      console.log('Device info failed: Missing fields');
      return res.status(400).json({ message: 'Missing fields' });
    }

    try {
      const deviceInfoCollection = db.collection('device_info');
      const existingDeviceInfo = await deviceInfoCollection.findOne({ childId: new ObjectId(childId) });

      if (existingDeviceInfo) {
        console.log('Updating existing device info...');
        await deviceInfoCollection.updateOne(
          { childId: new ObjectId(childId) },
          { $set: { device_name: deviceName, mac_address: macAddress, android_id: androidId } } // Update androidId as well
        );
        console.log('Device info updated successfully');
      } else {
        console.log('Inserting new device info...');
        await deviceInfoCollection.insertOne({
          childId: new ObjectId(childId),
          device_name: deviceName,
          mac_address: macAddress,
          android_id: androidId, // Save the Android ID
        });
        console.log('Device info saved successfully');
      }

      res.status(200).json({ message: 'Device info received and saved' });
    } catch (error) {
      console.error('Error saving device info to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};

/*
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  console.log('device_info.js module loaded and running.');

  router.post('/device-info', async (req, res) => {
    console.log('Received POST request at /device-info');
    const { childId, deviceName, macAddress } = req.body;
    console.log('Received device info:', { childId, deviceName, macAddress });

    if (!childId || !deviceName || !macAddress) {
      console.log('Device info failed: Missing fields');
      return res.status(400).json({ message: 'Missing fields' });
    }

    try {
      const deviceInfoCollection = db.collection('device_info');
      const existingDeviceInfo = await deviceInfoCollection.findOne({ childId: new ObjectId(childId) });

      if (existingDeviceInfo) {
        console.log('Updating existing device info...');
        await deviceInfoCollection.updateOne(
          { childId: new ObjectId(childId) },
          { $set: { device_name: deviceName, mac_address: macAddress } }
        );
        console.log('Device info updated successfully');
      } else {
        console.log('Inserting new device info...');
        await deviceInfoCollection.insertOne({
          childId: new ObjectId(childId),
          device_name: deviceName,
          mac_address: macAddress,
        });
        console.log('Device info saved successfully');
      }

      res.status(200).json({ message: 'Device info received and saved' });
    } catch (error) {
      console.error('Error saving device info to database:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};*/