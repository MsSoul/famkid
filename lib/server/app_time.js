//filename:../server/app_time.js
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');

// WebSocket server instance
let wss;

// Initialize WebSocket server and set up client connection handling
function initializeWebSocket(server) {
    wss = new WebSocket.Server({ server });
    wss.on('connection', (ws) => {
        console.log('[WEBSOCKET] Client connected');
        ws.on('close', () => console.log('[WEBSOCKET] Client disconnected'));
    });
}

function broadcastUpdate(childId, updatedSlots) {
    if (wss) {
        const message = JSON.stringify({ childId, updatedSlots });
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
        console.log(`[WEBSOCKET] Broadcasted update for Child ID: ${childId}`);
    }
}

// Fetch app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log(`[APP TIME] Fetching app time management for child ID: ${childId}`);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (appTimeManagement.length === 0) return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('[APP TIME] Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Helper function to update or insert time slots
async function updateOrInsertSlot(db, childId, appName, timeSlot) {
    const { slot_identifier, start_time, end_time, allowed_time = 0 } = timeSlot;
    const now = new Date();
    const startTime = new Date(`${now.toDateString()} ${start_time}`);
    const endTime = new Date(`${now.toDateString()} ${end_time}`);
    if (endTime < startTime) endTime.setDate(endTime.getDate() + 1);

    const remainingTime = now < startTime ? allowed_time : (now <= endTime ? Math.ceil((endTime - now) / 1000) : 0);

    const filter = { child_id: new ObjectId(childId), app_name: appName, "time_slots.slot_identifier": new ObjectId(slot_identifier) };
    const existingSlot = await db.collection('remaining_app_time').findOne(filter);

    if (existingSlot) {
        await db.collection('remaining_app_time').updateOne(filter, {
            $set: {
                "time_slots.$.remaining_time": remainingTime,
                "time_slots.$.start_time": start_time,
                "time_slots.$.end_time": end_time
            }
        });
    } else {
        await db.collection('remaining_app_time').updateOne(
            { child_id: new ObjectId(childId), app_name: appName },
            { $push: { time_slots: { slot_identifier: new ObjectId(slot_identifier), remaining_time: remainingTime, start_time, end_time } } },
            { upsert: true }
        );
    }

    return { slot_identifier, remaining_time: remainingTime, start_time, end_time };
}

// Synchronize app time slots with the remaining time
async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME] Syncing app time slots for child ID: ${childId}`);
    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagementDocs.length) {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
            return;
        }

        const updatedSlots = [];
        for (const doc of appTimeManagementDocs) {
            const appName = doc.app_name || 'Unknown';
            console.log(`    App Name: ${appName}`);

            const timeSlots = doc.time_slots.map(slot => slot.slot_identifier.toString());
            const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

            if (remainingAppTimeDoc) {
                const remainingSlots = remainingAppTimeDoc.time_slots.map(slot => slot.slot_identifier.toString());
                const slotsToRemove = remainingSlots.filter(slotId => !timeSlots.includes(slotId));
                if (slotsToRemove.length) {
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), app_name: appName },
                        { $pull: { time_slots: { slot_identifier: { $in: slotsToRemove.map(id => new ObjectId(id)) } } } }
                    );
                    console.log(`[SYNC] Removed outdated slots for Child ID: ${childId}, App: ${appName}, Slots: ${slotsToRemove}`);
                }
            }

            for (const timeSlot of doc.time_slots) {
                const updatedSlot = await updateOrInsertSlot(db, childId, appName, timeSlot);
                updatedSlots.push(updatedSlot);
                console.log(`        Slot Identifier: ${updatedSlot.slot_identifier}`);
                console.log(`            Start Time: ${timeSlot.start_time}  End Time: ${timeSlot.end_time}  Remaining Time: ${updatedSlot.remaining_time}`);
            }
        }
        broadcastUpdate(childId, updatedSlots);
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }
    console.log('[APP TIME] Completed sync for app time slots\n');
}

async function checkAndUpdateRemainingAppTime(db, req = null, res = null) {
    const { deviceTime } = req?.query || {};
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();
    const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
    console.log(`[APP TIME] Checking and updating remaining app time for ${appTimeManagementDocs.length} children...`);

    const logEntries = {};
    for (const doc of appTimeManagementDocs) {
        const childId = doc.child_id;
        const appName = doc.app_name || 'Unknown';
        const timeSlots = doc.time_slots.map(slot => slot.slot_identifier.toString());
        logEntries[childId] = logEntries[childId] || {};
        logEntries[childId][appName] = logEntries[childId][appName] || [];

        try {
            const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });
            if (remainingAppTimeDoc) {
                const remainingSlots = remainingAppTimeDoc.time_slots.map(slot => slot.slot_identifier.toString());
                const slotsToRemove = remainingSlots.filter(slotId => !timeSlots.includes(slotId));
                if (slotsToRemove.length) {
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), app_name: appName },
                        { $pull: { time_slots: { slot_identifier: { $in: slotsToRemove.map(id => new ObjectId(id)) } } } }
                    );
                    console.log(`[SYNC] Removed outdated slots for Child ID: ${childId}, App: ${appName}, Slots: ${slotsToRemove}`);
                }
            }

            for (const timeSlot of doc.time_slots) {
                const updatedSlot = await updateOrInsertSlot(db, childId, appName, timeSlot);
                logEntries[childId][appName].push(updatedSlot);
            }
        } catch (error) {
            console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId} - ${error.message}`);
        }
    }

    for (const childId in logEntries) {
        console.log(`CHILD ID: ${childId}`);
        for (const appName in logEntries[childId]) {
            console.log(`  App Name: ${appName}`);
            logEntries[childId][appName].forEach(slot => {
                console.log(`    SLOT #: ${slot.slot_identifier}\n   START TIME: ${slot.start_time}   END TIME: ${slot.end_time}\n   REMAINING TIME: ${slot.remaining_time} seconds`);
            });
        }
    }
    

    const responseStatus = logEntries.length ? (res ? res.status(200).json({ message: 'Remaining time updated successfully.' }) : null) : (res ? res.status(500).json({ message: 'Error updating remaining time for some slots.' }) : null);
    console.log('[APP TIME] Remaining time update and sync completed successfully.');
    return responseStatus;
}

