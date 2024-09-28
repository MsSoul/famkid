// filename: server/qr_code_connection.js
const express = require('express');
const { ObjectId } = require('mongodb');  // Ensure ObjectId is imported

module.exports = function (db, notifyClient) {
  const router = express.Router();

  // Compare data between device_info and child_profile
  router.get('/compare-device-and-profile', async (req, res) => {
    const { childId, deviceName } = req.query;

    console.log(`Checking device info for childId: ${childId}, deviceName: ${deviceName}`);

    // Convert childId to ObjectId to match MongoDB format
    let objectIdChildId;
    try {
      objectIdChildId = new ObjectId(childId);  // Convert childId to ObjectId
    } catch (error) {
      console.error('Invalid ObjectId format for childId:', childId);
      return res.status(400).json({ message: 'Invalid childId format' });
    }

    try {
      const deviceInfoCollection = db.collection('device_info');
      const childProfileCollection = db.collection('child_profile');

      // Find device info by childId and device_name
      const deviceInfo = await deviceInfoCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,  // Strict comparison to avoid mismatch
      });

      if (!deviceInfo) {
        console.log('Device Info not found');
        return res.status(404).json({ success: false, message: 'Device Info not found' });
      }

      console.log('Device Info Found:', deviceInfo);

      // Find child profile by childId and device_name
      const childProfile = await childProfileCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,  // Strict comparison to avoid mismatch
      });

      if (!childProfile) {
        console.log('Child Profile not found');
        return res.status(404).json({ success: false, message: 'Child Profile not found' });
      }

      console.log('Child Profile Found:', childProfile);

      // Notify client through WebSocket when profile matches
      notifyClient(childId, 'Profile successfully matched');

      return res.status(200).json({ success: true, message: 'Profile successfully matched' });
    } catch (error) {
      console.error('Error comparing data:', error);
      return res.status(500).json({ message: 'Server error', error });
    }
  });

  return router;
};

/*
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function (db, notifyClient) {
  const router = express.Router();

  // Compare data between device_info and child_profile
  router.get('/compare-device-and-profile', async (req, res) => {
    const { childId, deviceName } = req.query;

    console.log(`Checking device info for childId: ${childId}, deviceName: ${deviceName}`);

    // Convert childId to ObjectId to match MongoDB format
    let objectIdChildId;
    try {
      objectIdChildId = new ObjectId(childId); 
    } catch (error) {
      console.error('Invalid ObjectId format for childId:', childId);
      return res.status(400).json({ message: 'Invalid childId format' });
    }

    try {
      const deviceInfoCollection = db.collection('device_info');
      const childProfileCollection = db.collection('child_profile');

      // Find device info by childId and device_name
      const deviceInfo = await deviceInfoCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,
      });

      // If no matching deviceInfo found
      if (!deviceInfo) {
        console.log('Device Info not found');
        return res.status(404).json({ success: false, message: 'Device Info not found' });
      }

      console.log('Device Info Found:', deviceInfo);

      // Find child profile by the same criteria
      const childProfile = await childProfileCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,
      });

      // If no matching childProfile found
      if (!childProfile) {
        console.log('Child Profile not found');
        return res.status(404).json({ success: false, message: 'Child Profile not found' });
      }

      console.log('Child Profile Found:', childProfile);

      // Notify client through WebSocket when profile matches
      notifyClient(childId, 'Profile successfully matched');

      return res.status(200).json({ success: true, message: 'Profile successfully matched' });
    } catch (error) {
      console.error('Error comparing data:', error);
      return res.status(500).json({ message: 'Server error', error });
    }
  });

  return router;
};
*/
/* may trigger  ni sya pero ga work na.
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  // Compare data between device_info and child_profile
  router.get('/compare-device-and-profile', async (req, res) => {
    const { childId, deviceName } = req.query;

    console.log(`Checking device info for childId: ${childId}, deviceName: ${deviceName}`);

    // Convert childId to ObjectId to match MongoDB format
    let objectIdChildId;
    try {
      objectIdChildId = new ObjectId(childId); 
    } catch (error) {
      console.error('Invalid ObjectId format for childId:', childId);
      return res.status(400).json({ message: 'Invalid childId format' });
    }

    try {
      const deviceInfoCollection = db.collection('device_info');
      const childProfileCollection = db.collection('child_profile');

      // Find device info by childId and device_name
      const deviceInfo = await deviceInfoCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,
      });

      // If no matching deviceInfo found
      if (!deviceInfo) {
        console.log('Device Info not found');
        return res.status(404).json({ success: false, message: 'Device Info not found' });
      }

      console.log('Device Info Found:', deviceInfo);

      // Find child profile by the same criteria
      const childProfile = await childProfileCollection.findOne({
        childId: objectIdChildId,
        device_name: deviceName,
      });

      // If no matching childProfile found
      if (!childProfile) {
        console.log('Child Profile not found');
        return res.status(404).json({ success: false, message: 'Child Profile not found' });
      }

      console.log('Child Profile Found:', childProfile);

      return res.status(200).json({ success: true, message: 'Profile successfully matched' });
    } catch (error) {
      console.error('Error comparing data:', error);
      return res.status(500).json({ message: 'Server error', error });
    }
  });

  return router;
};
*/