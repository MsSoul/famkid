//filename:server/server.js
require('dotenv').config();
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');

// imports
const { syncTimeSlot, startRealTimeUpdates, watchTimeManagementCollection, checkAndUpdateRemainingTime } = require('./time_management');
const appTime = require('./app_time');
const appManagementRoutes = require('./app_management');
const qrCodeConnection = require('./qr_code_connection');
const themeRoutes = require('./theme');
const pinRoutes = require('./pin');
const protectionService = require('./protection_service');

// Initialize Express
const app = express();
const port = process.env.PORT || 4452;
const websocketPort = process.env.WEBSOCKET_PORT || 4453;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

// Store connected WebSocket clients by childId
const clients = new Map();

wss.on('connection', (ws, req) => {
    const childId = req.url.replace('/?', ''); 
    console.log(`WebSocket connected for childId: ${childId}`);
    clients.set(childId, ws);

    ws.on('close', () => {
        console.log(`WebSocket closed for childId: ${childId}`);
        clients.delete(childId);
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error with client ${childId}:`, err);
    });
});

function notifyClient(childId, message) {
    const client = clients.get(childId);
    if (client && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ message }));
    }
}

async function loadRoutes(db) {
    const userRoutes = require('./user');
    const deviceInfoRoutes = require('./device_info');
    const appListRoutes = require('./app_list');
    const { router: appManagementRouter, blockApps } = appManagementRoutes(db);

    app.use('/api', userRoutes(db));
    app.use('/api', deviceInfoRoutes(db));
    app.use('/api', appListRoutes(db));
    app.use('/api', qrCodeConnection(db, notifyClient));
    app.use('/api', themeRoutes(db));
    app.use('/api', pinRoutes(db));
    app.use('/api', appManagementRouter);
    app.use('/api', protectionService(db));

    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    startRealTimeUpdates(db);

    app.get('/blocked-apps', async (req, res) => {
        const result = await blockApps(db, wss);
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    app.post('/block-and-run-management', async (req, res) => {
        try {
            const appManagementResult = await blockApps(db, wss);
            if (!appManagementResult.success) throw new Error(appManagementResult.message);

            await checkAndUpdateRemainingTime(db);
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });

    app.get('/child', async (req, res) => {
        try {
            const childProfile = await db.collection('child_registration').findOne();
            if (childProfile) {
                res.json({ childId: childProfile._id });
            } else {
                res.status(404).json({ error: 'Child not found' });
            }
        } catch (error) {
            res.status(500).json({ error: 'Failed to fetch child ID' });
        }
    });
}

async function connectToDatabase() {
    try {
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);

        await loadRoutes(db);

        const timeManagementDocs = await db.collection('time_management').find({}).toArray();
        for (const doc of timeManagementDocs) {
            const childId = doc.child_id;
            const timeSlots = doc.time_slots;
            //console.log(`Syncing time slots for child ID: ${childId}`);
            if (timeSlots && timeSlots.length > 0) {
                await syncTimeSlot(db, childId, timeSlots);
            } else {
                console.log(`[TIME MANAGEMENT] No time slots found for child ID: ${childId}`);
            }
        }

        const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            //console.log(`Syncing app time slots for child ID: ${childId}`);
            await appTime.syncAppTimeSlotsWithRemainingTime(db, childId);
        }

        startRealTimeUpdates(db, 60 * 1000);
        console.log('[REAL-TIME UPDATES] Started real-time updates for remaining time.');

        watchTimeManagementCollection(db, notifyClient);
        console.log('[CHANGE STREAM] Watching time_management for changes.');

        cron.schedule('* * * * *', async () => {
            console.log('\n-------------------------------------------------------------------\n[*****AUTO SYNC STARTS******]\n');
            try {
                await appTime.checkAndUpdateRemainingAppTime(db);
                await checkAndUpdateRemainingTime(db);
                console.log('\n[*****AUTO SYNC COMPLETED******]\n');
            } catch (error) {
                console.error('[AUTO SYNC] Error during time sync:', error);
            }
        });

        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time...');
            try {
                await timeManagement.resetRemainingTimes(db);
                await appTime.resetRemainingAppTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Daily reset completed.');
            } catch (error) {
                console.error('Error during daily reset:', error);
            }
        });

    } catch (err) {
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

connectToDatabase().then(() => {
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    });
});

/*
require('dotenv').config();
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');

// imports
const timeManagement = require('./time_management');
const appTime = require('./app_time');
const appManagementRoutes = require('./app_management');
const qrCodeConnection = require('./qr_code_connection');
const themeRoutes = require('./theme');
const pinRoutes = require('./pin');

// Initialize Express
const app = express();
const port = process.env.PORT || 5164;
const websocketPort = process.env.WEBSOCKET_PORT || 5165;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

// Store connected WebSocket clients by childId
const clients = new Map();

// WebSocket connections for QR code (simplified)
wss.on('connection', (ws, req) => {
    const childId = req.url.replace('/?', ''); // Assuming childId is sent in the connection URL
    console.log(`WebSocket connected for childId: ${childId}`);
    clients.set(childId, ws); // Store the connection

    ws.on('close', () => {
        console.log(`WebSocket closed for childId: ${childId}`);
        clients.delete(childId); // Remove client on disconnect
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error with client ${childId}:`, err);
    });
});