// Monitor changes in `app_time_management` collection and trigger check and update
function watchAppTimeManagementCollection(db) {
    const changeStream = db.collection('app_time_management').watch([], { fullDocument: 'updateLookup' });
    changeStream.on('change', async (change) => {
        if (['update', 'insert'].includes(change.operationType)) {
            const childId = change.fullDocument.child_id;
            console.log(`[WATCH] Detected change in app_time_management for Child ID: ${childId}`);
            await checkAndUpdateRemainingAppTime(db, childId);
        }
    });
    changeStream.on('error', (error) => console.error('[WATCH] Error in change stream:', error.message));
}

// Midnight reset function
function resetRemainingAppTime(db) {
    console.log('[MIDNIGHT RESET] Resetting remaining app time...');
    db.collection('remaining_app_time').updateMany({}, { $set: { 'time_slots.$[].remaining_time': 0 } })
        .then(() => console.log('[MIDNIGHT RESET] Remaining app time reset successfully.'))
        .catch((error) => console.error('[MIDNIGHT RESET] Error resetting remaining app time:', error.message));
}

// Schedule midnight reset at 00:00
function scheduleMidnightReset(db) {
    const now = new Date();
    const msTillMidnight = (new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1) - now);
    setTimeout(() => {
        resetRemainingAppTime(db);
        scheduleMidnightReset(db); // Reschedule for the next day
    }, msTillMidnight);
}

// Export functions
module.exports = {
    initializeWebSocket,
    getAppTimeManagement,
    syncAppTimeSlotsWithRemainingTime,
    checkAndUpdateRemainingAppTime,
    watchAppTimeManagementCollection,
    scheduleMidnightReset
};

