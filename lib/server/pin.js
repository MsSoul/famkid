// filename: pin.js
const bcrypt = require('bcrypt');  // Import bcrypt
const saltRounds = 10;  // Number of salt rounds for bcrypt

module.exports = (db) => {
  const express = require('express');
  const router = express.Router();

  router.post('/set-pin', async (req, res) => {
    const { childId, pin } = req.body;

    console.log(`Received childId: ${childId}, pin: ${pin}`);

    // Check if the childId is a valid string
    if (!childId || typeof childId !== 'string') {
      return res.status(400).json({ message: 'Invalid childId format. Must be a non-empty string.' });
    }

    // Validate that the PIN is a 4-digit number
    if (!/^\d{4}$/.test(pin)) {
      return res.status(400).json({ message: 'Invalid PIN format. Must be 4 digits.' });
    }

    try {
      // Hash the PIN before saving
      const hashedPin = await bcrypt.hash(pin, saltRounds);
      console.log(`Hashed PIN: ${hashedPin}`);

      // Update the child_pin document with the hashed PIN
      const result = await db.collection('child_pin').findOneAndUpdate(
        { childId: childId },  // Use childId as a string in the filter
        { $set: { pin: hashedPin } },  // Save the hashed pin
        { upsert: true, returnDocument: 'after' }  // Create a new document if it doesn't exist
      );

      if (result.value) {
        console.log(`PIN updated for existing childId: ${childId}`);
      } else {
        console.log(`New PIN created for childId: ${childId}`);
      }

      res.status(200).json({ message: 'PIN saved successfully' });
    } catch (error) {
      console.error('Error saving PIN:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};

/*nagasave na ni kaso naga new sya ug child id sabata
const { ObjectId } = require('mongodb');  // Import ObjectId

module.exports = (db) => {
  const express = require('express');
  const router = express.Router();

  router.post('/set-pin', async (req, res) => {
    const { childId, pin } = req.body;

    console.log(`Received childId: ${childId}, pin: ${pin}`);

    // Check if the childId is a valid ObjectId
    if (!ObjectId.isValid(childId)) {
      return res.status(400).json({ message: 'Invalid childId format.' });
    }

    if (!/^\d{4}$/.test(pin)) {
      return res.status(400).json({ message: 'Invalid PIN format. Must be 4 digits.' });
    }

    try {
      // Convert childId to ObjectId
      const objectChildId = new ObjectId(childId);

      // Update the child_pin document with the ObjectId
      const result = await db.collection('child_pin').findOneAndUpdate(
        { childId: objectChildId },  // Use ObjectId instead of string
        { $set: { pin: pin } },
        { upsert: true, returnDocument: 'after' }
      );

      console.log('Database update result:', result);
      res.status(200).json({ message: 'PIN saved successfully' });
    } catch (error) {
      console.error('Error saving PIN:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};*/

/*
const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');

// Define a Mongoose schema for the PIN
const pinSchema = new mongoose.Schema({
  childId: { type: mongoose.Schema.Types.ObjectId, required: true, unique: true },
  pin: { type: String, required: true }, // Store the 4-digit PIN as a string
});

// Create the model and explicitly set the collection name to 'child_pin'
const Pin = mongoose.model('Pin', pinSchema, 'child_pin');

// Route to set or update a PIN for a child
router.post('/set-pin', async (req, res) => {
  try {
    const { childId, pin } = req.body;
    console.log('Received request to set PIN:', { childId, pin });  // Log the request body

    // PIN validation: must be a 4-digit number
    if (!/^\d{4}$/.test(pin)) {
      console.log('Invalid PIN format');  // Log invalid PIN format
      return res.status(400).json({ message: 'Invalid PIN format. Must be 4 digits.' });
    }

    // Validate childId
    if (!mongoose.Types.ObjectId.isValid(childId)) {
      console.log('Invalid childId format');  // Log invalid childId format
      return res.status(400).json({ message: 'Invalid childId format.' });
    }

    console.log('Saving or updating PIN...');  // Log before saving/updating PIN

    // Save or update the PIN for the child in the 'child_pin' collection
    const existingPin = await Pin.findOneAndUpdate(
      { childId },
      { pin },
      { new: true, upsert: true }  // Upsert: insert if not exists, update if exists
    );

    console.log('PIN saved successfully:', existingPin);  // Log success
    res.status(200).json({ message: 'PIN saved successfully', pin: existingPin });
  } catch (error) {
    console.error('Error setting PIN:', error);  // Log error
    res.status(500).json({ message: 'Failed to set PIN', error });
  }
});

// Route to verify a PIN for a child
router.post('/verify-pin', async (req, res) => {
  try {
    const { childId, pin } = req.body;
    console.log('Received request to verify PIN:', { childId, pin });  // Log the request body

    // Validate childId
    if (!mongoose.Types.ObjectId.isValid(childId)) {
      console.log('Invalid childId format');  // Log invalid childId format
      return res.status(400).json({ message: 'Invalid childId format.' });
    }

    console.log('Finding stored PIN...');  // Log before PIN lookup

    // Find the stored PIN for the child in the 'child_pin' collection
    const storedPin = await Pin.findOne({ childId });

    if (!storedPin) {
      console.log('PIN not found for child:', childId);  // Log if no PIN found
      return res.status(400).json({ message: 'Invalid PIN' });
    }

    console.log('Stored PIN:', storedPin.pin);  // Log the stored PIN
    console.log('Provided PIN:', pin);  // Log the provided PIN

    // Compare the stored PIN with the provided PIN
    if (storedPin.pin !== pin) {
      console.log('PIN mismatch');  // Log PIN mismatch
      return res.status(400).json({ message: 'Invalid PIN' });
    }

    console.log('PIN verified successfully');  // Log successful verification
    res.status(200).json({ message: 'PIN verified successfully' });
  } catch (error) {
    console.error('Error verifying PIN:', error);  // Log error
    res.status(500).json({ message: 'Failed to verify PIN', error });
  }
});

module.exports = router;
*/