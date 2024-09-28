// filename: ../server/user.js
const express = require('express');
const bcrypt = require('bcryptjs');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
  const router = express.Router();

  // Log that user.js is loaded
  console.log('user.js module loaded and running.');

  // Child signup route
  router.post('/child-signup', async (req, res) => {
    const { email, username, password, day, month, year } = req.body;
    console.log('Received child signup request:', { email, username, password, day, month, year });

    if (!email || !username || !password || !day || !month || !year) {
      console.log('Signup failed: Missing fields');
      return res.status(400).json({ message: 'Missing fields' });
    }

    try {
      const childCollection = db.collection('child_registration');

      // Check if email is already in use
      console.log('Checking if email is already in use:', email);
      const emailExists = await childCollection.findOne({ email });
      if (emailExists) {
        console.log('Signup failed: Email already in use');
        return res.status(400).json({ message: 'Email already in use' });
      }

      // Check if username is already in use
      console.log('Checking if username is already in use:', username);
      const usernameExists = await childCollection.findOne({ username });
      if (usernameExists) {
        console.log('Signup failed: Username already in use');
        return res.status(400).json({ message: 'Username already in use' });
      }

      const hashedPassword = await bcrypt.hash(password, 10);

      // Create new child account
      console.log('Creating new child account...');
      await childCollection.insertOne({
        email,
        username,
        password: hashedPassword,
        day,
        month,
        year,
      });
      console.log('Child registered successfully');
      res.status(201).json({ message: 'Child registered successfully' });
    } catch (error) {
      console.error('Error during child signup:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  // Child login route
  router.post('/child-login', async (req, res) => {
    const { username, password } = req.body || {};
    console.log('Received login request body:', req.body);

    if (!username || !password) {
      console.log('Login failed: Missing fields');
      return res.status(400).json({ message: 'Missing fields' });
    }

    try {
      const childCollection = db.collection('child_registration');
      console.log('Searching for child with username:', username);

      // Find child by username
      const child = await childCollection.findOne({ username });
      if (!child) {
        console.log('Login failed: username not found');
        return res.status(401).json({ message: 'Login failed' });
      }

      console.log('Found child:', child);
      console.log('Hashed password from DB:', child.password);

      const isValid = await bcrypt.compare(password, child.password);
      if (!isValid) {
        console.log('Login failed: incorrect password');
        return res.status(401).json({ message: 'Login failed' });
      }

      console.log('Login successful. Child ID:', child._id);
      res.status(200).json({ message: 'Login successful', childId: child._id });
    } catch (error) {
      console.error('Error during child login:', error);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  // Fetch children by parent ID route
  router.get('/get-children/:parentId', async (req, res) => {
    const parentId = req.params.parentId;
    console.log('Received get-children request for parent ID:', parentId);

    try {
      const children = await db.collection('child_profile').find({ parent_id: new ObjectId(parentId) }).toArray();
      console.log('Children retrieved successfully:', children);
      res.status(200).json(children);
    } catch (err) {
      console.error('Error fetching children:', err.message);
      res.status(500).json({ message: 'Internal server error' });
    }
  });

  return router;
};