/*
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');

// WebSocket server instance
let wss;

// Initialize WebSocket server and set up client connection handling
function initializeWebSocket(server) {
    wss = new WebSocket.Server({ server });
    
    wss.on('connection', (ws) => {
        console.log('[WEBSOCKET] Client connected');
        
        ws.on('close', () => {
            console.log('[WEBSOCKET] Client disconnected');
        });
    });
}

function broadcastUpdate(childId, updatedSlots) {
    if (wss) {
        const message = JSON.stringify({ childId, updatedSlots });
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
        console.log(`[WEBSOCKET] Broadcasted update for Child ID: ${childId}`);
    }
}

// Get app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log(`[APP TIME] Fetching app time management for child ID: ${childId}`);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('[APP TIME] Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Synchronize app time slots with the remaining time in `remaining_app_time`
async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME] Syncing app time slots for child ID: ${childId}`);

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();

        if (appTimeManagementDocs && appTimeManagementDocs.length > 0) {
            const updatedSlots = [];

            for (const doc of appTimeManagementDocs) {
                const appName = doc.app_name || 'Unknown';
                console.log(`    App Name: ${appName}`);

                // Create a structure to hold current time slots
                const timeSlots = doc.time_slots.map(slot => slot.slot_identifier.toString());

                // Check and manage existing remaining time entries
                const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

                if (remainingAppTimeDoc) { // Fixed variable name here
                    const remainingSlots = remainingAppTimeDoc.time_slots.map(slot => slot.slot_identifier.toString());
                    const slotsToRemove = remainingSlots.filter(slotId => !timeSlots.includes(slotId));

                    if (slotsToRemove.length > 0) {
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $pull: {
                                    time_slots: { slot_identifier: { $in: slotsToRemove.map(id => new ObjectId(id)) } }
                                }
                            }
                        );
                        console.log(`[SYNC] Removed outdated slots for Child ID: ${childId}, App: ${appName}, Slots: ${slotsToRemove}`);
                    }
                }

                for (const timeSlot of doc.time_slots) {
                    const slotIdentifier = timeSlot.slot_identifier;
                    const allowedTime = timeSlot.allowed_time || 0; // Use allowed_time directly
                    const startTime = new Date(`${new Date().toISOString().split('T')[0]}T${timeSlot.start_time}:00`);
                    const endTime = new Date(`${new Date().toISOString().split('T')[0]}T${timeSlot.end_time}:00`);

                    // Adjust for end time that crosses into the next day
                    if (endTime < startTime) {
                        endTime.setDate(endTime.getDate() + 1); // Move end time to the next day
                    }

                    const now = new Date();
                    let remainingTime;

                    // Calculate remaining time based on current time
                    if (now < startTime) {
                        remainingTime = allowedTime; // Full time if before start time
                    } else if (now >= startTime && now <= endTime) {
                        remainingTime = Math.max(0, Math.ceil((endTime - now) / 1000)); // Remaining seconds if within range
                    } else {
                        remainingTime = 0; // Past end time
                    }

                    const filter = {
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        "time_slots.slot_identifier": new ObjectId(slotIdentifier)
                    };

                    const existingSlot = await db.collection('remaining_app_time').findOne(filter);
                    if (existingSlot) {
                        await db.collection('remaining_app_time').updateOne(
                            filter,
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": timeSlot.start_time,
                                    "time_slots.$.end_time": timeSlot.end_time
                                }
                            }
                        );
                    } else {
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slotIdentifier),
                                        remaining_time: remainingTime,
                                        start_time: timeSlot.start_time,
                                        end_time: timeSlot.end_time
                                    }
                                }
                            },
                            { upsert: true }
                        );
                    }

                    updatedSlots.push({
                        slot_identifier: slotIdentifier,
                        remaining_time: remainingTime,
                        start_time: timeSlot.start_time,
                        end_time: timeSlot.end_time
                    });

                    console.log(`        Slot Identifier: ${slotIdentifier}`);
                    console.log(`            Start Time: ${timeSlot.start_time}  End Time: ${timeSlot.end_time}  Remaining Time: ${remainingTime}`);
                }
            }

            broadcastUpdate(childId, updatedSlots);
        } else {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
        }
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }

    console.log('[APP TIME] Completed sync for app time slots\n');
}

async function checkAndUpdateRemainingAppTime(db, req = null, res = null) {
    let errorOccurred = false;
    const { deviceTime } = req?.query || { deviceTime: null };
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();

    const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
    console.log(`[APP TIME] Checking and updating remaining app time for ${appTimeManagementDocs.length} children...`);

    // Create a structure to hold logs for each child
    const logEntries = {};

    for (const doc of appTimeManagementDocs) {
        const childId = doc.child_id;
        const appName = doc.app_name || 'Unknown';
        const timeSlots = doc.time_slots.map(slot => slot.slot_identifier.toString());

        // Ensure log entry for each child ID and app
        if (!logEntries[childId]) {
            logEntries[childId] = {};
        }
        if (!logEntries[childId][appName]) {
            logEntries[childId][appName] = [];
        }

        try {
            // Find all time slots in remaining_app_time for this child and app
            const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

            if (remainingAppTimeDoc) {
                // Get list of slot identifiers currently in remaining_app_time
                const remainingSlots = remainingAppTimeDoc.time_slots.map(slot => slot.slot_identifier.toString());

                // Determine slots that need to be removed from remaining_app_time
                const slotsToRemove = remainingSlots.filter(slotId => !timeSlots.includes(slotId));

                // Remove outdated slots
                if (slotsToRemove.length > 0) {
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), app_name: appName },
                        {
                            $pull: {
                                time_slots: { slot_identifier: { $in: slotsToRemove.map(id => new ObjectId(id)) } }
                            }
                        }
                    );
                    console.log(`[SYNC] Removed outdated slots for Child ID: ${childId}, App: ${appName}, Slots: ${slotsToRemove}`);
                }
            }

            // Proceed with remaining time updates
            for (const timeSlot of doc.time_slots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 0; // Use timeSlot's allowed_time directly
                const now = deviceDateTime;
                const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
                const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);
                let remainingTime = now < startTime ? allowedTime : now <= endTime ? Math.ceil((endTime - now) / 1000) : 0;

                // Check if the slot exists in the remaining_app_time document
                const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

                if (remainingAppTimeDoc) {
                    const slotExists = remainingAppTimeDoc.time_slots.some(slot => slot.slot_identifier.equals(new ObjectId(slotIdentifier)));

                    if (slotExists) {
                        // Update existing slot
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName, "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": timeSlot.start_time,
                                    "time_slots.$.end_time": timeSlot.end_time
                                }
                            }
                        );
                    } else {
                        // Add new slot
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slotIdentifier),
                                        remaining_time: remainingTime,
                                        start_time: timeSlot.start_time,
                                        end_time: timeSlot.end_time
                                    }
                                }
                            },
                            { upsert: true }
                        );
                    }
                } else {
                    // If the document doesn't exist, create it with the new slot
                    await db.collection('remaining_app_time').insertOne({
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        time_slots: [{
                            slot_identifier: new ObjectId(slotIdentifier),
                            remaining_time: remainingTime,
                            start_time: timeSlot.start_time,
                            end_time: timeSlot.end_time
                        }]
                    });
                }

                // Add entry to log structure
                logEntries[childId][appName].push({ slotIdentifier, remainingTime });
            }
        } catch (error) {
            console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId} - ${error.message}`);
            errorOccurred = true;
        }
    }

    // Log update results
    for (const childId in logEntries) {
        console.log(`CHILD ID: ${childId}`);
        for (const appName in logEntries[childId]) {
            console.log(`  App Name: ${appName}`);
            logEntries[childId][appName].forEach(slot => {
                console.log(`    SLOT #: ${slot.slotIdentifier}   REMAINING TIME: ${slot.remainingTime} seconds`);
            });
        }
    }

    if (errorOccurred) {
        return res ? res.status(500).json({ message: 'Error updating remaining time for some slots.' }) : null;
    } else {
        console.log('[APP TIME] Remaining time update and sync completed successfully.');
        return res ? res.status(200).json({ message: 'Remaining time updated successfully.' }) : null;
    }
}


// Monitor changes in `app_time_management` collection and trigger check and update
function watchAppTimeManagementCollection(db) {
    const changeStream = db.collection('app_time_management').watch([], { fullDocument: 'updateLookup' });

    changeStream.on('change', async (change) => {
        if (['update', 'insert'].includes(change.operationType)) {
            const childId = change.fullDocument.child_id;
            console.log(`[WATCH] Detected change in app_time_management for Child ID: ${childId}`);
            await checkAndUpdateRemainingAppTime(db, childId);
        }
    });

    changeStream.on('error', (error) => console.error('[WATCH] Error in change stream:', error));
}

// Reset app remaining times (for testing or initializing)
async function resetRemainingAppTimes(db) {
    try {
        await db.collection('remaining_app_time').deleteMany({});
        console.log('[RESET] Remaining app time reset');
    } catch (error) {
        console.error('[RESET] Error resetting remaining time collections:', error);
    }
}

// Start the interval-based real-time update checking
function startRealTimeUpdates(db, interval = 60 * 1000) {
    setInterval(() => {
        console.log('[REAL-TIME UPDATES] Checking and updating remaining app times');
        checkAndUpdateRemainingAppTime(db);
    }, interval);
}

// Update remaining app time for a specific slot
async function updateRemainingAppTime(db) {
    console.log('[APP TIME] Checking and updating remaining app time for children...');

    const children = await db.collection('children').find({}).toArray(); // Fetch all children

    for (const child of children) {
        const childId = child._id; // Assuming child ID is stored as _id
        const apps = await db.collection('remaining_app_time').find({ child_id: childId }).toArray();

        for (const app of apps) {
            const appName = app.app_name; // Assuming app name is stored in the document
            const slots = app.time_slots; // Assuming time slots are stored in an array
            
            for (const slot of slots) {
                const slotIdentifier = slot.slot_identifier; // Assuming slot identifier is available
                const remainingTime = slot.remaining_time; // Current remaining time for the slot
                
                // Perform your logic to calculate updated remaining time here
                // For example, deducting time based on usage:
                const updatedRemainingTime = remainingTime - (timeUsed || 0); // Replace 'timeUsed' with actual usage calculation

                // Log the current state before updating
                console.log(`  App Name: ${appName}`);
                console.log(`    SLOT #: ${slotIdentifier}   REMAINING TIME: ${updatedRemainingTime} seconds`);

                // Update the remaining time in the database
                try {
                    const result = await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                        { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
                        { upsert: false } // Change to 'false' if you don't want to create new documents
                    );

                    // Log the result of the update operation
                    console.log(`[APP TIME] Update Result for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, result);
                } catch (error) {
                    // Log the error details
                    console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, error);
                }
            }
        }
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
            res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            res.status(404).json({ message: 'No remaining app time found for the specified slot.' });
        }
    } catch (error) {
        console.error('[APP TIME] Error fetching remaining app time:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Reset all remaining app times (called at midnight or via some trigger)
async function resetAllRemainingAppTimes(db) {
    console.log('[RESET] Resetting all remaining app times at midnight...');
    const resetTime = 24 * 60 * 60; // 24 hours in seconds

    try {
        await db.collection('remaining_app_time').updateMany(
            {},
            { $set: { "time_slots.$[].remaining_time": resetTime } } // Reset all slots for all children
        );
        console.log('[RESET] All remaining app times have been reset');
    } catch (error) {
        console.error('[RESET] Error resetting all remaining app times:', error);
    }
}


// Export all the functions
module.exports = {
    initializeWebSocket,
    getAppTimeManagement,
    syncAppTimeSlotsWithRemainingTime,
    watchAppTimeManagementCollection,
    resetRemainingAppTimes,
    startRealTimeUpdates,
    updateRemainingAppTime,
    getRemainingAppTime,
    resetAllRemainingAppTimes,
    checkAndUpdateRemainingAppTime,
};
*/
/*e update and remaining time 
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');

// WebSocket server instance
let wss;

// Initialize WebSocket server and set up client connection handling

function initializeWebSocket(server) {
    wss = new WebSocket.Server({ server });
    
    wss.on('connection', (ws) => {
        console.log('[WEBSOCKET] Client connected');
        
        ws.on('close', () => {
            console.log('[WEBSOCKET] Client disconnected');
        });
    });
}

function broadcastUpdate(childId, updatedSlots) {
    if (wss) {
        const message = JSON.stringify({ childId, updatedSlots });
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
        console.log(`[WEBSOCKET] Broadcasted update for Child ID: ${childId}`);
    }
}

// Get app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log(`[APP TIME] Fetching app time management for child ID: ${childId}`);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('[APP TIME] Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Synchronize app time slots with the remaining time in `remaining_app_time`
async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME] Syncing app time slots for child ID: ${childId}`);

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();

        if (appTimeManagementDocs && appTimeManagementDocs.length > 0) {
            const updatedSlots = [];

            for (const doc of appTimeManagementDocs) {
                const appName = doc.app_name || 'Unknown';
                console.log(`    App Name: ${appName}`);

                for (const timeSlot of doc.time_slots) {
                    const slotIdentifier = timeSlot.slot_identifier;
                    const allowedTime = timeSlot.allowed_time;
                    const startTime = new Date(`${new Date().toISOString().split('T')[0]}T${timeSlot.start_time}:00`);
                    const endTime = new Date(`${new Date().toISOString().split('T')[0]}T${timeSlot.end_time}:00`);
                    
                    const now = new Date();
                    let remainingTime;

                    if (now < startTime) {
                        remainingTime = allowedTime; // Full time if before start time
                    } else if (now >= startTime && now <= endTime) {
                        remainingTime = Math.max(0, Math.ceil((endTime - now) / 1000)); // Remaining seconds if within range
                    } else {
                        remainingTime = 0; // Past end time
                    }

                    const filter = {
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        "time_slots.slot_identifier": new ObjectId(slotIdentifier)
                    };

                    // Check if the slot exists and then update or add the slot accordingly
                    const existingSlot = await db.collection('remaining_app_time').findOne(filter);
                    if (existingSlot) {
                        await db.collection('remaining_app_time').updateOne(
                            filter,
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": timeSlot.start_time,
                                    "time_slots.$.end_time": timeSlot.end_time
                                }
                            }
                        );
                    } else {
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slotIdentifier),
                                        remaining_time: remainingTime,
                                        start_time: timeSlot.start_time,
                                        end_time: timeSlot.end_time
                                    }
                                }
                            },
                            { upsert: true }
                        );
                    }

                    updatedSlots.push({
                        slot_identifier: slotIdentifier,
                        remaining_time: remainingTime,
                        start_time: timeSlot.start_time,
                        end_time: timeSlot.end_time
                    });

                    console.log(`        Slot Identifier: ${slotIdentifier}`);
                    console.log(`            Start Time: ${timeSlot.start_time}  End Time: ${timeSlot.end_time}  Remaining Time: ${remainingTime}`);
                }
            }

            broadcastUpdate(childId, updatedSlots);
        } else {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
        }
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }

    console.log('[APP TIME] Completed sync for app time slots\n');
}



// Monitor changes in `app_time_management` collection and trigger check and update
function watchAppTimeManagementCollection(db) {
    const changeStream = db.collection('app_time_management').watch([], { fullDocument: 'updateLookup' });

    changeStream.on('change', async (change) => {
        if (['update', 'insert'].includes(change.operationType)) {
            const childId = change.fullDocument.child_id;
            console.log(`[WATCH] Detected change in app_time_management for Child ID: ${childId}`);
            await checkAndUpdateRemainingAppTime(db, childId);
        }
    });

    changeStream.on('error', (error) => console.error('[WATCH] Error in change stream:', error));
}


// Reset app remaining times (for testing or initializing)
async function resetRemainingAppTimes(db) {
    try {
        await db.collection('remaining_app_time').deleteMany({});
        console.log('[RESET] Remaining app time reset');
    } catch (error) {
        console.error('[RESET] Error resetting remaining time collections:', error);
    }
}

// Start the interval-based real-time update checking
function startRealTimeUpdates(db, interval = 60 * 1000) {
    setInterval(() => {
        console.log('[REAL-TIME UPDATES] Checking and updating remaining app times');
        checkAndUpdateRemainingAppTime(db);
    }, interval);
}

// Update remaining app time for a specific slot
async function updateRemainingAppTime(db) {
    console.log('[APP TIME] Checking and updating remaining app time for children...');

    const children = await db.collection('children').find({}).toArray(); // Fetch all children

    for (const child of children) {
        const childId = child._id; // Assuming child ID is stored as _id
        const apps = await db.collection('remaining_app_time').find({ child_id: childId }).toArray();

        for (const app of apps) {
            const appName = app.app_name; // Assuming app name is stored in the document
            const slots = app.time_slots; // Assuming time slots are stored in an array
            
            for (const slot of slots) {
                const slotIdentifier = slot.slot_identifier; // Assuming slot identifier is available
                const remainingTime = slot.remaining_time; // Current remaining time for the slot
                
                // Perform your logic to calculate updated remaining time here
                // For example, deducting time based on usage:
                const updatedRemainingTime = remainingTime - (timeUsed || 0); // Replace 'timeUsed' with actual usage calculation

                // Log the current state before updating
                console.log(`  App Name: ${appName}`);
                console.log(`    SLOT #: ${slotIdentifier}   REMAINING TIME: ${updatedRemainingTime} seconds`);

                // Update the remaining time in the database
                try {
                    const result = await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                        { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
                        { upsert: false } // Change to 'false' if you don't want to create new documents
                    );

                    // Log the result of the update operation
                    console.log(`[APP TIME] Update Result for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, result);
                } catch (error) {
                    // Log the error details
                    console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, error);
                }
            }
        }
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
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            return res.status(404).json({ message: 'No remaining time found' });
        }
    } catch (error) {
        console.error('[APP TIME] Error fetching remaining time:', error.message);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

async function checkAndUpdateRemainingAppTime(db, req = null, res = null) {
    let errorOccurred = false;
    const { deviceTime } = req?.query || { deviceTime: null };
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();

    const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
    console.log(`[APP TIME] Checking and updating remaining app time for ${appTimeManagementDocs.length} children...`);

    // Create a structure to hold logs for each child
    const logEntries = {};

    for (const doc of appTimeManagementDocs) {
        const childId = doc.child_id;
        const appName = doc.app_name || 'Unknown';
        const timeSlots = doc.time_slots.map(slot => slot.slot_identifier.toString());

        // Ensure log entry for each child ID and app
        if (!logEntries[childId]) {
            logEntries[childId] = {};
        }
        if (!logEntries[childId][appName]) {
            logEntries[childId][appName] = [];
        }

        try {
            // Find all time slots in remaining_app_time for this child and app
            const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

            if (remainingAppTimeDoc) {
                // Get list of slot identifiers currently in remaining_app_time
                const remainingSlots = remainingAppTimeDoc.time_slots.map(slot => slot.slot_identifier.toString());

                // Determine slots that need to be removed from remaining_app_time
                const slotsToRemove = remainingSlots.filter(slotId => !timeSlots.includes(slotId));

                // Remove outdated slots
                if (slotsToRemove.length > 0) {
                    await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), app_name: appName },
                        {
                            $pull: {
                                time_slots: { slot_identifier: { $in: slotsToRemove.map(id => new ObjectId(id)) } }
                            }
                        }
                    );
                    console.log(`[SYNC] Removed outdated slots for Child ID: ${childId}, App: ${appName}, Slots: ${slotsToRemove}`);
                }
            }

            // Proceed with remaining time updates
            for (const timeSlot of doc.time_slots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 0; // Use timeSlot's allowed_time directly
                const now = deviceDateTime;
                const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
                const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);
                let remainingTime = now < startTime ? allowedTime : now <= endTime ? Math.ceil((endTime - now) / 1000) : 0;

                // Check if the slot exists in the remaining_app_time document
                const remainingAppTimeDoc = await db.collection('remaining_app_time').findOne({ child_id: new ObjectId(childId), app_name: appName });

                if (remainingAppTimeDoc) {
                    const slotExists = remainingAppTimeDoc.time_slots.some(slot => slot.slot_identifier.equals(new ObjectId(slotIdentifier)));

                    if (slotExists) {
                        // Update existing slot
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName, "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": timeSlot.start_time,
                                    "time_slots.$.end_time": timeSlot.end_time
                                }
                            }
                        );
                    } else {
                        // Add new slot
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slotIdentifier),
                                        remaining_time: remainingTime,
                                        start_time: timeSlot.start_time,
                                        end_time: timeSlot.end_time
                                    }
                                }
                            },
                            { upsert: true }
                        );
                    }
                } else {
                    // If the document doesn't exist, create it with the new slot
                    await db.collection('remaining_app_time').insertOne({
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        time_slots: [{
                            slot_identifier: new ObjectId(slotIdentifier),
                            remaining_time: remainingTime,
                            start_time: timeSlot.start_time,
                            end_time: timeSlot.end_time
                        }]
                    });
                }

                // Add entry to log structure
                logEntries[childId][appName].push({ slotIdentifier, remainingTime });
            }
        } catch (error) {
            console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId} - ${error.message}`);
            errorOccurred = true;
        }
    }

    // Log update results
    for (const childId in logEntries) {
        console.log(`CHILD ID: ${childId}`);
        for (const appName in logEntries[childId]) {
            console.log(`  App Name: ${appName}`);
            logEntries[childId][appName].forEach(slot => {
                console.log(`    SLOT #: ${slot.slotIdentifier}   REMAINING TIME: ${slot.remainingTime} seconds`);
            });
        }
    }

    if (errorOccurred) {
        return res ? res.status(500).json({ message: 'Error updating remaining time for some slots.' }) : null;
    } else {
        console.log('[APP TIME] Remaining time update and sync completed successfully.');
        return res ? res.status(200).json({ message: 'Remaining time updated and synchronized successfully.' }) : null;
    }
}



module.exports = {
    initializeWebSocket,
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    syncAppTimeSlotsWithRemainingTime,
    checkAndUpdateRemainingAppTime,
    watchAppTimeManagementCollection,
    resetRemainingAppTimes,
	startRealTimeUpdates
};
*/
/*
const { ObjectId } = require('mongodb');
const WebSocket = require('ws'); // Import WebSocket library

// WebSocket server to broadcast updates
let wss;

function initializeWebSocket(server) {
    wss = new WebSocket.Server({ server });

    wss.on('connection', (ws) => {
        console.log('[WEBSOCKET] Client connected');

        ws.on('close', () => {
            console.log('[WEBSOCKET] Client disconnected');
        });
    });
}

// Broadcast updates to all connected clients
function broadcastUpdate(childId, timeSlots) {
    if (wss) {
        const message = JSON.stringify({ childId, timeSlots });
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
        console.log(`[WEBSOCKET] Broadcasted update for Child ID: ${childId}`);
    }
}

// Get app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log(`[APP TIME] Fetching app time management for child ID: ${childId}`);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('[APP TIME] Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Update remaining app time for a specific slot
async function updateRemainingAppTime(db) {
    console.log('[APP TIME] Checking and updating remaining app time for children...');

    const children = await db.collection('children').find({}).toArray(); // Fetch all children

    for (const child of children) {
        const childId = child._id; // Assuming child ID is stored as _id
        const apps = await db.collection('remaining_app_time').find({ child_id: childId }).toArray();

        for (const app of apps) {
            const appName = app.app_name; // Assuming app name is stored in the document
            const slots = app.time_slots; // Assuming time slots are stored in an array
            
            for (const slot of slots) {
                const slotIdentifier = slot.slot_identifier; // Assuming slot identifier is available
                const remainingTime = slot.remaining_time; // Current remaining time for the slot
                
                // Perform your logic to calculate updated remaining time here
                // For example, deducting time based on usage:
                const updatedRemainingTime = remainingTime - (timeUsed || 0); // Replace 'timeUsed' with actual usage calculation

                // Log the current state before updating
                console.log(`  App Name: ${appName}`);
                console.log(`    SLOT #: ${slotIdentifier}   REMAINING TIME: ${updatedRemainingTime} seconds`);

                // Update the remaining time in the database
                try {
                    const result = await db.collection('remaining_app_time').updateOne(
                        { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                        { $set: { "time_slots.$.remaining_time": updatedRemainingTime } },
                        { upsert: false } // Change to 'false' if you don't want to create new documents
                    );

                    // Log the result of the update operation
                    console.log(`[APP TIME] Update Result for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, result);
                } catch (error) {
                    // Log the error details
                    console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId}, Slot ID: ${slotIdentifier}`, error);
                }
            }
        }
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
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            return res.status(404).json({ message: 'No remaining time found' });
        }
    } catch (error) {
        console.error('[APP TIME] Error fetching remaining time:', error.message);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

// Manual sync for remaining app time
async function manualSyncRemainingAppTime(req, res, db) {
    console.log('[APP TIME] Manual Sync Started');
    const { deviceTime } = req.query;
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();

        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;

            for (const timeSlot of timeSlots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 3600; // Default allowed time if not specified

                const now = deviceDateTime;
                const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
                const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);
                let remainingTime = now < startTime ? allowedTime : now <= endTime ? Math.ceil((endTime - now) / 1000) : 0;

                await db.collection('remaining_app_time').updateOne(
                    { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                    { $set: { "time_slots.$.remaining_time": remainingTime } },
                    { upsert: true }
                );
            }
        }

        res.status(200).json({ message: '[APP TIME] Manual sync completed' });
    } catch (error) {
        console.error('[APP TIME] Manual sync error:', error.message);
        res.status(500).json({ message: '[APP TIME] Manual sync failed', error: error.message });
    }
}


async function checkAndUpdateRemainingAppTime(db, req = null, res = null) {
    let errorOccurred = false;
    const { deviceTime } = req?.query || { deviceTime: null };
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();

    const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
    console.log(`[APP TIME] Checking and updating remaining app time for ${appTimeManagementDocs.length} children...`);

    // Create a structure to hold logs for each child
    const logEntries = {};

    for (const doc of appTimeManagementDocs) {
        const childId = doc.child_id;
        const timeSlots = doc.time_slots;

        // Ensure log entry for each child ID
        if (!logEntries[childId]) {
            logEntries[childId] = {};
        }

        for (const timeSlot of timeSlots) {
            const slotIdentifier = timeSlot.slot_identifier;
            const allowedTime = timeSlot.allowed_time || 3600;

            const now = deviceDateTime;
            const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
            const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);
            let remainingTime = now < startTime ? allowedTime : now <= endTime ? Math.ceil((endTime - now) / 1000) : 0;

            try {
                await db.collection('remaining_app_time').updateOne(
                    { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                    { $set: { "time_slots.$.remaining_time": remainingTime } },
                    { upsert: true }
                );

                // Initialize app name if not present
                const appName = doc.app_name || 'Unknown';
                if (!logEntries[childId][appName]) {
                    logEntries[childId][appName] = [];
                }

                // Add entry to log structure
                logEntries[childId][appName].push({
                    slotIdentifier,
                    remainingTime
                });
            } catch (error) {
                console.error(`[APP TIME] Error updating remaining time for Child ID: ${childId}, Slot ID: ${slotIdentifier} - ${error.message}`);
                errorOccurred = true;
            }
        }
    }

    // Output the accumulated logs
    for (const childId in logEntries) {
        console.log(`CHILD ID: ${childId}`);
        for (const appName in logEntries[childId]) {
            console.log(`  App Name: ${appName}`);
            logEntries[childId][appName].forEach(slot => {
                console.log(`    SLOT #: ${slot.slotIdentifier}   REMAINING TIME: ${slot.remainingTime} seconds`);
            });
        }
    }

    if (errorOccurred) {
        return res ? res.status(500).json({ message: 'Error updating remaining time for some slots.' }) : null;
    } else {
        console.log('[APP TIME] Remaining time update completed successfully.');
        return res ? res.status(200).json({ message: 'Remaining time updated successfully.' }) : null;
    }
}

async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME - FORCED SYNCING TIME SLOTS STARTS]\nCHILD ID: ${childId}`);

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();

        if (appTimeManagementDocs && appTimeManagementDocs.length > 0) {
            for (const appTimeManagementDoc of appTimeManagementDocs) {
                const timeSlots = appTimeManagementDoc.time_slots;
                const appName = appTimeManagementDoc.app_name || 'Unknown';

                for (const timeSlot of timeSlots) {
                    const { slot_identifier, allowed_time, start_time, end_time } = timeSlot;

                    const now = new Date();
                    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
                    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
                    let remainingTime = now < slotStartTime ? allowed_time : now <= slotEndTime ? Math.ceil((slotEndTime - now) / 1000) : 0;

                    // Update or insert time slot in `remaining_app_time` collection
                    const filter = {
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        "time_slots.slot_identifier": new ObjectId(slot_identifier)
                    };

                    const existingDoc = await db.collection('remaining_app_time').findOne(filter);

                    if (existingDoc) {
                        await db.collection('remaining_app_time').updateOne(
                            filter,
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": start_time,
                                    "time_slots.$.end_time": end_time
                                }
                            }
                        );
                    } else {
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slot_identifier),
                                        remaining_time: remainingTime,
                                        start_time: start_time,
                                        end_time: end_time
                                    }
                                },
                                $set: { app_name: appName }
                            },
                            { upsert: true }
                        );
                    }
                }
            }
            broadcastUpdate(childId, appTimeManagementDocs.map(doc => doc.time_slots));
        } else {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
        }
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }

    console.log('[FORCED SYNCING TIME SLOTS FOR APP TIME COMPLETED]\n');
}

// Watch for changes in the `app_time_management` collection
function watchAppTimeManagementCollection(db) {
    const changeStream = db.collection('app_time_management').watch([], { fullDocument: 'updateLookup' });

    changeStream.on('change', async (change) => {
        if (['update', 'insert'].includes(change.operationType)) {
            const { child_id } = change.fullDocument;
            await syncAppTimeSlotsWithRemainingTime(db, child_id); // Sync the slots
        }
    });

    changeStream.on('error', (error) => console.error('[APP TIME] Error in change stream:', error));
}
// Reset app remaining times
async function resetRemainingAppTimes(db) {
    try {
        await db.collection('remaining_app_time').deleteMany({});
        console.log('[APP TIME] Remaining app time reset');
    } catch (error) {
        console.error('[APP TIME] Error resetting remaining time collections:', error);
    }
}

// Start real-time updates for app time
function startRealTimeUpdates(db, interval = 60 * 1000) {
    setInterval(() => checkAndUpdateRemainingAppTime(db), interval);
}
module.exports = {
    initializeWebSocket,
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    manualSyncRemainingAppTime,
    syncAppTimeSlotsWithRemainingTime,
    checkAndUpdateRemainingAppTime,
    watchAppTimeManagementCollection,
    resetRemainingAppTimes,
	startRealTimeUpdates
};*/

