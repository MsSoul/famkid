//filename:../server/app_time.js
const { ObjectId } = require('mongodb');

// Get app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log('Received app time management request for child ID:', childId);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            console.log('No app time slots found for the specified child.');
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }

        console.log('App time management data retrieved successfully:', appTimeManagement);
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Update remaining app time for a specific slot
async function updateRemainingAppTime(req, res, db) {
    console.log('App time management: updateRemainingAppTime function called');
    const { childId, slotIdentifier, remainingTime } = req.body;

    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const result = await db.collection('remaining_app_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { 
                $set: { 
                    "time_slots.$.remaining_time": remainingTime
                } 
            },
            { upsert: true }
        );

        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
            console.log('Remaining app time updated successfully');
            return res.status(200).json({ message: 'Remaining app time updated successfully' });
        } else {
            return res.status(500).json({ message: 'Failed to update remaining app time' });
        }
    } catch (error) {
        console.error('Error updating remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

// Get remaining app time for a specific slot
async function getRemainingAppTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;

    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingAppTimeDoc) {
            const timeSlot = remainingAppTimeDoc.time_slots.find(slot => slot.slot_identifier.equals(new ObjectId(slotIdentifier)));
            console.log('Remaining app time retrieved successfully:', timeSlot);
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            console.log('No remaining app time found for the specified app slot');
            return res.status(404).json({ message: 'No remaining app time found for the specified app slot' });
        }
    } catch (error) {
        console.error('Error fetching remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

// Manual sync for remaining app time
async function manualSyncRemainingAppTime(req, res, db) {
    console.log('(==================[APP TIME] Manual Sync Start==================)');
    const { deviceTime } = req.query; // Accept device time from the request
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date(); // Use device time if provided, fallback to server time

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();

        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;

            for (const timeSlot of timeSlots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 3600; // Default to 1 hour if not provided

                const now = deviceDateTime; // Use device time here
                const startTimeStr = timeSlot.start_time;
                const endTimeStr = timeSlot.end_time;

                if (!startTimeStr || !endTimeStr) {
                    console.error(`[APP TIME] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                    continue;
                }

                const startTime = new Date(`${now.toDateString()} ${startTimeStr}`);
                const endTime = new Date(`${now.toDateString()} ${endTimeStr}`);

                let remainingTime;

                if (now >= startTime && now <= endTime) {
                    remainingTime = Math.ceil((endTime - now) / 1000); // Remaining seconds
                } else if (now < startTime) {
                    remainingTime = allowedTime; // Before the slot starts
                } else {
                    remainingTime = 0; // Slot has ended
                }

                // Prepare filter and update
                const filter = {
                    child_id: new ObjectId(childId),
                    "time_slots.slot_identifier": new ObjectId(slotIdentifier),
                };

                const update = {
                    $set: {
                        "time_slots.$.remaining_time": remainingTime,
                        "time_slots.$.start_time": timeSlot.start_time,
                        "time_slots.$.end_time": timeSlot.end_time
                    }
                };

                await db.collection('remaining_app_time').updateOne(filter, update, { upsert: true });

                console.log(`[APP TIME] Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
            }
        }

        res.status(200).json({ message: '[APP TIME] Manual sync completed successfully.' });
    } catch (error) {
        console.error('Manual sync error:', error);
        res.status(500).json({ message: '[APP TIME] Manual sync failed.', error: error.message });
    }
    console.log('(==================[APP TIME] Manual Sync End==================)');
}

// Check and update remaining app time
// Check and update remaining app time
async function checkAndUpdateRemainingAppTime(db, res = null) {
    let errorOccurred = false;

    console.log('[***APP TIME***] Checking and updating remaining time...');

    try {
        const appTimeDocs = await db.collection('remaining_app_time').find().toArray();

        for (const doc of appTimeDocs) {
            const childId = doc.child_id;
            const appName = doc.app_name;

            if (!doc.time_slots || doc.time_slots.length === 0) {
                console.warn(`[APP TIME] No time slots found for app: ${appName}, child: ${childId}`);
                continue;
            }

            // Group log output for each child
            console.log(`Child ID: ${childId}`);

            // Now iterate through the time_slots array
            for (const timeSlot of doc.time_slots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const startTime = timeSlot.start_time;
                const endTime = timeSlot.end_time;
                const allowedTime = timeSlot.allowed_time || 3600; // Default to 1 hour if not provided

                // Checking if start_time, end_time, or slot_identifier are missing
                if (!slotIdentifier || !startTime || !endTime) {
                    console.error(`[APP TIME] Start time, end time, or slot identifier is missing for slot ${slotIdentifier || 'undefined'}. Skipping update.`);
                    errorOccurred = true;
                    continue; // Skip this slot if any key field is missing
                }

                const now = new Date();
                const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);
                const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);

                let remainingTime;

                if (now >= slotStartTime && now <= slotEndTime) {
                    remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
                } else if (now < slotStartTime) {
                    remainingTime = allowedTime; // Before the slot starts
                } else {
                    remainingTime = 0; // Slot has ended
                }

                try {
                    // Update the remaining app time in the collection
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                        {
                            $set: {
                                "time_slots.$.remaining_time": remainingTime,
                                "time_slots.$.start_time": startTime,
                                "time_slots.$.end_time": endTime
                            }
                        }
                    );

                    // Log the slot details under the current child
                    console.log(`     Slot# : ${slotIdentifier} : Remaining Time = ${remainingTime}`);
                } catch (updateError) {
                    console.error(`[APP TIME] Error updating remaining time for slot ${slotIdentifier}:`, updateError);
                    errorOccurred = true;
                }
            }
        }

        if (res && res.status) {
            if (errorOccurred) {
                res.status(500).json({ message: '[APP TIME] Errors occurred during update.' });
            } else {
                res.status(200).json({ message: '[APP TIME] Check and update completed successfully.' });
            }
        }

        console.log('[APP TIME] Automatically updated remaining time for all slots.\n\n');

    } catch (error) {
        console.error('[APP TIME] Error checking and updating remaining app time:', error);
        if (res && res.status) {
            res.status(500).json({ message: 'Internal server error' });
        }
    }
}


