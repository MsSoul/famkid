//filename:server/app_management.js
const express = require('express');
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');
const router = express.Router();

console.log('[APP MANAGEMENT] app_management.js module loaded and running.');

function appManagementRoutes(db) {
    
    // Function to fetch apps directly from app_management collection
    router.get('/fetch-apps', async (req, res) => {
        const childId = req.query.childId;
    
        console.log('Fetching apps for Child ID:', childId);
    
        if (!childId) {
            console.log('Error: Child ID is missing');
            return res.status(400).json({ success: false, message: 'Child ID is required.' });
        }
    
        try {
            const appManagementCollection = db.collection('app_management');
            const query = { child_id: ObjectId.isValid(childId) ? new ObjectId(childId) : childId };
            console.log('Querying app_management collection with query:', query);
    
            const appsDoc = await appManagementCollection.findOne(query);
            console.log('Fetched document:', appsDoc);
    
            if (!appsDoc || !appsDoc.apps) {
                console.log('No apps found for this child.');
                return res.status(200).json({
                    success: true,
                    message: 'No apps to block or allow.',
                    apps: []
                });
            }
    
            // Return the app list with is_allowed field
            return res.status(200).json({
                success: true,
                message: 'Apps retrieved successfully.',
                apps: appsDoc.apps
            });
        } catch (error) {
            console.error('Error fetching apps from app_management collection:', error);
            return res.status(500).json({
                success: false,
                message: 'Failed to fetch apps.',
                apps: []
            });
        }
    });
    

    // WebSocket Function for blocking/unblocking apps
    function blockAppOnDevice(app, wss) {
        console.log(`Sending block/unblock command for app: ${app.package_name}`);

        if (wss && wss.clients) {
            wss.clients.forEach((client) => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify({
                        action: app.is_blocked ? 'blockApp' : 'unblockApp',
                        packageName: app.package_name
                    }));

                    // Expect response from the device
                    client.on('message', (message) => {
                        const data = JSON.parse(message);
                        console.log('Message received from client:', data);

                        if (data.status === 'success' && data.packageName === app.package_name) {
                            console.log(`App ${app.package_name} was ${app.is_blocked ? 'blocked' : 'unblocked'} successfully on the device.`);
                        } else {
                            console.error(`Failed to ${app.is_blocked ? 'block' : 'unblock'} app ${app.package_name} on the device.`);
                        }
                    });
                }
            });
        } else {
            console.error('WebSocket server is not available.');
        }
    }

    // Function to block/unblock apps from the app_management collection
    async function blockAppsFromAppManagement(db, wss) {
        try {
            const appManagementCollection = db.collection('app_management');
            const appsToBlock = await appManagementCollection.find({ 'apps.is_allowed': false }).toArray();

            if (appsToBlock.length === 0) {
                console.log('No apps to block.');
                return { success: true, message: 'No apps to block.' };
            }

            for (const doc of appsToBlock) {
                for (const app of doc.apps) {
                    if (!app.is_allowed) {
                        blockAppOnDevice(app, wss);
                    }
                }
            }

            return { success: true, message: 'Apps blocked/unblocked successfully.' };
        } catch (error) {
            console.error('Error blocking/unblocking apps:', error);
            return { success: false, message: 'Failed to block/unblock apps.' };
        }
    }

    // API route to fetch apps and block/unblock based on app_management collection
    router.get('/blocked-apps', async (req, res) => {
        const childId = req.query.childId;
        console.log('Fetching blocked apps for Child ID:', childId);

        if (!childId) {
            console.log('Error: Child ID is missing');
            return res.status(400).json({ success: false, message: 'Child ID is required.' });
        }

        try {
            const appManagementCollection = db.collection('app_management');
            const query = { child_id: ObjectId.isValid(childId) ? new ObjectId(childId) : childId };
            console.log('Querying app_management collection with query:', query);

            const appsDoc = await appManagementCollection.findOne(query);
            console.log('Fetched document:', appsDoc);

            if (!appsDoc || !appsDoc.apps) {
                console.log('No apps found for this child.');
                return res.status(200).json({
                    success: true,
                    message: 'No apps to block or allow.',
                    blocked_apps: [],
                    allowed_apps: []
                });
            }

            const blockedApps = appsDoc.apps.filter(app => !app.is_allowed).map(app => ({
                package_name: app.package_name,
                is_blocked: true
            }));
            const allowedApps = appsDoc.apps.filter(app => app.is_allowed).map(app => ({
                package_name: app.package_name,
                is_blocked: false
            }));

            console.log('Blocked Apps:', blockedApps);
            console.log('Allowed Apps:', allowedApps);

            return res.status(200).json({
                success: true,
                message: 'Apps retrieved successfully.',
                blocked_apps: blockedApps,
                allowed_apps: allowedApps
            });
        } catch (error) {
            console.error('Error fetching apps from app_management collection:', error);
            return res.status(500).json({
                success: false,
                message: 'Failed to fetch apps.',
                blocked_apps: [],
                allowed_apps: []
            });
        }
    });

    return { router, blockAppsFromAppManagement};
}

