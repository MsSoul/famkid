//filename:../server/time_management.js
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots, deviceTime = null) {
  // Use the provided deviceTime if available, otherwise fallback to server time
  const now = deviceTime ? new Date(deviceTime) : new Date();
  const timeSource = deviceTime ? `Device time: ${now.toISOString()}` : `Server time: ${now.toISOString()}`; // Log the source of time

  const updatedTimeSlots = [];

  console.log(`[TIME MANAGEMENT - SYNCING TIME SLOTS STARTS]`);
  console.log(`(${timeSource})\n`);

  console.log(`CHILD ID: ${childId}`);

  for (const slot of timeSlots) {
    const { slot_identifier, start_time, end_time, allowed_time } = slot;

    // Check if slot_identifier is valid, and if not, generate a new ObjectId for it
    const slotIdentifier = slot_identifier ? new ObjectId(slot_identifier) : new ObjectId();

    // Log the details of each slot for debugging
    //console.log(`Time slot details:`, slot);

    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
    
    let remainingTime;

    // Calculate remaining time based on current time
    if (now >= slotStartTime && now <= slotEndTime) {
      remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
    } else if (now < slotStartTime) {
      remainingTime = allowed_time || 0; // Before the slot starts, reset to allowed time
    } else {
      remainingTime = 0; // Slot has ended
    }

    updatedTimeSlots.push({
      slot_identifier: slotIdentifier, // Ensure this is always an ObjectId
      remaining_time: remainingTime,
      start_time: start_time,
      end_time: end_time,
    });

    // Log for each slot with remaining time
    console.log(`  SLOT# : ${slotIdentifier} : REMAINING TIME = ${remainingTime}`);
  }

  // Update the database with the remaining times
  await db.collection('remaining_time').updateOne(
    { child_id: new ObjectId(childId) }, 
    {
      $set: {
        time_slots: updatedTimeSlots,
      },
    },
    { upsert: true }
  );

  console.log(`[SYNCING TIME SLOTS FOR TIME MANAGEMENT COMPLETED]\n`);
}

async function processTimeManagementSlot(db, childId, deviceTime = null) {
  console.log(`[TIME MANAGEMENT] Fetching time management for child ${childId}`);
  const timeManagementDoc = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });

  if (!timeManagementDoc) {
    console.error(`[TIME MANAGEMENT] No time management document found for child ${childId}.`);
    return;
  }

  const timeSlots = timeManagementDoc.time_slots;
  if (!timeSlots || timeSlots.length === 0) {
    console.error(`[TIME MANAGEMENT] No time slots found for child ${childId}.`);
    return;
  }

  await syncTimeSlot(db, childId, timeSlots, deviceTime); 
}

async function checkAndUpdateRemainingTime(db, req = null, res = null) {
  try {
    console.log('[TIME MANAGEMENT] Checking and updating remaining time...');

    // Get the device time from the request query or default to null
    const { deviceTime } = req ? req.query : { deviceTime: null };

    const timeManagementDocs = await db.collection('remaining_time').find().toArray();

    // Iterate through each child document
    for (const doc of timeManagementDocs) {
      const childId = doc.child_id;
      const timeSlots = doc.time_slots;

      if (!timeSlots || timeSlots.length === 0) {
        console.warn(`[TIME MANAGEMENT] No time slots found for child: ${childId}`);
        continue; // Skip if there are no time slots
      }

      // Log the Child ID
      console.log(`Child ID: ${childId}`);

      // Iterate through each time slot for the child
      for (const timeSlot of timeSlots) {
        const slotIdentifier = timeSlot.slot_identifier;
        const startTime = timeSlot.start_time;
        const endTime = timeSlot.end_time;
        const allowedTime = timeSlot.allowed_time || 3600; // Default to 1 hour if not provided

        // Ensure that `slot_identifier`, `start_time`, and `end_time` exist
        if (!slotIdentifier || !startTime || !endTime) {
          console.error(`[TIME MANAGEMENT] Slot identifier or times missing for child ${childId}`);
          continue; // Skip this time slot if any key field is missing
        }

        // Calculate the remaining time based on the device time or current server time
        const now = deviceTime ? new Date(deviceTime) : new Date();
        const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);
        const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
        let remainingTime;

        if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining time in seconds
        } else if (now < slotStartTime) {
          remainingTime = allowedTime; // Before the slot starts
        } else {
          remainingTime = 0; // Slot has ended
        }

        // Log the remaining time for each time slot under the child
        console.log(`  Slot# ${slotIdentifier} : Remaining Time = ${remainingTime}`);
      }
    }

    if (res && res.status) {
      res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.' });
    }
    console.log('[TIME MANAGEMENT] Automatically updated remaining time for all slots.');
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
}



async function getTimeManagement(req, res, db) {
  const { childId } = req.params;
  try {
    console.log(`[TIME MANAGEMENT] Fetching time management data for child ID: ${childId}`);

    const timeManagement = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });
    if (!timeManagement) {
      console.error(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
      return res.status(404).json({ message: 'No time slots found for the specified child.' });
    }

    // Successfully fetched time management
    console.log(`[TIME MANAGEMENT] Time management data retrieved for child ID: ${childId}`);
    res.status(200).json(timeManagement);

  } catch (error) {
    console.error('[TIME MANAGEMENT] Error fetching time management data:', error);
    res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}

async function manualSyncRemainingTime(req, res, db) {
  const { deviceTime } = req.query;  // Accept deviceTime for manual sync
  console.log('[TIME MANAGEMENT] Manual Sync Started');
  try {
    const timeManagementDocs = await db.collection('time_management').find({}).toArray();
    for (const { child_id, time_slots } of timeManagementDocs) {
      if (time_slots && time_slots.length > 0) {
        await syncTimeSlot(db, new ObjectId(child_id), time_slots, deviceTime || new Date()); // Pass device time here
      }
    }
    res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
  } catch (error) {
    console.error('[TIME MANAGEMENT] Manual sync error:', error);
    res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
  }
  console.log('[TIME MANAGEMENT] Manual Sync Ended');
}