// Function to notify a WebSocket client by childId
function notifyClient(childId, message) {
    const client = clients.get(childId);
    if (client && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ message }));
    }
}

// Function to load routes after MongoDB connection
async function loadRoutes(db) {
    const userRoutes = require('./user');
    const deviceInfoRoutes = require('./device_info');
    const appListRoutes = require('./app_list');

    // Import routes and functions from app_management.js
    const { router: appManagementRouter, blockApps } = appManagementRoutes(db);

    // routes
    app.use('/api', userRoutes(db));
    app.use('/api', deviceInfoRoutes(db));
    app.use('/api', appListRoutes(db));
    app.use('/api', qrCodeConnection(db, notifyClient));
    app.use('/api', themeRoutes(db));
    app.use('/api', pinRoutes(db));
    app.use('/api', appManagementRouter); // use the app management router

    // Time Management Routes
    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    timeManagement.startRealTimeUpdates(db);

    // App Management Routes
    app.get('/blocked-apps', async (req, res) => {
        const result = await blockApps(db, wss); // Use blockApps function here
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    // Pass WebSocket server (wss) to the blockApps function
    app.post('/block-and-run-management', async (req, res) => {
        try {
            const appManagementResult = await blockApps(db, wss); // Pass the WebSocket server
            if (!appManagementResult.success) throw new Error(appManagementResult.message);

            await timeManagement.checkAndUpdateRemainingTime(db);
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    // Routes to lock/unlock devices
    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });

    // Route to fetch childId
    app.get('/child', async (req, res) => {
        try {
            const childProfile = await db.collection('child_registration').findOne();
            if (childProfile) {
                res.json({ childId: childProfile._id });
            } else {
                res.status(404).json({ error: 'Child not found' });
            }
        } catch (error) {
            res.status(500).json({ error: 'Failed to fetch child ID' });
        }
    });
}

// Connect to MongoDB and load routes
async function connectToDatabase() {
    try {
        // Connect to MongoDB
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);

        // Load the application routes
        await loadRoutes(db);

        // Sync the app time management to remaining app time at server start
        const appTimeManagementDocs = await db.collection('app_time_management').find({}).toArray();
        for (const doc of appTimeManagementDocs) {
            const childId = doc.child_id;
            console.log(`Syncing app time slots for child ID: ${childId}`); // Log the childId for verification
            await appTime.syncAppTimeSlotsWithRemainingTime(db, childId); // Ensure this method is defined
        }

        // Start real-time updates for remaining time every minute
        timeManagement.startRealTimeUpdates(db, 60 * 1000);  // Automatically updates every 1 minute
        console.log('[REAL-TIME UPDATES] Started real-time updates for remaining time.');

        // Start watching the `time_management` collection for changes
        timeManagement.watchTimeManagementCollection(db, notifyClient);
        console.log('[CHANGE STREAM] Watching time_management for changes.');

        // Set up cron job to sync time every minute
        cron.schedule('* * * * *', async () => {
            console.log('\n[**AUTO SYNC**] Starting time sync...');
            try {
                // Sync remaining app time and remaining time every minute
                await appTime.checkAndUpdateRemainingAppTime(db);
                await timeManagement.checkAndUpdateRemainingTime(db);
                console.log('[AUTO SYNC] Time sync completed.');
            } catch (error) {
                console.error('[AUTO SYNC] Error during time sync:', error);
            }
        });

        // Set up cron job to reset remaining time and app time at midnight every day
        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time...');
            try {
                // Reset remaining time and app time at midnight
                await timeManagement.resetRemainingTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Daily reset completed.');
            } catch (error) {
                console.error('Error during daily reset:', error);
            }
        });

    } catch (err) {
        // Handle MongoDB connection error
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

// Start the server
connectToDatabase().then(() => {
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    });
});
*/