module.exports = appManagementRoutes;


/*mugana kaso no apps to block ang error
const express = require('express');
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');
const app = express();

app.use(express.json()); // Ensure you can parse JSON request bodies

console.log('[APP MANAGEMENT] app_management.js module loaded and running.');

// Function to fetch blocked apps based on child ID
app.get('/blocked-apps', async (req, res) => {
    const childId = req.query.childId;

    if (!childId) {
        return res.status(400).json({ success: false, message: 'Child ID is required.' });
    }

    try {
        const appManagementCollection = req.app.locals.db.collection('app_management');

        // Log the childId and ObjectId conversion status
        console.log('Received Child ID:', childId);
        const query = { 
            child_id: ObjectId.isValid(childId) ? ObjectId(childId) : childId,
            is_allowed: false 
        };

        // Log the query being used
        console.log('MongoDB Query:', query); 

        const appsToBlock = await appManagementCollection.find(query).toArray();

        // Log the apps retrieved from the database
        console.log('Apps retrieved from DB:', appsToBlock);

        if (appsToBlock.length === 0) {
            return res.status(200).json({
                success: true,
                message: 'No apps to block.',
                apps: []  // Always return an array for apps
            });
        }

        return res.status(200).json({
            success: true,
            message: 'Blocked apps retrieved.',
            apps: appsToBlock.map(app => ({ package_name: app.package_name }))
        });
    } catch (error) {
        console.error('Error fetching blocked apps:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch blocked apps.',
            apps: []  // Return an empty array even in case of error
        });
    }
});



// Function to block apps from the database and send commands via WebSocket
async function blockApps(db, wss) {
    try {
      const appManagementCollection = db.collection('app_management');
      const appsToBlock = await appManagementCollection.find({ is_allowed: false }).toArray();
  
      if (appsToBlock.length === 0) {
        return { success: true, message: 'No apps to block.', apps: [] };
      }
  
      for (const app of appsToBlock) {
        blockAppOnDevice(app, wss);
      }
  
      // Modify the return statement to reflect the actual block status
      return { success: true, message: 'Apps blocked successfully.', apps: appsToBlock.map(app => ({ package_name: app.package_name })) };
    } catch (error) {
      return { success: false, message: 'Failed to block apps.', apps: [] };
    }
}

// WebSocket Function for blocking apps
function blockAppOnDevice(app, wss) {
    console.log(`Sending block command for app: ${app.package_name}`);

    // Check if WebSocket Server is available and broadcast the block command
    if (wss && wss.clients) {
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                    action: 'blockApp',
                    packageName: app.package_name  // Send the app's package name to the client
                }));

                // Expect a response from the client confirming the block action
                client.on('message', (message) => {
                    const data = JSON.parse(message);
                    console.log('Message received from client:', data); // Log the incoming message
                  
                    if (data.status === 'blocked' && data.packageName === app.package_name) {
                      console.log(`App ${app.package_name} was blocked successfully on the device.`);
                    } else {
                      console.error(`Failed to block app ${app.package_name} on the device. Response:`, data);
                    }
                  });
            }
        });
    }
}

module.exports = { app, blockApps };*/