// Sync app time slots from app_time_management to remaining_app_time
async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME] Syncing app time slots for child ID: ${childId}`);

    try {
        const appTimeManagementDoc = await db.collection('app_time_management').findOne({ child_id: new ObjectId(childId) });

        if (appTimeManagementDoc) {
            const timeSlots = appTimeManagementDoc.time_slots;
            const appName = appTimeManagementDoc.app_name; // Retrieve app_name as a string

            for (const timeSlot of timeSlots) {
                const { slot_identifier, allowed_time, start_time, end_time } = timeSlot;

                console.log(`[APP TIME] Processing slot identifier: ${slot_identifier}`);

                // Calculate remaining time
                const now = new Date();
                const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
                const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);

                let remainingTime;
                if (now < slotStartTime) {
                    remainingTime = allowed_time; // Before the slot starts
                } else if (now >= slotStartTime && now <= slotEndTime) {
                    remainingTime = Math.ceil((slotEndTime - now) / 1000); // Remaining seconds
                } else {
                    remainingTime = 0; // Slot has ended
                }

                // Check if the document exists in remaining_app_time
                const filter = {
                    child_id: new ObjectId(childId),
                    "time_slots.slot_identifier": new ObjectId(slot_identifier)
                };

                const existingDoc = await db.collection('remaining_app_time').findOne(filter);

                if (existingDoc) {
                    // Update the existing document
                    console.log(`[APP TIME] Found existing time slot. Updating...`);
                    const updateResult = await db.collection('remaining_app_time').updateOne(
                        filter,
                        {
                            $set: {
                                "time_slots.$.remaining_time": remainingTime,
                                "time_slots.$.start_time": start_time,
                                "time_slots.$.end_time": end_time,
                                "app_name": appName // Ensure app_name is stored as a string, not an array
                            }
                        }
                    );

                    if (updateResult.modifiedCount > 0) {
                        console.log(`[APP TIME] Slot ${slot_identifier} updated with remaining time ${remainingTime} and app name '${appName}' for child ${childId}.`);
                    } else {
                        console.error(`[APP TIME] No update made for slot ${slot_identifier}.`);
                    }
                } else {
                    // Insert new document if it doesn't exist
                    console.log(`[APP TIME] No existing time slot found. Inserting new document...`);
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId) },
                        {
                            $push: {
                                time_slots: {
                                    slot_identifier: new ObjectId(slot_identifier),
                                    remaining_time: remainingTime,
                                    start_time: start_time,
                                    end_time: end_time
                                }
                            },
                            $set: {
                                "app_name": appName // Insert app_name as a string
                            }
                        },
                        { upsert: true }
                    );
                    console.log(`[APP TIME] New time slot inserted with remaining time ${remainingTime} and app name '${appName}' for child ${childId}.`);
                }
            }
        } else {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
        }
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }
}

module.exports = {
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    manualSyncRemainingAppTime,
    checkAndUpdateRemainingAppTime,
    syncAppTimeSlotsWithRemainingTime
};

/*
const { ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('app_time.js module loaded and running.');

async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log('Received app time management request for child ID:', childId);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            console.log('No app time slots found for the specified child.');
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }

        console.log('App time management data retrieved successfully:', appTimeManagement);
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

async function updateRemainingAppTime(req, res, db) {
    console.log('App time management: updateRemainingAppTime function called');
    const { childId, slotIdentifier, remainingTime } = req.body;

    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const result = await db.collection('remaining_app_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { 
                $set: { 
                    "time_slots.$.remaining_time": remainingTime, 
                    "time_slots.$.timestamp": new Date() 
                } 
            },
            { upsert: true }
        );

        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
            console.log('Remaining app time updated successfully');
            return res.status(200).json({ message: 'Remaining app time updated successfully' });
        } else {
            return res.status(500).json({ message: 'Failed to update remaining app time' });
        }
    } catch (error) {
        console.error('Error updating remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

async function getRemainingAppTime(req, res, db) {
    const { childId, slotIdentifier } = req.query;

    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingAppTimeDoc) {
            const timeSlot = remainingAppTimeDoc.time_slots.find(slot => slot.slot_identifier.equals(new ObjectId(slotIdentifier)));
            console.log('Remaining app time retrieved successfully:', timeSlot);
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            console.log('No remaining app time found for the specified app slot');
            return res.status(404).json({ message: 'No remaining app time found for the specified app slot' });
        }
    } catch (error) {
        console.error('Error fetching remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

async function manualSyncRemainingAppTime(req, res, db) {
    console.log('(==================[APP TIME] Manual Sync Start==================)');
    try {
        const appTimeManagementCollection = db.collection('app_time_management');
        const remainingAppTimeCollection = db.collection('remaining_app_time');

        const appTimeManagementDocs = await appTimeManagementCollection.find({}).toArray();

        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            const appId = doc.app_id; 
            let timeSlots = doc.time_slots;

            if (!Array.isArray(timeSlots)) {
                console.error(`timeSlots is not an array for document with childId ${childId}:`, timeSlots);
                timeSlots = [];
                await appTimeManagementCollection.updateOne(
                    { _id: doc._id },
                    { $set: { time_slots: timeSlots } }
                );
                continue;
            }

            for (const timeSlot of timeSlots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 3600; 
                const endTime = timeSlot.end_time;
                const startTime = timeSlot.start_time;

                if (!startTime || !endTime) {
                    console.error(`Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                    continue;
                }

                const now = new Date();
                const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
                const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

                let remainingTime;

                if (now >= slotStartTime && now <= slotEndTime) {
                    remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60; // Round up to the nearest minute
                } else if (now < slotStartTime) {
                    remainingTime = allowedTime;
                } else {
                    remainingTime = 0;
                }

                const filter = {
                    child_id: new ObjectId(childId),
                    slot_identifier: new ObjectId(slotIdentifier),
                    app_id: new ObjectId(appId)
                };

                const update = {
                    $set: {
                        remaining_time: remainingTime,
                        start_time: startTime,
                        end_time: endTime,
                        timestamp: new Date()
                    }
                };

                await remainingAppTimeCollection.updateOne(filter, update, { upsert: true });

                console.log(`[APP TIME] Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
            }
        }

        if (res && res.status) {
            res.status(200).json({ message: 'APP TIME Manual sync completed successfully.' });
        } else {
            console.log('[APP TIME] Manual sync completed successfully.');
        }
    } catch (error) {
        console.error('Manual sync error:', error);
        if (res && res.status) {
            res.status(500).json({ message: 'Manual sync failed.', error: error.message });
        }
    }
    console.log('(==================[APP TIME] Manual Sync End==================)');
}

async function checkAndUpdateRemainingAppTime(db, res = null) {
    let errorOccurred = false;

    try {
        const appTimeSlots = await db.collection('remaining_app_time').find().toArray();

        for (const timeSlot of appTimeSlots) {
            const slotIdentifier = timeSlot.slot_identifier;
            const allowedTime = timeSlot.allowed_time || 3600;
            const childId = timeSlot.child_id;

            if (!timeSlot.start_time || !timeSlot.end_time) {
                console.error(`[APP TIME] Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                errorOccurred = true;
                continue;
            }

            const startTime = timeSlot.start_time;
            const endTime = timeSlot.end_time;

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
                await db.collection('remaining_app_time').updateOne(
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
                console.log(`[APP TIME] Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
            } catch (updateError) {
                console.error(`[APP TIME] Error updating remaining time for slot ${slotIdentifier}:`, updateError);
                errorOccurred = true;
            }
        }

        if (res && res.status) {
            if (errorOccurred) {
                res.status(500).json({ message: '[APP TIME] Errors occurred during update.' });
            } else {
                res.status(200).json({ message: '[APP TIME] Check and update completed successfully.' });
            }
        }
    } catch (error) {
        console.error('Error checking and updating remaining app time:', error);
        if (res && res.status) {
            res.status(500).json({ message: 'Internal server error' });
        }
    }
}

module.exports = {
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    manualSyncRemainingAppTime,
    checkAndUpdateRemainingAppTime
};

*/
/*
const { ObjectId } = require('mongodb');

// Indicate that the module is loaded
console.log('app_time.js module loaded and running.');

async function getAppTimeManagement(req, res, db) {
    console.log('App time management: getAppTimeManagement function called');
    const childId = req.params.childId;
    console.log('Received app time management request for child ID:', childId);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            console.log('No app time slots found for the specified child.');
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }

        console.log('App time management data retrieved successfully:', appTimeManagement);
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

async function updateRemainingAppTime(req, res, db) {
    console.log('App time management: updateRemainingAppTime function called');
    const { childId, slotIdentifier, remainingTime } = req.body;

    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const result = await db.collection('remaining_app_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { 
                $set: { 
                    "time_slots.$.remaining_time": remainingTime, 
                    "time_slots.$.timestamp": new Date() 
                } 
            },
            { upsert: true }
        );

        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
            console.log('Remaining app time updated successfully');
            return res.status(200).json({ message: 'Remaining app time updated successfully' });
        } else {
            return res.status(500).json({ message: 'Failed to update remaining app time' });
        }
    } catch (error) {
        console.error('Error updating remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

async function getRemainingAppTime(req, res, db) {
    console.log('App time management: getRemainingAppTime function called');
    const { childId, slotIdentifier } = req.query;

    if (!childId || !slotIdentifier) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({
            child_id: new ObjectId(childId),
            "time_slots.slot_identifier": new ObjectId(slotIdentifier)
        });

        if (remainingAppTimeDoc) {
            const timeSlot = remainingAppTimeDoc.time_slots.find(slot => slot.slot_identifier.equals(new ObjectId(slotIdentifier)));
            console.log('Remaining app time retrieved successfully:', timeSlot);
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            console.log('No remaining app time found for the specified app slot');
            return res.status(404).json({ message: 'No remaining app time found for the specified app slot' });
        }
    } catch (error) {
        console.error('Error fetching remaining app time:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

async function manualSyncRemainingAppTime(req, res, db) {
  console.log('App time management: manualSyncRemainingAppTime function called /n');
  try {
      const appTimeManagementCollection = db.collection('app_time_management');
      const remainingAppTimeCollection = db.collection('remaining_app_time');

      const appTimeManagementDocs = await appTimeManagementCollection.find({}).toArray();

      for (const doc of appTimeManagementDocs) {
          const childId = doc.child_id;
          const appId = doc.app_id; 
          let timeSlots = doc.time_slots;

          if (!Array.isArray(timeSlots)) {
              console.error(`timeSlots is not an array for document with childId ${childId}:`, timeSlots);
              timeSlots = [];
              await appTimeManagementCollection.updateOne(
                  { _id: doc._id },
                  { $set: { time_slots: timeSlots } }
              );
              continue;
          }

          for (const timeSlot of timeSlots) {
              const slotIdentifier = timeSlot.slot_identifier;
              const allowedTime = timeSlot.allowed_time || 3600; 
              const endTime = timeSlot.end_time;
              const startTime = timeSlot.start_time;

              if (!startTime || !endTime) {
                  console.error(`Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
                  continue;
              }

              const now = new Date();
              const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
              const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

              let remainingTime;

              if (now >= slotStartTime && now <= slotEndTime) {
                  remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60; // Round up to the nearest minute
              } else if (now < slotStartTime) {
                  remainingTime = allowedTime;
              } else {
                  remainingTime = 0;
              }

              const filter = {
                  child_id: new ObjectId(childId),
                  slot_identifier: new ObjectId(slotIdentifier),
                  app_id: new ObjectId(appId)
              };

              const update = {
                  $set: {
                      remaining_time: remainingTime,
                      start_time: startTime,
                      end_time: endTime,
                      timestamp: new Date()
                  }
              };

              await remainingAppTimeCollection.updateOne(filter, update, { upsert: true });

              console.log(`Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);
          }
      }

      if (res && res.status) {
          res.status(200).json({ message: 'APP TIME Manual sync completed successfully.' });
      } else {
          console.log('\x1b[32m%s\x1b[0m', '{ message: "MANUALLY UPDATED." }');
      }
  } catch (error) {
      console.error('Manual sync error:', error);
      if (res && res.status) {
          res.status(500).json({ message: 'Manual sync failed.', error: error.message });
      }
  }
}

async function checkAndUpdateRemainingAppTime(db, res = null) {
  console.log('Running the checkAndUpdateRemainingAppTime function of APP TIME /n');
  
  try {
      const appTimeSlots = await db.collection('remaining_app_time').find().toArray();

      for (const timeSlot of appTimeSlots) {
          const slotIdentifier = timeSlot.slot_identifier;
          const allowedTime = timeSlot.allowed_time || 3600; // Default to 3600 seconds if allowed_time is not present
          const endTime = timeSlot.end_time;
          const startTime = timeSlot.start_time;
          const childId = timeSlot.child_id;

          if (!startTime || !endTime) {
              console.error(`Start time or end time is missing for slot ${slotIdentifier}. Skipping update.`);
              continue;
          }

          const now = new Date();
          const slotEndTime = new Date(`${now.toDateString()} ${endTime}`);
          const slotStartTime = new Date(`${now.toDateString()} ${startTime}`);

          if (now >= slotStartTime && now <= slotEndTime) {
              let remainingTime = Math.ceil((slotEndTime - now) / 1000 / 60) * 60; // Round up to the nearest minute

              if (remainingTime < 0) {
                  remainingTime = 0;
              }

              console.log(`Synced slot ${slotIdentifier} with remaining time ${remainingTime} for child ${childId}.`);

              await db.collection('remaining_app_time').updateOne(
                  { slot_identifier: slotIdentifier },
                  {
                      $set: {
                          remaining_time: remainingTime,
                          timestamp: now
                      }
                  }
              );
          } else if (now < slotStartTime) {
              console.log(`Synced slot ${slotIdentifier} with remaining time ${allowedTime} for child ${childId}.`);
              
              await db.collection('remaining_app_time').updateOne(
                  { slot_identifier: slotIdentifier },
                  {
                      $set: {
                          remaining_time: allowedTime,
                          timestamp: now
                      }
                  }
              );
          } else {
              console.log(`Synced slot ${slotIdentifier} with remaining time 0 for child ${childId}.`);

              await db.collection('remaining_app_time').updateOne(
                  { slot_identifier: slotIdentifier },
                  {
                      $set: {
                          remaining_time: 0,
                          timestamp: now
                      }
                  }
              );
          }
      }

      // Send the response if the function was called with a res object (indicating an HTTP request)
      if (res && res.status) {
          res.status(200).json({ message: 'APP TIME AUTOMATICALLY UPDATED.' });
      } else {
          console.log('\x1b[32m%s\x1b[0m', '{ message: "AUTOMATICALLY UPDATED." }');
      }
  } catch (error) {
      console.error('Error in checkAndUpdateRemainingAppTime:', error);
  }
}


module.exports = {
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    manualSyncRemainingAppTime,
    checkAndUpdateRemainingAppTime
};

*/