/*ilisan kay wla pa na update and time management
require('dotenv').config();
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');

//imports
const timeManagement = require('./time_management');
const appTime = require('./app_time');
const appManagementRoutes = require('./app_management');
const qrCodeConnection = require('./qr_code_connection');
const themeRoutes = require('./theme');
const pinRoutes = require('./pin');

// Initialize Express
const app = express();
const port = process.env.PORT || 5164;
const websocketPort = process.env.WEBSOCKET_PORT || 5165;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

// Store connected WebSocket clients by childId
const clients = new Map();

// WebSocket connections for QR code (simplified)
wss.on('connection', (ws, req) => {
    const childId = req.url.replace('/?', ''); // Assuming childId is sent in the connection URL
    console.log(`WebSocket connected for childId: ${childId}`);
    clients.set(childId, ws); // Store the connection

    ws.on('close', () => {
        console.log(`WebSocket closed for childId: ${childId}`);
        clients.delete(childId); // Remove client on disconnect
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error with client ${childId}:`, err);
    });
});

// Function to notify a WebSocket client by childId
function notifyClient(childId, message) {
    const client = clients.get(childId);
    if (client && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ message }));
    }
}

// Function to load routes after MongoDB connection
async function loadRoutes(db) {
    const userRoutes = require('./user');
    const deviceInfoRoutes = require('./device_info');
    const appListRoutes = require('./app_list');

    // Import routes and functions from app_management.js
    const { router: appManagementRouter, blockApps} = appManagementRoutes(db);

    //routes
    app.use('/api', userRoutes(db));
    app.use('/api', deviceInfoRoutes(db));
    app.use('/api', appListRoutes(db));
    app.use('/api', qrCodeConnection(db, notifyClient));
    app.use('/api', themeRoutes(db));
    app.use('/api', pinRoutes(db));
    app.use('/api', appManagementRouter); // use the app management router

    // Time Management Routes
    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    // App Management Routes
    app.get('/blocked-apps', async (req, res) => {
        const result = await blockApps(db, wss); // Use blockApps function here
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    // Pass WebSocket server (wss) to the blockApps function
    app.post('/block-and-run-management', async (req, res) => {
        try {
            const appManagementResult = await blockApps(db, wss); // Pass the WebSocket server
            if (!appManagementResult.success) throw new Error(appManagementResult.message);

            await timeManagement.checkAndUpdateRemainingTime(db);
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    // Routes to lock/unlock devices
    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });

    // Route to fetch childId
    app.get('/child', async (req, res) => {
        try {
            const childProfile = await db.collection('child_registration').findOne(your query logic here );
            if (childProfile) {
                res.json({ childId: childProfile._id });
            } else {
                res.status(404).json({ error: 'Child not found' });
            }
        } catch (error) {
            res.status(500).json({ error: 'Failed to fetch child ID' });
        }
    });
}

// Connect to MongoDB and load routes
async function connectToDatabase() {
    try {
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);
        await loadRoutes(db);

        // Start monitoring for changes in the app_management collection
       const { startMonitoring } = require('./app_management')(db); // Import startMonitoring properly
        await startMonitoring(db); // Use startMonitoring function here

        // Set up cron jobs
        cron.schedule('* * * * *', async () => {
            console.log('\n[**AUTO SYNC APP TIME**] Starting time sync...\n');
            await appTime.checkAndUpdateRemainingAppTime(db);
            await timeManagement.checkAndUpdateRemainingTime(db);
            console.log('\n[AUTO SYNC] Time sync completed.');
        });

        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time...');
            try {
                await timeManagement.resetRemainingTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Daily reset completed.');
            } catch (error) {
                console.error('Error during daily reset:', error);
            }
        });

    } catch (err) {
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

// Start the server
connectToDatabase().then(() => {
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    });
});
*/