async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }
    try {
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;
        const now = new Date();
        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) updatedRemainingTime = 0;
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[TIME MANAGEMENT] Remaining time updated successfully' : '[TIME MANAGEMENT] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;
    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            const slot = remainingTimeDoc.time_slots.find(s => s.slot_identifier.equals(new ObjectId(slotIdentifier)));
            if (slot) {
                return res.status(200).json({ remaining_time: slot.remaining_time });
            } else {
                return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
            }
        } else {
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified child' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function resetRemainingTimes(db) {
    try {
        await db.collection('remaining_time').deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

function watchTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('time_management').watch([], { fullDocument: 'updateLookup' });
    console.log('[TIME MANAGEMENT] Watching time_management collection for changes.');

    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected:', JSON.stringify(change, null, 2));
        
        if (change.operationType === 'update' || change.operationType === 'insert') {
            const { child_id, time_slots } = change.fullDocument;
            await syncTimeSlot(db, new ObjectId(child_id), time_slots);
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Function to start real-time updates at a fixed interval
function startRealTimeUpdates(db, interval = 60 * 1000) {
    console.log(`[TIME MANAGEMENT] Starting real-time updates every ${interval / 1000} seconds.`);

    setInterval(async () => {
        await checkAndUpdateRemainingTime(db);
    }, interval);
}

// Exporting the functions
module.exports = {
    syncTimeSlot,
    startRealTimeUpdates,
    processTimeManagementSlot,
    watchTimeManagementCollection,
    checkAndUpdateRemainingTime,
    manualSyncRemainingTime,
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes
};

/*
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots, deviceTime = null) {
  // Use the provided deviceTime if available, otherwise fallback to server time
  const now = deviceTime ? new Date(deviceTime) : new Date();
  const updatedTimeSlots = [];

  for (const slot of timeSlots) {
    const { slot_identifier, start_time, end_time, allowed_time } = slot;
    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
    
    let remainingTime;

    // Calculate remaining time based on current time
    if (now >= slotStartTime && now <= slotEndTime) {
      remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
    } else if (now < slotStartTime) {
      remainingTime = allowed_time || 0; // Before the slot starts, reset to allowed time
    } else {
      remainingTime = 0; // Slot has ended
    }

    updatedTimeSlots.push({
      slot_identifier: new ObjectId(slot_identifier),
      remaining_time: remainingTime,
      start_time: start_time,
      end_time: end_time,
    });

    console.log(`[TIME MANAGEMENT] Slot ${slot_identifier} for child ${childId}: Remaining time ${remainingTime}`);
  }

  console.log(`[TIME MANAGEMENT] Syncing remaining time for child ${childId} with ${timeSlots.length} slots.`);

  await db.collection('remaining_time').updateOne(
    { child_id: new ObjectId(childId) }, 
    {
      $set: {
        time_slots: updatedTimeSlots,
      },
    },
    { upsert: true }
  );
  console.log(`[TIME MANAGEMENT] Remaining time updated for child ${childId}`);
}

async function processTimeManagementSlot(db, childId, deviceTime = null) {
  console.log(`[TIME MANAGEMENT] Fetching time management for child ${childId}`);
  const timeManagementDoc = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });

  if (!timeManagementDoc) {
    console.error(`[TIME MANAGEMENT] No time management document found for child ${childId}.`);
    return;
  }

  const timeSlots = timeManagementDoc.time_slots;
  if (!timeSlots || timeSlots.length === 0) {
    console.error(`[TIME MANAGEMENT] No time slots found for child ${childId}.`);
    return;
  }

  await syncTimeSlot(db, childId, timeSlots, deviceTime); 
}

async function checkAndUpdateRemainingTime(db, req = null, res = null) {
  try {
    console.log('[TIME MANAGEMENT]\n Checking and updating remaining time...\n');

    // Get the device time from the request query or default to null
    const { deviceTime } = req ? req.query : { deviceTime: null };

    const timeManagementDocs = await db.collection('remaining_time').find().toArray();

    // Iterate through each child document
    for (const doc of timeManagementDocs) {
      const childId = doc.child_id;
      const timeSlots = doc.time_slots;

      if (!timeSlots || timeSlots.length === 0) {
        console.warn(`[TIME MANAGEMENT] No time slots found for child: ${childId}`);
        continue; // Skip if there are no time slots
      }

      // Log the Child ID
      console.log(`Child ID: ${childId}`);

      // Iterate through each time slot for the child
      for (const timeSlot of timeSlots) {
        const slotIdentifier = timeSlot.slot_identifier;
        const startTime = timeSlot.start_time;
        const endTime = timeSlot.end_time;
        const allowedTime = timeSlot.allowed_time || 3600; // Default to 1 hour if not provided

        // Ensure that `slot_identifier`, `start_time`, and `end_time` exist
        if (!slotIdentifier || !startTime || !endTime) {
          console.error(`[TIME MANAGEMENT] Slot identifier or times missing for child ${childId}`);
          continue; // Skip this time slot if any key field is missing
        }

        // Calculate the remaining time based on the device time or current server time
        const now = deviceTime ? new Date(deviceTime) : new Date();
        const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);
        const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
        let remainingTime;

        if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining time in seconds
        } else if (now < slotStartTime) {
          remainingTime = allowedTime; // Before the slot starts
        } else {
          remainingTime = 0; // Slot has ended
        }

        // Log the remaining time for each time slot under the child
        console.log(`     Slot# : ${slotIdentifier} : Remaining Time = ${remainingTime}`);
      }
    }

    if (res && res.status) {
      res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.\n\n' });
    }
    console.log('(================[TIME MANAGEMENT] Automatically Synced all slots================)');
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
}


async function getTimeManagement(req, res, db) {
  const { childId } = req.params;
  try {
      console.log(`[TIME MANAGEMENT] Fetching time management data for child ID: ${childId}`);

      const timeManagement = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });
      if (!timeManagement) {
          console.error(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
          return res.status(404).json({ message: 'No time slots found for the specified child.' });
      }

      // Successfully fetched time management
      console.log(`[TIME MANAGEMENT] Time management data retrieved for child ID: ${childId}`);
      res.status(200).json(timeManagement);

  } catch (error) {
      console.error('[TIME MANAGEMENT] Error fetching time management data:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}


async function manualSyncRemainingTime(req, res, db) {
  const { deviceTime } = req.query;  // Accept deviceTime for manual sync
  console.log('[TIME MANAGEMENT] Manual Sync Started');
  try {
      const timeManagementDocs = await db.collection('time_management').find({}).toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await syncTimeSlot(db, new ObjectId(child_id), time_slots, deviceTime || new Date()); // Pass device time here
          }
      }
      res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
  } catch (error) {
      console.error('[TIME MANAGEMENT] Manual sync error:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
  }
  console.log('[TIME MANAGEMENT] Manual Sync Ended');
}

async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }
    try {
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;
        const now = new Date();
        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) updatedRemainingTime = 0;
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[TIME MANAGEMENT] Remaining time updated successfully' : '[TIME MANAGEMENT] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;
    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            const slot = remainingTimeDoc.time_slots.find(s => s.slot_identifier.equals(new ObjectId(slotIdentifier)));
            if (slot) {
                return res.status(200).json({ remaining_time: slot.remaining_time });
            } else {
                return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
            }
        } else {
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified child' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function resetRemainingTimes(db) {
    try {
        await db.collection('remaining_time').deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

function watchTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('time_management').watch([], { fullDocument: 'updateLookup' });
    console.log('[TIME MANAGEMENT] Watching time_management collection for changes.');

    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected:', JSON.stringify(change, null, 2));
        
        if (change.operationType === 'update' || change.operationType === 'insert') {
            const { child_id, time_slots } = change.fullDocument;
            await syncTimeSlot(db, new ObjectId(child_id), time_slots);
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Function to start real-time updates at a fixed interval
function startRealTimeUpdates(db, interval = 60 * 1000) {
    console.log(`[TIME MANAGEMENT] Starting real-time updates every ${interval / 1000} seconds.`);

    setInterval(async () => {
        await checkAndUpdateRemainingTime(db);
    }, interval);
}

// Exporting the functions
module.exports = {
    startRealTimeUpdates,
    watchTimeManagementCollection,
    checkAndUpdateRemainingTime,
    manualSyncRemainingTime,
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes
};*/
/*const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots, deviceTime = null) {
  // Use the provided deviceTime if available, otherwise fallback to server time
  const now = deviceTime ? new Date(deviceTime) : new Date();
  const updatedTimeSlots = [];

  for (const slot of timeSlots) {
    const { slot_identifier, start_time, end_time, allowed_time } = slot;  // Fetch allowed_time from the slot for calculation purposes
    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
      
    let remainingTime;

    // Calculate remaining time based on current time
    if (now >= slotStartTime && now <= slotEndTime) {
      remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
    } else if (now < slotStartTime) {
      remainingTime = allowed_time || 0; // Before the slot starts, reset to allowed time
    } else {
      remainingTime = 0; // Slot has ended
    }

    updatedTimeSlots.push({
      slot_identifier: new ObjectId(slot_identifier), // Ensure ObjectId is correctly instantiated
      remaining_time: remainingTime,
      start_time: start_time,
      end_time: end_time
      // Removed 'allowed_time' from being saved in the remaining_time collection
    });

    console.log(`[TIME MANAGEMENT] Slot ${slot_identifier} for child ${childId}: Remaining time ${remainingTime}`);
  }

  console.log(`[TIME MANAGEMENT] Syncing remaining time for child ${childId} with ${timeSlots.length} slots.`);

  await db.collection('remaining_time').updateOne(
    { child_id: new ObjectId(childId) }, // Ensure ObjectId is correctly instantiated
    {
      $set: {
        time_slots: updatedTimeSlots // Save the array of time slots without allowed_time
      }
    },
    { upsert: true }
  );
  console.log(`[TIME MANAGEMENT] Remaining time updated for child ${childId}`);
}

async function processTimeManagementSlot(db, childId, deviceTime = null) {
  console.log(`[TIME MANAGEMENT] Fetching time management for child ${childId}`);
  const timeManagementDoc = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });

  if (!timeManagementDoc) {
    console.error(`[TIME MANAGEMENT] No time management document found for child ${childId}.`);
    return;
  }

  const timeSlots = timeManagementDoc.time_slots;
  if (!timeSlots || timeSlots.length === 0) {
    console.error(`[TIME MANAGEMENT] No time slots found for child ${childId}.`);
    return;
  }

  await syncTimeSlot(db, childId, timeSlots, deviceTime); // Pass the entire array of time slots and device time
}

async function checkAndUpdateRemainingTime(db, req = null, res = null) {
  try {
    console.log('[TIME MANAGEMENT] Checking and updating remaining time...');

    // Get the device time from the request query or default to null
    const { deviceTime } = req ? req.query : { deviceTime: null };

    const timeManagementDocs = await db.collection('time_management').find().toArray();
    for (const { child_id, time_slots } of timeManagementDocs) {
      if (time_slots && time_slots.length > 0) {
        await processTimeManagementSlot(db, child_id, deviceTime);  // Pass deviceTime if available
      }
    }

    if (res && res.status) {
      res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.' });
    }
    console.log('[TIME MANAGEMENT] Automatically updated remaining time for all slots.');
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
}

async function manualSyncRemainingTime(req, res, db) {
  const { deviceTime } = req.query;  // Accept deviceTime for manual sync
  console.log('[TIME MANAGEMENT] Manual Sync Started');
  try {
      const timeManagementDocs = await db.collection('time_management').find({}).toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await syncTimeSlot(db, new ObjectId(child_id), time_slots, deviceTime || new Date()); // Pass device time here
          }
      }
      res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
  } catch (error) {
      console.error('[TIME MANAGEMENT] Manual sync error:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
  }
  console.log('[TIME MANAGEMENT] Manual Sync Ended');
}

async function getTimeManagement(req, res, db) {
  const { childId } = req.params;
  try {
      console.log(`[TIME MANAGEMENT] Fetching time management data for child ID: ${childId}`);

      const timeManagement = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });
      if (!timeManagement) {
          console.error(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
          return res.status(404).json({ message: 'No time slots found for the specified child.' });
      }

      // Successfully fetched time management
      console.log(`[TIME MANAGEMENT] Time management data retrieved for child ID: ${childId}`);
      res.status(200).json(timeManagement);

  } catch (error) {
      console.error('[TIME MANAGEMENT] Error fetching time management data:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}

async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }
    try {
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;
        const now = new Date();
        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) updatedRemainingTime = 0;
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[TIME MANAGEMENT] Remaining time updated successfully' : '[TIME MANAGEMENT] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;
    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            const slot = remainingTimeDoc.time_slots.find(s => s.slot_identifier.equals(new ObjectId(slotIdentifier)));
            if (slot) {
                return res.status(200).json({ remaining_time: slot.remaining_time });
            } else {
                return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
            }
        } else {
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified child' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function resetRemainingTimes(db) {
    try {
        await db.collection('remaining_time').deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

function watchTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('time_management').watch([], { fullDocument: 'updateLookup' });
    console.log('[TIME MANAGEMENT] Watching time_management collection for changes.');

    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected:', JSON.stringify(change, null, 2));
        
        if (change.operationType === 'update' || change.operationType === 'insert') {
            const { child_id, time_slots } = change.fullDocument;
            await syncTimeSlot(db, new ObjectId(child_id), time_slots);
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Function to start real-time updates at a fixed interval
function startRealTimeUpdates(db, interval = 60 * 1000) {
    console.log(`[TIME MANAGEMENT] Starting real-time updates every ${interval / 1000} seconds.`);

    setInterval(async () => {
        await checkAndUpdateRemainingTime(db);
    }, interval);
}

// Exporting the functions
module.exports = {
    startRealTimeUpdates,
    watchTimeManagementCollection,
    checkAndUpdateRemainingTime,
    manualSyncRemainingTime,
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes
};
*/
/*
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots) {
  const now = new Date();
  const updatedTimeSlots = [];

  for (const slot of timeSlots) {
      const { slot_identifier, start_time, end_time, allowed_time } = slot;  // Fetch allowed_time from the slot
      const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
      const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
      
      let remainingTime;

      // Calculate remaining time based on current time
      if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
      } else if (now < slotStartTime) {
          remainingTime = allowed_time || 0; // Before the slot starts, reset to allowed time
      } else {
          remainingTime = 0; // Slot has ended
      }

      updatedTimeSlots.push({
          slot_identifier: new ObjectId(slot_identifier), // Ensure ObjectId is correctly instantiated
          remaining_time: remainingTime,
          start_time: start_time,
          end_time: end_time,
          allowed_time: allowed_time  // Add the allowed_time dynamically fetched from time_slots
      });

      console.log(`[TIME MANAGEMENT] Slot ${slot_identifier} for child ${childId}: Remaining time ${remainingTime}`);
  }

  console.log(`[TIME MANAGEMENT] Syncing remaining time for child ${childId} with ${timeSlots.length} slots.`);

  await db.collection('remaining_time').updateOne(
      { child_id: new ObjectId(childId) }, // Ensure ObjectId is correctly instantiated
      {
          $set: {
              time_slots: updatedTimeSlots // Save the array of time slots
          }
      },
      { upsert: true }
  );
  console.log(`[TIME MANAGEMENT] Remaining time updated for child ${childId}`);
}

async function processTimeManagementSlot(db, childId) {
  console.log(`[TIME MANAGEMENT] Fetching time management for child ${childId}`);
  const timeManagementDoc = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });

  if (!timeManagementDoc) {
      console.error(`[TIME MANAGEMENT] No time management document found for child ${childId}.`);
      return;
  }

  const timeSlots = timeManagementDoc.time_slots;
  if (!timeSlots || timeSlots.length === 0) {
      console.error(`[TIME MANAGEMENT] No time slots found for child ${childId}.`);
      return;
  }

  await syncTimeSlot(db, childId, timeSlots); // Pass the entire array of time slots
}

async function checkAndUpdateRemainingTime(db, res = null) {
  try {
      console.log('[TIME MANAGEMENT] Checking and updating remaining time...');
      const timeManagementDocs = await db.collection('time_management').find().toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await processTimeManagementSlot(db, child_id);  // Ensure child_id is processed
          }
      }

      if (res && res.status) {
          res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.' });
      }
      console.log('[TIME MANAGEMENT] Automatically updated remaining time for all slots.');
  } catch (error) {
      console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
      if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
}


async function manualSyncRemainingTime(req, res, db) {
  console.log('[TIME MANAGEMENT] Manual Sync Started');
  try {
      const timeManagementDocs = await db.collection('time_management').find({}).toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await syncTimeSlot(db, new ObjectId(child_id), time_slots); // Ensure ObjectId is correctly instantiated
          }
      }
      res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
  } catch (error) {
      console.error('[TIME MANAGEMENT] Manual sync error:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
  }
  console.log('[TIME MANAGEMENT] Manual Sync Ended');
}

async function getTimeManagement(req, res, db) {
  const { childId } = req.params;
  try {
      console.log(`[TIME MANAGEMENT] Fetching time management data for child ID: ${childId}`);

      const timeManagement = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });
      if (!timeManagement) {
          console.error(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
          return res.status(404).json({ message: 'No time slots found for the specified child.' });
      }

      // Successfully fetched time management
      console.log(`[TIME MANAGEMENT] Time management data retrieved for child ID: ${childId}`);
      res.status(200).json(timeManagement);

  } catch (error) {
      console.error('[TIME MANAGEMENT] Error fetching time management data:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}


async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }
    try {
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;
        const now = new Date();
        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) updatedRemainingTime = 0;
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[TIME MANAGEMENT] Remaining time updated successfully' : '[TIME MANAGEMENT] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;
    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            const slot = remainingTimeDoc.time_slots.find(s => s.slot_identifier.equals(new ObjectId(slotIdentifier)));
            if (slot) {
                return res.status(200).json({ remaining_time: slot.remaining_time });
            } else {
                return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
            }
        } else {
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified child' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function resetRemainingTimes(db) {
    try {
        await db.collection('remaining_time').deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

function watchTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('time_management').watch([], { fullDocument: 'updateLookup' });
    console.log('[TIME MANAGEMENT] Watching time_management collection for changes.');

    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected:', JSON.stringify(change, null, 2));
        
        if (change.operationType === 'update' || change.operationType === 'insert') {
            const { child_id, time_slots } = change.fullDocument;
            await syncTimeSlot(db, new ObjectId(child_id), time_slots);
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Function to start real-time updates at a fixed interval
function startRealTimeUpdates(db, interval = 60 * 1000) {
    console.log(`[TIME MANAGEMENT] Starting real-time updates every ${interval / 1000} seconds.`);

    setInterval(async () => {
        await checkAndUpdateRemainingTime(db);
    }, interval);
}

// Exporting the functions
module.exports = {
    startRealTimeUpdates,
    watchTimeManagementCollection,
    checkAndUpdateRemainingTime,
    manualSyncRemainingTime,
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes
};

*/
/*
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots) {
  const now = new Date();
  const updatedTimeSlots = [];

  for (const slot of timeSlots) {
      const { slot_identifier, start_time, end_time, allowed_time = 3600 } = slot;
      const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
      const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
      
      let remainingTime;

      // Calculate remaining time based on current time
      if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
      } else if (now < slotStartTime) {
          remainingTime = allowed_time; // Before the slot starts, reset to allowed time
      } else {
          remainingTime = 0; // Slot has ended
      }

      updatedTimeSlots.push({
          slot_identifier: new ObjectId(slot_identifier), // Ensure ObjectId is correctly instantiated
          remaining_time: remainingTime,
          start_time: start_time,
          end_time: end_time
      });

      console.log(`[TIME MANAGEMENT] Slot ${slot_identifier} for child ${childId}: Remaining time ${remainingTime}`);
  }

  console.log(`[TIME MANAGEMENT] Syncing remaining time for child ${childId} with ${timeSlots.length} slots.`);

  await db.collection('remaining_time').updateOne(
      { child_id: new ObjectId(childId) }, // Ensure ObjectId is correctly instantiated
      {
          $set: {
              time_slots: updatedTimeSlots // Save the array of time slots
          }
      },
      { upsert: true }
  );
  console.log(`[TIME MANAGEMENT] Remaining time updated for child ${childId}`);
}

async function processTimeManagementSlot(db, childId) {
  console.log(`[TIME MANAGEMENT] Fetching time management for child ${childId}`);
  const timeManagementDoc = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });

  if (!timeManagementDoc) {
      console.error(`[TIME MANAGEMENT] No time management document found for child ${childId}.`);
      return;
  }

  const timeSlots = timeManagementDoc.time_slots;
  if (!timeSlots || timeSlots.length === 0) {
      console.error(`[TIME MANAGEMENT] No time slots found for child ${childId}.`);
      return;
  }

  await syncTimeSlot(db, childId, timeSlots); // Pass the entire array of time slots
}

async function checkAndUpdateRemainingTime(db, res = null) {
  try {
      console.log('[TIME MANAGEMENT] Checking and updating remaining time...');
      const timeManagementDocs = await db.collection('time_management').find().toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await processTimeManagementSlot(db, child_id);  // Ensure child_id is processed
          }
      }

      if (res && res.status) {
          res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.' });
      }
      console.log('[TIME MANAGEMENT] Automatically updated remaining time for all slots.');
  } catch (error) {
      console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
      if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
}


async function manualSyncRemainingTime(req, res, db) {
  console.log('[TIME MANAGEMENT] Manual Sync Started');
  try {
      const timeManagementDocs = await db.collection('time_management').find({}).toArray();
      for (const { child_id, time_slots } of timeManagementDocs) {
          if (time_slots && time_slots.length > 0) {
              await syncTimeSlot(db, new ObjectId(child_id), time_slots); // Ensure ObjectId is correctly instantiated
          }
      }
      res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
  } catch (error) {
      console.error('[TIME MANAGEMENT] Manual sync error:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
  }
  console.log('[TIME MANAGEMENT] Manual Sync Ended');
}

async function getTimeManagement(req, res, db) {
  const { childId } = req.params;
  try {
      console.log(`[TIME MANAGEMENT] Fetching time management data for child ID: ${childId}`);

      const timeManagement = await db.collection('time_management').findOne({ child_id: new ObjectId(childId) });
      if (!timeManagement) {
          console.error(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
          return res.status(404).json({ message: 'No time slots found for the specified child.' });
      }

      // Successfully fetched time management
      console.log(`[TIME MANAGEMENT] Time management data retrieved for child ID: ${childId}`);
      res.status(200).json(timeManagement);

  } catch (error) {
      console.error('[TIME MANAGEMENT] Error fetching time management data:', error);
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}


async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }
    try {
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;
        const now = new Date();
        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) updatedRemainingTime = 0;
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[TIME MANAGEMENT] Remaining time updated successfully' : '[TIME MANAGEMENT] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;
    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            const slot = remainingTimeDoc.time_slots.find(s => s.slot_identifier.equals(new ObjectId(slotIdentifier)));
            if (slot) {
                return res.status(200).json({ remaining_time: slot.remaining_time });
            } else {
                return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
            }
        } else {
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified child' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

async function resetRemainingTimes(db) {
    try {
        await db.collection('remaining_time').deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

function watchTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('time_management').watch([], { fullDocument: 'updateLookup' });
    console.log('[TIME MANAGEMENT] Watching time_management collection for changes.');

    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected:', JSON.stringify(change, null, 2));
        
        if (change.operationType === 'update' || change.operationType === 'insert') {
            const { child_id, time_slots } = change.fullDocument;
            await syncTimeSlot(db, new ObjectId(child_id), time_slots);
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Function to start real-time updates at a fixed interval
function startRealTimeUpdates(db, interval = 60 * 1000) {
    console.log(`[TIME MANAGEMENT] Starting real-time updates every ${interval / 1000} seconds.`);

    setInterval(async () => {
        await checkAndUpdateRemainingTime(db);
    }, interval);
}

// Exporting the functions
module.exports = {
    startRealTimeUpdates,
    watchTimeManagementCollection,
    checkAndUpdateRemainingTime,
    manualSyncRemainingTime,
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes
};
*/
/*old time management
//(correct calculation of remainining)
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function checkAndUpdateRemainingTime(db, res = null) {
  let errorOccurred = false;

  try {
      const timeSlots = await db.collection('remaining_time').find().toArray();

      for (const timeSlot of timeSlots) {
          const slotIdentifier = timeSlot.slot_identifier;
          const allowedTime = timeSlot.allowed_time || 3600;
          const childId = timeSlot.child_id;

          const timeManagementDoc = await db.collection('time_management').findOne({
              child_id: childId,
              "time_slots.slot_identifier": slotIdentifier
          });

          if (!timeManagementDoc) {
              console.error(`[TIME MANAGEMENT] No time management document found for child ${childId} and slot ${slotIdentifier}.`);
              errorOccurred = true;
              continue;
          }

          const timeSlotFromManagement = timeManagementDoc.time_slots.find(slot => slot.slot_identifier.equals(slotIdentifier));
          if (!timeSlotFromManagement || !timeSlotFromManagement.start_time || !timeSlotFromManagement.end_time) {
              console.error(`[TIME MANAGEMENT] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
              errorOccurred = true;
              continue;
          }

          const startTime = timeSlotFromManagement.start_time;
          const endTime = timeSlotFromManagement.end_time;

          const now = new Date();
          const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
          const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

          let remainingTime;

          if (now >= slotStartTime && now <= slotEndTime) {
              remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60;
          } else if (now < slotStartTime) {
              remainingTime = allowedTime;
          } else {
              remainingTime = 0;
          }

          try {
              await db.collection('remaining_time').updateOne(
                  { slot_identifier: slotIdentifier },
                  {
                      $set: {
                          remaining_time: remainingTime,
                          start_time: startTime,
                          end_time: endTime,
                          timestamp: now
                      }
                  }
              );
              console.log(`[TIME MANAGEMENT] slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId} Synced.`);
          } catch (updateError) {
              console.error(`[TIME MANAGEMENT] Error updating remaining time for slot ${slotIdentifier}:`, updateError);
              errorOccurred = true;
          }
      }

      if (res && res.status) {
          if (errorOccurred) {
              res.status(500).json({ message: '[TIME MANAGEMENT] Errors occurred during update.' });
          } else {
              res.status(200).json({ message: '[TIME MANAGEMENT] AUTOMATICALLY UPDATED.' });
          }
      } else {
          if (errorOccurred) {
              console.log('\n[TIME MANAGEMENT] Errors occurred during update.\n');
          } else {
              console.log('\n[TIME MANAGEMENT] AUTOMATICALLY UPDATED.\n');
          }
      }
  } catch (error) {
      console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
      if (res && res.status) {
          res.status(500).json({ message: '[TIME MANAGEMENT] Internal error during update.', error: error.message });
      }
  }
}


async function manualSyncRemainingTime(req, res, db) {
    console.log('\n====================[TIME MANAGEMENT] Manual Sync Start====================\n');

    try {
        const timeManagementCollection = db.collection('time_management');
        const remainingTimeCollection = db.collection('remaining_time');

        const timeManagementDocs = await timeManagementCollection.find({}).toArray();

        for (const doc of timeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;

            for (const slot of timeSlots) {
                const slotIdentifier = slot.slot_identifier;
                const allowedTime = slot.allowed_time || 3600;
                const endTime = slot.end_time;
                const startTime = slot.start_time;

                if (!startTime || !endTime) {
                    console.error(`[TIME MANAGEMENT] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                    continue;
                }

                const now = new Date();
                const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
                const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

                let remainingTime;

                if (now >= slotStartTime && now <= slotEndTime) {
                    remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60;
                } else if (now < slotStartTime) {
                    remainingTime = allowedTime;
                } else {
                    remainingTime = 0;
                }

                await remainingTimeCollection.updateOne(
                    { child_id: childId, slot_identifier: slotIdentifier },
                    {
                        $set: {
                            remaining_time: remainingTime,
                            start_time: startTime,
                            end_time: endTime,
                            timestamp: new Date()
                        }
                    },
                    { upsert: true }
                );
                console.log(`[TIME MANAGEMENT] Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
            }
        }

        if (res && res.status) {
            res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Manual sync error:', error);
        if (res && res.status) {
            res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
        }
    }
    console.log('====================[TIME MANAGEMENT] Manual Sync End====================\n');
}

// Time management route
async function getTimeManagement(req, res, db) {
    console.log('[TIME MANAGEMENT] getTimeManagement function called');
    const childId = req.params.childId;
    console.log('[TIME MANAGEMENT] Received time management request for child ID:', childId);

    try {
        const timeManagement = await db.collection('time_management').findOne({ child_id: toObjectId(childId) });
        if (!timeManagement) {
            console.log('[TIME MANAGEMENT] No time slots found for the specified child.');
            return res.status(404).json({ message: 'No time slots found for the specified child.' });
        }

        console.log('[TIME MANAGEMENT] Time management data retrieved successfully:', timeManagement);
        res.status(200).json(timeManagement);
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching time management data:', error.message);
        res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

// Route to update the remaining time in the database
async function updateRemainingTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;

    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const now = new Date();
        const timeSlot = await db.collection('time_management').findOne(
            { child_id: toObjectId(childId), "time_slots.slot_identifier": toObjectId(slotIdentifier) },
            { projection: { "time_slots.$": 1 } }
        );

        let updatedRemainingTime = remainingTime;

        if (timeSlot) {
            const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
            if (now > endTime) {
                updatedRemainingTime = 0;
            }
        }

        const result = await db.collection('remaining_time').updateOne(
            { child_id: toObjectId(childId), slot_identifier: toObjectId(slotIdentifier) },
            {
                $set: {
                    remaining_time: updatedRemainingTime,
                    timestamp: new Date()
                }
            },
            { upsert: true }
        );

        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
            console.log('[TIME MANAGEMENT] Remaining time updated successfully');
            return res.status(200).json({ message: '[TIME MANAGEMENT] Remaining time updated successfully' });
        } else {
            return res.status(500).json({ message: '[TIME MANAGEMENT] Failed to update remaining time' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

// Route to fetch the remaining time from the database
async function getRemainingTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;

    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
    }

    try {
        const remainingTimeDoc = await db.collection('remaining_time').findOne({
            child_id: toObjectId(childId),
            slot_identifier: toObjectId(slotIdentifier)
        });

        if (remainingTimeDoc) {
            console.log('[TIME MANAGEMENT] Remaining time retrieved successfully:', remainingTimeDoc);
            return res.status(200).json({ remaining_time: remainingTimeDoc.remaining_time });
        } else {
            console.log('[TIME MANAGEMENT] No remaining time found for the specified slot');
            return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
        return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
    }
}

// Function to reset remaining time collections at midnight
async function resetRemainingTimes(db) {
    try {
        const remainingTimeCollection = db.collection('remaining_time');
        await remainingTimeCollection.deleteMany({});
        console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
    } catch (error) {
        console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
    }
}

// Watch the time_management collection for changes and update remaining_time accordingly
function watchTimeManagementCollection(db, broadcastUpdate) {
    const timeManagementCollection = db.collection('time_management');
    const changeStream = timeManagementCollection.watch([], { fullDocument: 'updateLookup' });
    
    changeStream.on('change', async (change) => {
        console.log('[TIME MANAGEMENT] Change detected in time_management:', JSON.stringify(change, null, 2));

        if (change.operationType === 'update' || change.operationType === 'insert') {
            const fullDocument = change.fullDocument;
            const childId = fullDocument.child_id;
            const timeSlots = fullDocument.time_slots;

            for (const slot of timeSlots) {
                const slotIdentifier = slot.slot_identifier;
                const allowedTime = slot.allowed_time;
                const endTime = slot.end_time;
                console.log(`[TIME MANAGEMENT] Processing slot: ${slotIdentifier}, Allowed time: ${allowedTime}, End time: ${endTime}`);
                await addRemainingTimeForNewSlot(db, toObjectId(childId), toObjectId(slotIdentifier), allowedTime, endTime);
                broadcastUpdate(slotIdentifier, allowedTime);
            }
        }
    });

    changeStream.on('error', (error) => {
        console.error('[TIME MANAGEMENT] Error in change stream:', error);
    });

    changeStream.on('end', () => {
        console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
        watchTimeManagementCollection(db, broadcastUpdate);
    });
}

// Exporting the functions
module.exports = {
    getTimeManagement,
    updateRemainingTime,
    getRemainingTime,
    resetRemainingTimes,
    watchTimeManagementCollection,
    manualSyncRemainingTime,
    checkAndUpdateRemainingTime  
};
*/

/*09/15/24

const { MongoClient, ObjectId } = require('mongodb');
const { exec } = require('child_process');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

// Function to get the device time (Android)
function getDeviceTime(callback) {
  exec('adb shell date "+%Y-%m-%d %H:%M:%S"', (error, stdout, stderr) => {
    if (error) {
      console.error(`[TIME MANAGEMENT] Error fetching Android device time: ${error.message}`);
      return callback(new Date()); // Fallback to current system time if there's an error
    }
    console.log(`[TIME MANAGEMENT] Fetched Android device time: ${stdout.trim()}`);
    callback(new Date(stdout.trim())); // Convert the device time to a Date object
  });
}

// Function to check and update remaining time
// Function to check and update remaining time
// Function to check and update remaining time
async function checkAndUpdateRemainingTime(db, res = null) {
  let errorOccurred = false;
  let androidDeviceTime = null; // Variable to store Android device time

  try {
    const timeSlots = await db.collection('remaining_time').find().toArray();

    // Fetch the Android device time only once
    getDeviceTime(async (deviceTime) => {
      androidDeviceTime = deviceTime; // Store the fetched Android device time
      let logMessages = `\n\n[**AUTO SYNC TIME MANAGEMENT**] Time sync completed. \n(Fetched Android device time: ${androidDeviceTime.toISOString().split('T')[0]})\n\n`;

      for (const timeSlot of timeSlots) {
        const slotIdentifier = timeSlot.slot_identifier;
        const allowedTime = timeSlot.allowed_time || 3600;
        const childId = timeSlot.child_id;

        const timeManagementDoc = await db.collection('time_management').findOne({
          child_id: childId,
          "time_slots.slot_identifier": slotIdentifier
        });

        if (!timeManagementDoc) {
          logMessages += `[TIME MANAGEMENT] No time management document found for child ${childId} and slot ${slotIdentifier}.\n`;
          errorOccurred = true;
          continue;
        }

        const timeSlotFromManagement = timeManagementDoc.time_slots.find(slot => slot.slot_identifier.equals(slotIdentifier));
        if (!timeSlotFromManagement || !timeSlotFromManagement.start_time || !timeSlotFromManagement.end_time) {
          logMessages += `[TIME MANAGEMENT] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.\n`;
          errorOccurred = true;
          continue;
        }

        const startTime = timeSlotFromManagement.start_time;
        const endTime = timeSlotFromManagement.end_time;
        const now = androidDeviceTime; // Use the fetched Android device time
        const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
        const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

        let remainingTime;
        const deviceStatus = await db.collection('device_status').findOne({ child_id: childId });

        if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60;

          if (remainingTime > 0 && deviceStatus && deviceStatus.is_locked) {
            await unlockDevice(db, childId);
            logMessages += `[TIME MANAGEMENT] Device unlocked for child ${childId}\n`;
          }
        } else if (now < slotStartTime) {
          remainingTime = allowedTime;
        } else {
          remainingTime = 0;

          if (remainingTime === 0 && (!deviceStatus || !deviceStatus.is_locked)) {
            await lockDevice(db, childId);
            logMessages += `[TIME MANAGEMENT] Device locked for child ${childId}\n`;
          }
        }

        try {
          await db.collection('remaining_time').updateOne(
            { slot_identifier: slotIdentifier },
            {
              $set: {
                remaining_time: remainingTime,
                start_time: startTime,
                end_time: endTime,
                timestamp: now
              }
            }
          );
          logMessages += `[TIME MANAGEMENT] Slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId} synced.\n`;
        } catch (updateError) {
          logMessages += `[TIME MANAGEMENT] Error updating remaining time for slot ${slotIdentifier}: ${updateError}\n`;
          errorOccurred = true;
        }
      }

      // Log all collected messages after syncing is complete
      if (errorOccurred) {
        console.error(logMessages);
      } else {
        console.log(logMessages);
      }

      if (res && res.status) {
        if (errorOccurred) {
          res.status(500).json({ message: '[TIME MANAGEMENT] Errors occurred during update.' });
        } else {
          res.status(200).json({ message: '[TIME MANAGEMENT] AUTOMATICALLY UPDATED.' });
        }
      }
    });
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) {
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal error during update.', error: error.message });
    }
  }
}


// Function to lock a device (Android)
async function lockDevice(db, childId) {
  console.log(`[TIME MANAGEMENT] Locking device for child ${childId}`);
  try {
    // Update the device status in the database
    await db.collection('device_status').updateOne(
      { child_id: childId },
      { $set: { is_locked: true } },
      { upsert: true }
    );
    console.log(`[TIME MANAGEMENT] Device status updated for child ${childId}`);

    // Lock the Android device using adb
    lockAndroidDevice();
  } catch (error) {
    console.error(`[TIME MANAGEMENT] Error locking device for child ${childId}:`, error);
  }
}

// Function to unlock a device (Android)
async function unlockDevice(db, childId) {
  console.log(`[TIME MANAGEMENT] Unlocking device for child ${childId}`);
  try {
    // Update the device status in the database
    await db.collection('device_status').updateOne(
      { child_id: childId },
      { $set: { is_locked: false } },
      { upsert: true }
    );
    console.log(`[TIME MANAGEMENT] Device status updated for child ${childId}`);

    // Unlock the Android device using adb
    unlockAndroidDevice();
  } catch (error) {
    console.error(`[TIME MANAGEMENT] Error unlocking device for child ${childId}:`, error);
  }
}

// Lock Android Device (Emulator or ADB)
function lockAndroidDevice() {
  console.log(`[TIME MANAGEMENT] Locking Android device using ADB`);
  exec('adb shell input keyevent 26', (error, stdout, stderr) => {
    if (error) {
      console.error(`[TIME MANAGEMENT] Error locking Android device: ${error.message}`);
      return;
    }
    console.log(`[TIME MANAGEMENT] Android device locked: ${stdout}`);
  });
}

// Unlock Android Device (Emulator or ADB)
function unlockAndroidDevice() {
  console.log(`[TIME MANAGEMENT] Unlocking Android device using ADB`);
  exec('adb shell input keyevent 82', (error, stdout, stderr) => {
    if (error) {
      console.error(`[TIME MANAGEMENT] Error unlocking Android device: ${error.message}`);
      return;
    }
    console.log(`[TIME MANAGEMENT] Android device unlocked: ${stdout}`);
  });
}

// Exporting the functions
module.exports = {
  checkAndUpdateRemainingTime,
  lockDevice,
  unlockDevice
};
*/
/*

const { MongoClient, ObjectId } = require('mongodb');
const { exec } = require('child_process');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function checkAndUpdateRemainingTime(db, res = null) {
  let errorOccurred = false;

  try {
    const timeSlots = await db.collection('remaining_time').find().toArray();

    for (const timeSlot of timeSlots) {
      const slotIdentifier = timeSlot.slot_identifier;
      const allowedTime = timeSlot.allowed_time || 3600;
      const childId = timeSlot.child_id;

      const timeManagementDoc = await db.collection('time_management').findOne({
        child_id: childId,
        "time_slots.slot_identifier": slotIdentifier
      });

      if (!timeManagementDoc) {
        console.error(`[TIME MANAGEMENT] No time management document found for child ${childId} and slot ${slotIdentifier}.`);
        errorOccurred = true;
        continue;
      }

      const timeSlotFromManagement = timeManagementDoc.time_slots.find(slot => slot.slot_identifier.equals(slotIdentifier));
      if (!timeSlotFromManagement || !timeSlotFromManagement.start_time || !timeSlotFromManagement.end_time) {
        console.error(`[TIME MANAGEMENT] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
        errorOccurred = true;
        continue;
      }

      const startTime = timeSlotFromManagement.start_time;
      const endTime = timeSlotFromManagement.end_time;

      const now = new Date();
      const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
      const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

      let remainingTime;
      const deviceStatus = await db.collection('device_status').findOne({ child_id: childId });

      if (now >= slotStartTime && now <= slotEndTime) {
        // Calculate the remaining time in seconds
        remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60;

        // Unlock the device only if it's currently locked and remaining_time is > 0
        if (remainingTime > 0 && deviceStatus && deviceStatus.is_locked) {
          await unlockDevice(db, childId, timeManagementDoc.platform);
          console.log(`[TIME MANAGEMENT] Device unlocked for child ${childId}`);
        }
      } else if (now < slotStartTime) {
        // If current time is before the slot's start time, reset the remaining time
        remainingTime = allowedTime;
      } else {
        remainingTime = 0; // If the slot has ended, set remaining time to 0

        // Lock the device only if it's currently unlocked and the remaining time has reached 0
        if (remainingTime === 0 && (!deviceStatus || !deviceStatus.is_locked)) {
          await lockDevice(db, childId, timeManagementDoc.platform);
          console.log(`[TIME MANAGEMENT] Device locked for child ${childId}`);
        }
      }

      try {
        await db.collection('remaining_time').updateOne(
          { slot_identifier: slotIdentifier },
          {
            $set: {
              remaining_time: remainingTime,
              start_time: startTime,
              end_time: endTime,
              timestamp: now
            }
          }
        );
        console.log(`[TIME MANAGEMENT] Slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId} Synced.`);
      } catch (updateError) {
        console.error(`[TIME MANAGEMENT] Error updating remaining time for slot ${slotIdentifier}:`, updateError);
        errorOccurred = true;
      }
    }

    if (res && res.status) {
      if (errorOccurred) {
        res.status(500).json({ message: '[TIME MANAGEMENT] Errors occurred during update.' });
      } else {
        res.status(200).json({ message: '[TIME MANAGEMENT] AUTOMATICALLY UPDATED.' });
      }
    } else {
      if (errorOccurred) {
        console.log('\n[TIME MANAGEMENT] Errors occurred during update.\n');
      } else {
        console.log('\n[TIME MANAGEMENT] AUTOMATICALLY UPDATED.\n');
      }
    }
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) {
      res.status(500).json({ message: '[TIME MANAGEMENT] Internal error during update.', error: error.message });
    }
  }
}
// Function to lock a device (Android)
async function lockDevice(db, childId, platform) {
  console.log(`[TIME MANAGEMENT] Locking device for child ${childId}`);
  try {
    // Update the device status in the database
    await db.collection('device_status').updateOne(
      { child_id: childId },
      { $set: { is_locked: true } },
      { upsert: true }
    );
    console.log(`[TIME MANAGEMENT] Device status updated for child ${childId}`);

    // Lock the Android device using adb if the platform is Android
    if (platform === 'android') {
      lockAndroidDevice();
    } else if (platform === 'ios') {
      lockIOSDevice(); // Placeholder for iOS MDM
    }
  } catch (error) {
    console.error(`[TIME MANAGEMENT] Error locking device for child ${childId}:`, error);
  }
}

// Function to unlock a device (Android)
async function unlockDevice(db, childId, platform) {
  console.log(`[TIME MANAGEMENT] Unlocking device for child ${childId}`);
  try {
    // Update the device status in the database
    await db.collection('device_status').updateOne(
      { child_id: childId },
      { $set: { is_locked: false } },
      { upsert: true }
    );
    console.log(`[TIME MANAGEMENT] Device status updated for child ${childId}`);

    // Unlock the Android device using adb if the platform is Android
    if (platform === 'android') {
      unlockAndroidDevice();
    } else if (platform === 'ios') {
      unlockIOSDevice(); // Placeholder for iOS MDM
    }
  } catch (error) {
    console.error(`[TIME MANAGEMENT] Error unlocking device for child ${childId}:`, error);
  }
}

// Lock Android Device (Emulator or ADB)
function lockAndroidDevice() {
  console.log(`[TIME MANAGEMENT] Locking Android device using ADB`);
  exec('adb shell input keyevent 26', (error, stdout, stderr) => {
    if (error) {
      console.error(`[TIME MANAGEMENT] Error locking Android device: ${error.message}`);
      return;
    }
    console.log(`[TIME MANAGEMENT] Android device locked: ${stdout}`);
  });
}

// Unlock Android Device (Emulator or ADB)
function unlockAndroidDevice() {
  console.log(`[TIME MANAGEMENT] Unlocking Android device using ADB`);
  exec('adb shell input keyevent 82', (error, stdout, stderr) => {
    if (error) {
      console.error(`[TIME MANAGEMENT] Error unlocking Android device: ${error.message}`);
      return;
    }
    console.log(`[TIME MANAGEMENT] Android device unlocked: ${stdout}`);
  });
}

// Placeholder for iOS MDM Locking (Add your MDM logic here)
function lockIOSDevice() {
  console.log(`[TIME MANAGEMENT] Locking iOS device via MDM`);
  // Here you'd call your MDM API to lock the iOS device
  // Example: sendDeviceLockCommandToMDM(iOSDeviceId);
}

// Placeholder for iOS MDM Unlocking (Add your MDM logic here)
function unlockIOSDevice() {
  console.log(`[TIME MANAGEMENT] Unlocking iOS device via MDM`);
  // Here you'd call your MDM API to unlock the iOS device
}
// Function to parse the time string
function parseTime(timeString) {
  const [hour, minute] = timeString.split(':').map(Number);
  return { hour, minute };
}

// Time management route
async function getTimeManagement(req, res, db) {
  console.log('[TIME MANAGEMENT] getTimeManagement function called');
  const childId = req.params.childId;
  console.log('[TIME MANAGEMENT] Received time management request for child ID:', childId);

  try {
    const timeManagement = await db.collection('time_management').findOne({ child_id: ObjectId(childId) });
    if (!timeManagement) {
      console.log('[TIME MANAGEMENT] No time slots found for the specified child.');
      return res.status(404).json({ message: 'No time slots found for the specified child.' });
    }

    console.log('[TIME MANAGEMENT] Time management data retrieved successfully:', timeManagement);
    res.status(200).json(timeManagement);
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error fetching time management data:', error.message);
    res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}

async function manualSyncRemainingTime(req, res, db) {
    console.log('\n====================[TIME MANAGEMENT] Manual Sync Start====================\n');

    try {
        const timeManagementCollection = db.collection('time_management');
        const remainingTimeCollection = db.collection('remaining_time');

        const timeManagementDocs = await timeManagementCollection.find({}).toArray();

        for (const doc of timeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;

            for (const slot of timeSlots) {
                const slotIdentifier = slot.slot_identifier;
                const allowedTime = slot.allowed_time || 3600;
                const endTime = slot.end_time;
                const startTime = slot.start_time;

                if (!startTime || !endTime) {
                    console.error(`[TIME MANAGEMENT] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                    continue;
                }

                const now = new Date();
                const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
                const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

                let remainingTime;

                if (now >= slotStartTime && now <= slotEndTime) {
                    remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60;
                } else if (now < slotStartTime) {
                    remainingTime = allowedTime;
                } else {
                    remainingTime = 0;
                }

                await remainingTimeCollection.updateOne(
                    { child_id: childId, slot_identifier: slotIdentifier },
                    {
                        $set: {
                            remaining_time: remainingTime,
                            start_time: startTime,
                            end_time: endTime,
                            timestamp: new Date()
                        }
                    },
                    { upsert: true }
                );
                console.log(`[TIME MANAGEMENT] Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
            }
        }

        if (res && res.status) {
            res.status(200).json({ message: '[TIME MANAGEMENT] Manual sync completed successfully.' });
        }
    } catch (error) {
        console.error('[TIME MANAGEMENT] Manual sync error:', error);
        if (res && res.status) {
            res.status(500).json({ message: '[TIME MANAGEMENT] Manual sync failed.', error: error.message });
        }
    }
    console.log('====================[TIME MANAGEMENT] Manual Sync End====================\n');
}

// Route to update the remaining time in the database
async function updateRemainingTime(req, res, db) {
  const { childId, slotIdentifier, remainingTime } = req.body;

  if (!childId || !slotIdentifier || remainingTime === undefined) {
    return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
  }

  try {
    const now = new Date();
    const timeSlot = await db.collection('time_management').findOne(
      { child_id: ObjectId(childId), "time_slots.slot_identifier": ObjectId(slotIdentifier) },
      { projection: { "time_slots.$": 1 } }
    );

    let updatedRemainingTime = remainingTime;

    if (timeSlot) {
      const endTime = new Date(`${now.toDateString()} ${timeSlot.time_slots[0].end_time}`);
      if (now > endTime) {
        updatedRemainingTime = 0;
      }
    }

    const result = await db.collection('remaining_time').updateOne(
      { child_id: ObjectId(childId), slot_identifier: ObjectId(slotIdentifier) },
      {
        $set: {
          remaining_time: updatedRemainingTime,
          timestamp: new Date()
        }
      },
      { upsert: true }
    );

    if (result.modifiedCount > 0 || result.upsertedCount > 0) {
      console.log('[TIME MANAGEMENT] Remaining time updated successfully');
      return res.status(200).json({ message: '[TIME MANAGEMENT] Remaining time updated successfully' });
    } else {
      return res.status(500).json({ message: '[TIME MANAGEMENT] Failed to update remaining time' });
    }
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error updating remaining time:', error);
    return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}

// Route to fetch the remaining time from the database
async function getRemainingTime(req, res, db) {
  const { childId, slotIdentifier } = req.query;

  if (!childId || !slotIdentifier) {
    return res.status(400).json({ message: '[TIME MANAGEMENT] Missing required fields' });
  }

  try {
    const remainingTimeDoc = await db.collection('remaining_time').findOne({
      child_id: ObjectId(childId),
      slot_identifier: ObjectId(slotIdentifier)
    });

    if (remainingTimeDoc) {
      console.log('[TIME MANAGEMENT] Remaining time retrieved successfully:', remainingTimeDoc);
      return res.status(200).json({ remaining_time: remainingTimeDoc.remaining_time });
    } else {
      console.log('[TIME MANAGEMENT] No remaining time found for the specified slot');
      return res.status(404).json({ message: '[TIME MANAGEMENT] No remaining time found for the specified slot' });
    }
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error fetching remaining time:', error);
    return res.status(500).json({ message: '[TIME MANAGEMENT] Internal server error' });
  }
}

// Function to reset remaining time collections at midnight
async function resetRemainingTimes(db) {
  try {
    const remainingTimeCollection = db.collection('remaining_time');
    await remainingTimeCollection.deleteMany({});
    console.log('[TIME MANAGEMENT] Remaining time collection reset successfully at midnight.');
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error resetting remaining time collections:', error);
  }
}

// Watch the time_management collection for changes and update remaining_time accordingly
function watchTimeManagementCollection(db, broadcastUpdate) {
  const timeManagementCollection = db.collection('time_management');
  const changeStream = timeManagementCollection.watch([], { fullDocument: 'updateLookup' });

  changeStream.on('change', async (change) => {
    console.log('[TIME MANAGEMENT] Change detected in time_management:', JSON.stringify(change, null, 2));

    if (change.operationType === 'update' || change.operationType === 'insert') {
      const fullDocument = change.fullDocument;
      const childId = fullDocument.child_id;
      const timeSlots = fullDocument.time_slots;

      for (const slot of timeSlots) {
        const slotIdentifier = slot.slot_identifier;
        const allowedTime = slot.allowed_time;
        const endTime = slot.end_time;
        console.log(`[TIME MANAGEMENT] Processing slot: ${slotIdentifier}, Allowed time: ${allowedTime}, End time: ${endTime}`);
        await addRemainingTimeForNewSlot(db, ObjectId(childId), ObjectId(slotIdentifier), allowedTime, endTime);
        broadcastUpdate(slotIdentifier, allowedTime);
      }
    }
  });

  changeStream.on('error', (error) => {
    console.error('[TIME MANAGEMENT] Error in change stream:', error);
  });

  changeStream.on('end', () => {
    console.log('[TIME MANAGEMENT] Change stream ended. Restarting...');
    watchTimeManagementCollection(db, broadcastUpdate);
  });
}

// Exporting the functions
module.exports = {
  getTimeManagement,
  updateRemainingTime,
  getRemainingTime,
  resetRemainingTimes,
  watchTimeManagementCollection,
  manualSyncRemainingTime,
  checkAndUpdateRemainingTime,
  lockDevice,
  unlockDevice
};
*/