/*wla ko kabalo kung ga dagan bani haha
// filename: server/app_management.js
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');

console.log('[APP MANAGEMENT] app_management.js module loaded and running.');

async function blockApps(db, wss) {
    try {
        const appManagementCollection = db.collection('app_management');

        // Fetch apps with is_allowed = false
        const appsToBlock = await appManagementCollection.find({ is_allowed: false }).toArray();
        console.log('Apps to block:', appsToBlock);

        if (appsToBlock.length === 0) {
            console.log('No apps need to be blocked.');
            return { success: true, message: 'No apps to block.' };
        }

        // Block these apps using WebSocket to communicate with devices
        for (const app of appsToBlock) {
            console.log(`Blocking app: ${app.app_name}`);
            blockAppOnDevice(app, wss); // Use the passed WebSocket server (wss)
        }

        return { success: true, message: 'Apps blocked successfully.' };
    } catch (error) {
        console.error('Error blocking apps:', error);
        return { success: false, message: 'Failed to block apps.' };
    }
}

// Function to send a WebSocket command to block an app on the device
function blockAppOnDevice(app, wss) {
    console.log(`Sending block command for app: ${app.app_name}`);

    // Check if WebSocket Server is available and broadcast the block command
    if (wss && wss.clients) {
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                    action: 'blockApp',
                    packageName: app.package_name // Send the app's package name to the client
                }));
                console.log(`Sent blockApp command for ${app.package_name}`);
            } else {
                console.error('WebSocket client is not open.');
            }
        });
    } else {
        console.error('WebSocket server is not available or not properly initialized.');
    }
}

module.exports = { blockApps };

*/
/*
const { ObjectId } = require('mongodb');
const WebSocket = require('ws');

console.log('[APP MANAGEMENT] app_management.js module loaded and running.');

async function blockApps(db, wss) {
    try {
        const appManagementCollection = db.collection('app_management');

        // Fetch apps with is_allowed = false
        const appsToBlock = await appManagementCollection.find({ is_allowed: false }).toArray();

        if (appsToBlock.length === 0) {
            console.log('No apps need to be blocked.');
            return { success: true, message: 'No apps to block.' };
        }

        // Block these apps using WebSocket to communicate with devices
        for (const app of appsToBlock) {
            console.log(`Blocking app: ${app.app_name}`);
            blockAppOnDevice(app, wss); // Use the passed WebSocket server (wss)
        }

        return { success: true, message: 'Apps blocked successfully.' };
    } catch (error) {
        console.error('Error blocking apps:', error);
        return { success: false, message: 'Failed to block apps.' };
    }
}

// Function to send a WebSocket command to block an app on the device
function blockAppOnDevice(app, wss) {
    console.log(`Sending block command for app: ${app.app_name}`);

    // Check if WebSocket Server is available and broadcast the block command
    if (wss && wss.clients) {
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                    action: 'blockApp',
                    packageName: app.package_name // Send the app's package name to the client
                }));
            } else {
                console.error('WebSocket client is not open.');
            }
        });
    } else {
        console.error('WebSocket server is not available or not properly initialized.');
    }
}

module.exports = { blockApps };*/

/*const WebSocket = require('ws');
require('dotenv').config();
const { exec } = require('child_process');

// Connect to the WebSocket server
const ws = new WebSocket(process.env.WEBSOCKET_URL);

ws.on('open', function open() {
    console.log('Connected to the server for app management.');
});

ws.on('message', function incoming(data) {
    const message = JSON.parse(data);

    if (message.action === 'blockApp') {
        const packageName = message.packageName;
        console.log(`Received command to block app: ${packageName}`);

        // Block or hide the app on the device
        blockAppOnDevice(packageName);
    }
});

function blockAppOnDevice(packageName) {
    console.log(`Blocking or hiding app: ${packageName}`);
    exec(`pm disable ${packageName}`, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error disabling app ${packageName}:`, error);
        } else {
            console.log(`App ${packageName} disabled successfully.`);
        }
    });
}

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed.');
});
*/