/*ilisan lang kay dli ma block ang apps
require('dotenv').config();
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');

//imports
const timeManagement = require('./time_management');
const appTime = require('./app_time');
const appManagement = require('./app_management');
const qrCodeConnection = require('./qr_code_connection');
const themeRoutes = require('./theme'); 
const pinRoutes = require('./pin');

// Initialize Express
const app = express();
const port = process.env.PORT || 5164;
const websocketPort = process.env.WEBSOCKET_PORT || 5165;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

// Store connected WebSocket clients by childId
const clients = new Map();

// WebSocket connections for QR code (simplified)
wss.on('connection', (ws, req) => {
    const childId = req.url.replace('/?', ''); // Assuming childId is sent in the connection URL
    console.log(`WebSocket connected for childId: ${childId}`);
    clients.set(childId, ws); // Store the connection

    ws.on('close', () => {
        console.log(`WebSocket closed for childId: ${childId}`);
        clients.delete(childId); // Remove client on disconnect
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error with client ${childId}:`, err);
    });
});

// Function to notify a WebSocket client by childId
function notifyClient(childId, message) {
    const client = clients.get(childId);
    if (client && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ message }));
    }
}

// Function to lock/unlock device based on time management
async function checkAndHandleDeviceLock(childId) {
    const timeManagementDoc = await db.collection('time_management').findOne({ child_id: ObjectId(childId) });
    if (timeManagementDoc && timeManagementDoc.time_slots) {
        const now = new Date();
        const isWithinTimeSlot = timeManagementDoc.time_slots.some(slot => {
            const startTime = new Date(`${now.toDateString()} ${slot.start_time}`);
            const endTime = new Date(`${now.toDateString()} ${slot.end_time}`);
            return now >= startTime && now <= endTime;
        });

        if (isWithinTimeSlot) {
            await unlockDevice(childId);
        } else {
            await lockDevice(childId);
        }
    }
}

// Lock and Unlock Device Placeholder
async function lockDevice(childId) {
    console.log(`Locking device for child ${childId}`);
    // Implement device locking logic (e.g., sending a signal or database update)
}

async function unlockDevice(childId) {
    console.log(`Unlocking device for child ${childId}`);
    // Implement device unlocking logic (e.g., sending a signal or database update)
}

// Function to load routes after MongoDB connection
async function loadRoutes(db) {
    const userRoutes = require('./user');
    const deviceInfoRoutes = require('./device_info');
    const appListRoutes = require('./app_list');


    //routes
    app.use('/api', userRoutes(db));
    app.use('/api', deviceInfoRoutes(db));
    app.use('/api', appListRoutes(db));
    app.use('/api', qrCodeConnection(db, notifyClient));
    app.use('/api', themeRoutes(db));
    app.use('/api', pinRoutes(db));
    
    // Time Management Routes
    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    // App Management Routes
    app.get('/blocked-apps', async (req, res) => {
        const result = await appManagement.blockApps(db, wss);
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    // Pass WebSocket server (wss) to the blockApps function
    app.post('/block-and-run-management', async (req, res) => {
        try {
            const appManagementResult = await appManagement.blockApps(db, wss); // Pass the WebSocket server
            if (!appManagementResult.success) throw new Error(appManagementResult.message);

            await timeManagement.checkAndUpdateRemainingTime(db);
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    // Routes to lock/unlock devices
    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });
    // Route to fetch childId
app.get('/child', async (req, res) => {
    try {
      const childProfile = await db.collection('child_registration').findOne(/* your query logic here );
      if (childProfile) {
        res.json({ childId: childProfile._id });
      } else {
        res.status(404).json({ error: 'Child not found' });
      }
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch child ID' });
    }
  });
}

// Connect to MongoDB and load routes
async function connectToDatabase() {
    try {
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);
        await loadRoutes(db);

        // Set up cron jobs
        cron.schedule('* * * * *', async () => {
            console.log('\n[**AUTO SYNC APP TIME**] Starting time sync...\n');
            await appTime.checkAndUpdateRemainingAppTime(db);
            await timeManagement.checkAndUpdateRemainingTime(db);
            console.log('\n[AUTO SYNC] Time sync completed.');
        });

        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time...');
            try {
                await timeManagement.resetRemainingTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Daily reset completed.');
            } catch (error) {
                console.error('Error during daily reset:', error);
            }
        });

    } catch (err) {
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

// Start the server
connectToDatabase().then(() => {
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    });
});
*/
/*
// filename: server/server.js (MUGANA NA NI MO DISPLAY UG SUCCESSFUL CONNECTION SA QRCODE)
require('dotenv').config();
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');
const timeManagement = require('./time_management');
const appTime = require('./app_time');
const appManagement = require('./app_management');
const qrCodeConnection = require('./qr_code_connection');// Import qr_code_connection.js as a function

// Initialize Express
const app = express();
const port = process.env.PORT || 3864;
const websocketPort = process.env.WEBSOCKET_PORT || 3865;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

// Broadcast update to all connected WebSocket clients
function broadcastUpdate(slotIdentifier, remainingTime) {
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ slotIdentifier, remainingTime }));
        }
    });
}

// WebSocket connections for QR code (simplified)
wss.on('connection', (ws, req) => {
    const childId = req.url.replace('/?', ''); // Assuming childId is sent in the connection URL
    console.log(`WebSocket connected for childId: ${childId}`);

    ws.on('close', () => {
        console.log(`WebSocket closed for childId: ${childId}`);
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error with client ${childId}:`, err);
    });
});

// Function to lock/unlock device based on time management
async function checkAndHandleDeviceLock(childId) {
    const timeManagementDoc = await db.collection('time_management').findOne({ child_id: ObjectId(childId) });
    if (timeManagementDoc && timeManagementDoc.time_slots) {
        const now = new Date();
        const isWithinTimeSlot = timeManagementDoc.time_slots.some(slot => {
            const startTime = new Date(`${now.toDateString()} ${slot.start_time}`);
            const endTime = new Date(`${now.toDateString()} ${slot.end_time}`);
            return now >= startTime && now <= endTime;
        });

        if (isWithinTimeSlot) {
            await unlockDevice(childId);
        } else {
            await lockDevice(childId);
        }
    }
}

// Lock and Unlock Device Placeholder
async function lockDevice(childId) {
    console.log(`Locking device for child ${childId}`);
    // Implement device locking logic (e.g., sending a signal or database update)
}

async function unlockDevice(childId) {
    console.log(`Unlocking device for child ${childId}`);
    // Implement device unlocking logic (e.g., sending a signal or database update)
}

// Function to load routes after MongoDB connection
async function loadRoutes(db) {
    const userRoutes = require('./user');
    const deviceInfoRoutes = require('./device_info');
    const appListRoutes = require('./app_list');

    app.use('/api', userRoutes(db));
    app.use('/api', deviceInfoRoutes(db));
    app.use('/api', appListRoutes(db));
    app.use('/api', qrCodeConnection(db));

  
    // Time Management Routes
    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    // App Management Routes
    app.post('/block-apps', async (req, res) => {
        const result = await appManagement.blockApps(db, wss);
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    // Pass WebSocket server (wss) to the blockApps function
    app.post('/block-and-run-management', async (req, res) => {
        try {
            const appManagementResult = await appManagement.blockApps(db, wss); // Pass the WebSocket server
            if (!appManagementResult.success) throw new Error(appManagementResult.message);

            await timeManagement.checkAndUpdateRemainingTime(db);
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    // Routes to lock/unlock devices
    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });

    // Fetch theme settings route
    app.get('/theme', async (req, res) => {
        const adminId = req.query.admin_id;

        try {
            const theme = await db.collection('theme_management').findOne({ admin_id: new ObjectId(adminId) });
            if (!theme) {
                return res.status(404).json({ message: 'Theme not found' });
            }
            res.status(200).json(theme);
        } catch (error) {
            console.error('Error fetching theme:', error);
            res.status(500).json({ message: 'Internal server error' });
        }
    });
    
}

// Connect to MongoDB and load routes
async function connectToDatabase() {
    try {
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);
        await loadRoutes(db);

        // Set up cron jobs
        cron.schedule('* * * * *', async () => {
            console.log('[AUTO SYNC] Starting time sync...');
            await appTime.checkAndUpdateRemainingAppTime(db);
            await timeManagement.checkAndUpdateRemainingTime(db);
            console.log('[AUTO SYNC] Time sync completed.');
        });

        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time...');
            try {
                await timeManagement.resetRemainingTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Daily reset completed.');
            } catch (error) {
                console.error('Error during daily reset:', error);
            }
        });

    } catch (err) {
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

// Start the server
connectToDatabase().then(() => {
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    });
});

*/
/*
require('dotenv').config(); 
const cron = require('node-cron');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const { MongoClient, ObjectId } = require('mongodb');
const WebSocket = require('ws');
const timeManagement = require('./time_management'); 
const appTime = require('./app_time');
const appManagement = require('./app_management'); 
const qrCodeConnection = require('./qr_code_connection');


// Initialize Express
const app = express()
const port = process.env.PORT || 4656;
const websocketPort = process.env.WEBSOCKET_PORT || 4657;

// Middleware setup
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan('dev'));

// MongoDB connection URL
const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME;

// Initialize MongoClient
const client = new MongoClient(uri);

let db;

// WebSocket setup
const wss = new WebSocket.Server({ port: websocketPort });
console.log(`WebSocket Server running on ws://localhost:${websocketPort}`);

function broadcastUpdate(slotIdentifier, remainingTime) {
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ slotIdentifier, remainingTime }));
        }
    });
}

// Function to lock a device
async function lockDevice(childId) {
    console.log(`Locking device for child ${childId}`);
    // Implement your device locking logic here
}

// Function to unlock a device
async function unlockDevice(childId) {
    console.log(`Unlocking device for child ${childId}`);
    // Implement your device unlocking logic here
}

// Function to check and handle device lock/unlock based on time management
async function checkAndHandleDeviceLock(childId) {
    const timeManagementDoc = await db.collection('time_management').findOne({ child_id: ObjectId(childId) });

    if (timeManagementDoc && timeManagementDoc.time_slots) {
        const timeSlots = timeManagementDoc.time_slots;
        const now = new Date();

        let isWithinTimeSlot = false;

        for (const timeSlot of timeSlots) {
            const startTime = new Date(`${now.toDateString()} ${timeSlot.start_time}`);
            const endTime = new Date(`${now.toDateString()} ${timeSlot.end_time}`);

            if (now >= startTime && now <= endTime) {
                isWithinTimeSlot = true;
                break;
            }
        }

        if (isWithinTimeSlot) {
            await unlockDevice(childId);
        } else {
            await lockDevice(childId);
        }
    }
}

// Function to load routes after MongoDB connection
async function loadRoutes(db) {
    const userRoutes = require('./user');
    app.use('/api', userRoutes(db));

    const deviceInfoRoutes = require('./device_info');
    app.use('/api', deviceInfoRoutes(db));

    const appListRoutes = require('./app_list');
    app.use('/api', appListRoutes(db));

    // Time Management Routes
    app.get('/time-management/:childId', (req, res) => timeManagement.getTimeManagement(req, res, db));
    app.post('/update-remaining-time', (req, res) => timeManagement.updateRemainingTime(req, res, db));
    app.get('/get-remaining-time', (req, res) => timeManagement.getRemainingTime(req, res, db));
    app.post('/manual-sync-remaining-time', (req, res) => timeManagement.manualSyncRemainingTime(req, res, db));

    // App Time Management Routes
    app.get('/app-time-management/:childId', (req, res) => appTime.getAppTimeManagement(req, res, db));
    app.post('/update-remaining-app-time', (req, res) => appTime.updateRemainingAppTime(req, res, db));
    app.get('/get-remaining-app-time', (req, res) => appTime.getRemainingAppTime(req, res, db));
    app.post('/manual-sync-remaining-app-time', (req, res) => appTime.manualSyncRemainingAppTime(req, res, db));

    // App Management Routes
    app.post('/block-apps', async (req, res) => {
        const result = await appManagement.blockApps(db, wss);
        res.status(result.success ? 200 : 500).send({ message: result.message });
    });

    // Combined Endpoint for App Blocking and Time Management Sync
    app.post('/block-and-run-management', async (req, res) => {
        try {
            // Run the blockApps function from app_management.js
            const appManagementResult = await appManagement.blockApps(db, wss);
            if (!appManagementResult.success) {
                throw new Error(appManagementResult.message);
            }

            // Run the time management sync
            await timeManagement.checkAndUpdateRemainingTime(db);

            // Run the app time management sync
            await appTime.checkAndUpdateRemainingAppTime(db);

            res.status(200).send({ message: 'Apps blocked and management processes executed successfully.' });
        } catch (error) {
            console.error('Error during block-and-run-management:', error);
            res.status(500).send({ message: 'Error during management processes.' });
        }
    });

    // Routes to lock/unlock devices
    app.post('/lock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await lockDevice(childId);
            res.status(200).send(`Device locked for child ${childId}`);
        } catch (error) {
            console.error(`Error locking device for child ${childId}:`, error);
            res.status(500).send(`Error locking device for child ${childId}`);
        }
    });

    app.post('/unlock-device/:childId', async (req, res) => {
        const childId = req.params.childId;
        try {
            await unlockDevice(childId);
            res.status(200).send(`Device unlocked for child ${childId}`);
        } catch (error) {
            console.error(`Error unlocking device for child ${childId}:`, error);
            res.status(500).send(`Error unlocking device for child ${childId}`);
        }
    });

    // Populate remaining_time and remaining_app_time collections on startup
    console.log('Populating remaining_time and remaining_app_time collections on startup...');
    await timeManagement.manualSyncRemainingTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
    await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);

    // Start watching collections for changes
    timeManagement.watchTimeManagementCollection(db, broadcastUpdate);

    // Fetch theme settings route
    app.get('/theme', async (req, res) => {
        const adminId = req.query.admin_id;

        try {
            const theme = await db.collection('theme_management').findOne({ admin_id: new ObjectId(adminId) });
            if (!theme) {
                return res.status(404).json({ message: 'Theme not found' });
            }
            res.status(200).json(theme);
        } catch (error) {
            console.error('Error fetching theme:', error);
            res.status(500).json({ message: 'Internal server error' });
        }
    });
}

// Connect to MongoDB and load routes
async function connectToDatabase() {
    try {
        await client.connect();
        console.log('Connected to MongoDB');
        db = client.db(dbName);
        await loadRoutes(db);

        // Set up cron job to update remaining app time every minute
        cron.schedule('* * * * *', async () => {
            console.log('\n====================[APP TIME] Auto Sync Start====================\n');
            await appTime.checkAndUpdateRemainingAppTime(db);
            console.log('\n====================[APP TIME] Auto Sync End====================\n');

            // After app time sync is complete, run time management sync
            console.log('\n====================[TIME MANAGEMENT] Auto Sync Start====================\n');
            await timeManagement.checkAndUpdateRemainingTime(db);
            console.log('\n====================[TIME MANAGEMENT] Auto Sync End====================\n');
        });

        // Set up cron job to reset remaining time collections at midnight
        cron.schedule('0 0 * * *', async () => {
            console.log('Running daily reset of remaining time and remaining app time collections at midnight');
            try {
                await timeManagement.resetRemainingTimes(db);
                await appTime.manualSyncRemainingAppTime({ query: {} }, { status: () => ({ json: console.log }) }, db);
                console.log('Remaining time and remaining app time collections reset successfully.');
            } catch (error) {
                console.error('Error during midnight reset:', error);
            }
        });

    } catch (err) {
        console.error('Error connecting to MongoDB:', err.message);
        process.exit(1);
    }
}

// Connect to the database before starting the server
connectToDatabase().then(() => {
    // Default route
    app.get('/', (req, res) => {
        res.send('Hello, server is running!');
    });

    // Start HTTP server
    app.listen(port, () => {
        console.log(`HTTP Server running on port ${port}`);
    }).on('error', (err) => {
        console.error('Error starting server:', err);
    });
});

*/