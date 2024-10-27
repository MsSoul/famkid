//filename:../server/time_management.js
const { MongoClient, ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('[TIME MANAGEMENT] time_management.js module loaded and running.');

async function syncTimeSlot(db, childId, timeSlots, deviceTime = null) {
  // Use device time if provided, otherwise fallback to server time
  const now = deviceTime ? new Date(deviceTime) : new Date();
  
  const updatedTimeSlots = [];

  console.log(`[TIME MANAGEMENT - SYNCING TIME SLOTS STARTS]`);
  console.log(`
    Child ID: ${childId}
          `);
  for (const slot of timeSlots) {
    const { slot_identifier, start_time, end_time, allowed_time } = slot;
    const slotIdentifier = slot_identifier ? new ObjectId(slot_identifier) : new ObjectId();

    // Calculate start and end times based on device or server time
    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
    const totalSlotDuration = Math.ceil((slotEndTime - slotStartTime) / 1000); // Duration in seconds
    
    let remainingTime;

    // Update remaining time based on the current time
    if (now >= slotStartTime && now <= slotEndTime) {
      // Within the time slot, calculate remaining time
      remainingTime = Math.ceil((slotEndTime - now) / 1000);
    } else if (now < slotStartTime) {
      // Before the slot starts, reset to allowed time
      remainingTime = allowed_time || totalSlotDuration;
    } else {
      // After the slot has ended, remaining time should be zero
      remainingTime = 0;
    }

    updatedTimeSlots.push({
      slot_identifier: slotIdentifier,
      remaining_time: remainingTime,
      start_time: start_time,
      end_time: end_time,
    });

    // Log each slot with remaining time and slot_identifier
    console.log(`     SLOT# : ${slotIdentifier} : REMAINING TIME = ${remainingTime}`);
  }

  // Update the remaining_time collection with the new remaining times
  await db.collection('remaining_time').updateOne(
    { child_id: new ObjectId(childId) },
    { $set: { time_slots: updatedTimeSlots } },
    { upsert: true }
  );

  console.log(`[SYNCING TIME SLOTS FOR TIME MANAGEMENT COMPLETED]\n`);
}


async function checkAndUpdateRemainingTime(db, req = null, res = null) {
  try {
    // Get the device time from the request query or default to current time
    const { deviceTime } = req ? req.query : { deviceTime: null };
    const now = deviceTime ? new Date(deviceTime) : new Date(); // Use device or server time
    //const timeSource = deviceTime ? `Device time: ${now.toISOString()}` : `Server time: ${now.toISOString()}`; // Log the time source

    // Log the device time
    console.log(`Device time: ${now.toISOString()}`);

    const timeManagementDocs = await db.collection('remaining_time').find().toArray();

    // Iterate through each child document
    for (const doc of timeManagementDocs) {
      const childId = doc.child_id;
      const timeSlots = doc.time_slots;

      if (!timeSlots || timeSlots.length === 0) {
        console.warn(`[TIME MANAGEMENT] No time slots found for child: ${childId}`);
        continue; // Skip if there are no time slots
      }

      // Log the Child ID and formatted output header
      console.log(`
Child ID: ${childId}
      `);

      // Iterate through each time slot for the child
      for (const timeSlot of timeSlots) {
        const slotIdentifier = timeSlot.slot_identifier;
        const startTime = timeSlot.start_time;
        const endTime = timeSlot.end_time;

        // Parse the start and end times using the device time
        const slotStartTime = new Date(new Date(now).toDateString() + ' ' + startTime);
        const slotEndTime = new Date(new Date(now).toDateString() + ' ' + endTime);

        // Calculate the total duration of the slot (in seconds)
        const totalSlotDuration = Math.ceil((slotEndTime - slotStartTime) / 1000); // Duration in seconds

        let remainingTime;

        // Calculate remaining time based on the device time
        if (now >= slotStartTime && now <= slotEndTime) {
          remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining time in seconds
        } else if (now < slotStartTime) {
          // Before the slot starts, set remaining time to the total duration (i.e., full slot time, not default to 3600)
          remainingTime = totalSlotDuration;
        } else {
          // Slot has ended, remaining time is zero
          remainingTime = 0;
        }

        // Log the slot information in the desired format
        console.log(`     Slot# ${slotIdentifier}\n     Start Time: ${startTime}   End Time: ${endTime} \n     Remaining Time: ${remainingTime} seconds
        `);

        // Update remaining time in the document to reflect the calculated value
        await db.collection('remaining_time').updateOne(
          { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
          { $set: { "time_slots.$.remaining_time": remainingTime } }
        );
      }
    }

    if (res && res.status) {
      res.status(200).json({ message: '[TIME MANAGEMENT] Automatically updated remaining time for all slots.' });
    }
    console.log('(===============[TIME MANAGEMENT] Automatically Synced all slots===============)');
  } catch (error) {
    console.error('[TIME MANAGEMENT] Error in checkAndUpdateRemainingTime:', error);
    if (res && res.status) res.status(500).json({ message: '[TIME MANAGEMENT] Internal error.', error: error.message });
  }
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