/*e upadte kay wala naga automatic update ang remainingtime
const { ObjectId } = require('mongodb');

// Get app time management for a specific child
async function getAppTimeManagement(req, res, db) {
    const childId = req.params.childId;
    console.log(`[APP TIME] Fetching app time management for child ID: ${childId}`);

    try {
        const appTimeManagement = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();
        if (!appTimeManagement || appTimeManagement.length === 0) {
            return res.status(404).json({ message: 'No app time slots found for the specified child.' });
        }
        res.status(200).json(appTimeManagement);
    } catch (error) {
        console.error('[APP TIME] Error fetching app time management data:', error.message);
        res.status(500).json({ message: 'Internal server error' });
    }
}

// Update remaining app time for a specific slot
async function updateRemainingAppTime(req, res, db) {
    const { childId, slotIdentifier, remainingTime } = req.body;
    if (!childId || !slotIdentifier || remainingTime === undefined) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    try {
        const result = await db.collection('remaining_app_time').updateOne(
            { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
            { $set: { "time_slots.$.remaining_time": remainingTime } },
            { upsert: true }
        );

        res.status(result.modifiedCount > 0 || result.upsertedCount > 0 ? 200 : 500).json({
            message: result.modifiedCount > 0 || result.upsertedCount > 0 ? '[APP TIME] Remaining time updated' : '[APP TIME] Failed to update remaining time'
        });
    } catch (error) {
        console.error('[APP TIME] Error updating remaining time:', error.message);
        res.status(500).json({ message: 'Internal server error' });
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
            return res.status(200).json({ remaining_time: timeSlot.remaining_time });
        } else {
            return res.status(404).json({ message: 'No remaining time found' });
        }
    } catch (error) {
        console.error('[APP TIME] Error fetching remaining time:', error.message);
        return res.status(500).json({ message: 'Internal server error' });
    }
}

// Manual sync for remaining app time
async function manualSyncRemainingAppTime(req, res, db) {
    console.log('[APP TIME] Manual Sync Started');
    const { deviceTime } = req.query;
    const deviceDateTime = deviceTime ? new Date(deviceTime) : new Date();

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();

        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;

            for (const timeSlot of timeSlots) {
                const slotIdentifier = timeSlot.slot_identifier;
                const allowedTime = timeSlot.allowed_time || 3600;

                const now = deviceDateTime;
                const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
                const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);
                let remainingTime = now < startTime ? allowedTime : now <= endTime ? Math.ceil((endTime - now) / 1000) : 0;

                await db.collection('remaining_app_time').updateOne(
                    { child_id: new ObjectId(childId), "time_slots.slot_identifier": new ObjectId(slotIdentifier) },
                    { $set: { "time_slots.$.remaining_time": remainingTime } },
                    { upsert: true }
                );
            }
        }

        res.status(200).json({ message: '[APP TIME] Manual sync completed' });
    } catch (error) {
        console.error('[APP TIME] Manual sync error:', error.message);
        res.status(500).json({ message: '[APP TIME] Manual sync failed', error: error.message });
    }
}

// Sync app time slots from app_time_management to remaining_app_time
async function syncAppTimeSlotsWithRemainingTime(db, childId) {
    console.log(`[APP TIME - FORCED SYNCING TIME SLOTS STARTS]\nCHILD ID: ${childId}`);

    try {
        const appTimeManagementDocs = await db.collection('app_time_management').find({ child_id: new ObjectId(childId) }).toArray();

        if (appTimeManagementDocs && appTimeManagementDocs.length > 0) {
            for (const appTimeManagementDoc of appTimeManagementDocs) {
                const timeSlots = appTimeManagementDoc.time_slots;
                const appName = appTimeManagementDoc.app_name;

                console.log(`\n  App Name: ${appName}`); // Log the app name for each app

                for (const timeSlot of timeSlots) {
                    const { slot_identifier, allowed_time, start_time, end_time } = timeSlot;

                    const now = new Date();
                    const slotStartTime = new Date(`${now.toDateString()} ${start_time}`);
                    const slotEndTime = new Date(`${now.toDateString()} ${end_time}`);
                    let remainingTime = now < slotStartTime ? allowed_time : now <= slotEndTime ? Math.ceil((slotEndTime - now) / 1000) : 0;

                    // First, check if the app and slot exist in remaining_app_time
                    const filter = {
                        child_id: new ObjectId(childId),
                        app_name: appName,
                        "time_slots.slot_identifier": new ObjectId(slot_identifier)
                    };

                    const existingDoc = await db.collection('remaining_app_time').findOne(filter);

                    if (existingDoc) {
                        // If the slot exists, update using the positional operator
                        const result = await db.collection('remaining_app_time').updateOne(
                            filter,
                            {
                                $set: {
                                    "time_slots.$.remaining_time": remainingTime,
                                    "time_slots.$.start_time": start_time,
                                    "time_slots.$.end_time": end_time
                                }
                            }
                        );

                        if (result.modifiedCount > 0) {
                            console.log(`     SLOT #${slot_identifier}: ${remainingTime} UPDATED`);
                        } else {
                            console.log(`     SLOT #${slot_identifier}: NO UPDATE (Already Synced)`);
                        }
                    } else {
                        // If the slot doesn't exist, insert it
                        await db.collection('remaining_app_time').updateOne(
                            { child_id: new ObjectId(childId), app_name: appName },
                            {
                                $push: {
                                    time_slots: {
                                        slot_identifier: new ObjectId(slot_identifier),
                                        remaining_time: remainingTime,
                                        start_time: start_time,
                                        end_time: end_time
                                    }
                                },
                                $set: { app_name: appName }
                            },
                            { upsert: true }
                        );
                        console.log(`     SLOT #${slot_identifier}: ${remainingTime} UPDATED (NEW ENTRY)`);
                    }
                }
            }
        } else {
            console.log(`[APP TIME] No app time management document found for child ID: ${childId}`);
        }
    } catch (error) {
        console.error(`[APP TIME] Error syncing app time slots: ${error.message}`);
    }

    console.log('[FORCED SYNCING TIME SLOTS FOR APP TIME COMPLETED]\n');
}


// Check and update remaining app time
async function checkAndUpdateRemainingAppTime(db, req = null, res = null) {
    let errorOccurred = false;

    // Get the device time from the request query or default to current time
    const { deviceTime } = req ? req.query : { deviceTime: null };
    const now = deviceTime ? new Date(deviceTime) : new Date(); // Use device or server time
    const timeSource = deviceTime ? `Device time: ${now.toISOString()}` : `Server time: ${now.toISOString()}`; // Time source

    // Log the time source
    console.log(`[APP TIME] (${timeSource})\nChecking and updating remaining time...\n`);

    try {
        const appTimeDocs = await db.collection('remaining_app_time').find().toArray();

        for (const doc of appTimeDocs) {
            const childId = doc.child_id;
            const appName = doc.app_name;

            if (!doc.time_slots || doc.time_slots.length === 0) {
                console.warn(`[APP TIME] No time slots found for app: ${appName}, child: ${childId}`);
                continue;
            }

            // Log the Child ID and App Name
            console.log(`Child ID: ${childId}\n  App Name: ${appName}`);

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

                    // Log the slot details under the current app
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

        console.log('\n(==================[APP TIME] Automatically Synced all slots==================)\n\n');

    } catch (error) {
        console.error('[APP TIME] Error checking and updating remaining app time:', error);
        if (res && res.status) {
            res.status(500).json({ message: 'Internal server error' });
        }
    }
}

// Watch for changes in app time management collection
function watchAppTimeManagementCollection(db, broadcastUpdate) {
    const changeStream = db.collection('app_time_management').watch([], { fullDocument: 'updateLookup' });

    changeStream.on('change', async (change) => {
        if (['update', 'insert'].includes(change.operationType)) {
            const { child_id, time_slots } = change.fullDocument;
            await syncAppTimeSlotsWithRemainingTime(db, new ObjectId(child_id));
            broadcastUpdate(child_id, time_slots);
        }
    });

    changeStream.on('error', (error) => console.error('[APP TIME] Error in change stream:', error));
}

// Reset app remaining times
async function resetRemainingAppTimes(db) {
    try {
        await db.collection('remaining_app_time').deleteMany({});
        console.log('[APP TIME] Remaining app time reset');
    } catch (error) {
        console.error('[APP TIME] Error resetting remaining time collections:', error);
    }
}

// Start real-time updates for app time
function startRealTimeUpdates(db, interval = 60 * 1000) {
    setInterval(() => checkAndUpdateRemainingAppTime(db), interval);
}

// Export functions
module.exports = {
    getAppTimeManagement,
    updateRemainingAppTime,
    getRemainingAppTime,
    manualSyncRemainingAppTime,
    checkAndUpdateRemainingAppTime,
    syncAppTimeSlotsWithRemainingTime,
    startRealTimeUpdates,
    watchAppTimeManagementCollection,
    resetRemainingAppTimes
};
*/