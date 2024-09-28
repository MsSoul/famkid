//filename:server/device_listener.js
const WebSocket = require('ws');
require('dotenv').config();
const { exec } = require('child_process');

// Connect to the WebSocket server
const ws = new WebSocket(process.env.WEBSOCKET_URL);

ws.on('open', function open() {
    console.log('Connected to the WebSocket server.');
});

ws.on('message', function incoming(data) {
    const message = JSON.parse(data);

    if (message.action === 'blockApp') {
        const packageName = message.packageName;
        console.log(`Received command to block app: ${packageName}`);

        // Block the app on the device using adb command (for Android)
        blockAppOnDevice(packageName);
    }
});

// Function to block an app on the device
function blockAppOnDevice(packageName) {
    console.log(`Blocking app: ${packageName}`);
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
