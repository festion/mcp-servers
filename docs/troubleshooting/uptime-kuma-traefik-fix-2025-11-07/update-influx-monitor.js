#!/usr/bin/env node

/**
 * Update InfluxDB Monitor to use /ping endpoint
 * 
 * This script updates the existing InfluxDB monitor in Uptime Kuma
 * to use the /ping endpoint which returns HTTP 204
 */

const io = require('socket.io-client');

const UPTIME_KUMA_URL = 'http://localhost:3001';
const USERNAME = process.argv[2];
const PASSWORD = process.argv[3];

if (!USERNAME || !PASSWORD) {
    console.error('Usage: node update-influx-monitor.js <username> <password>');
    console.error('');
    console.error('This script will update the InfluxDB monitor to use the /ping endpoint');
    console.error('which accepts HTTP 204 (No Content) as a valid response.');
    process.exit(1);
}

console.log('Connecting to Uptime Kuma...');
const socket = io(UPTIME_KUMA_URL, {
    reconnection: true,
    reconnectionDelay: 1000,
    reconnectionAttempts: 3
});

socket.on('connect', () => {
    console.log('Connected to Uptime Kuma');
    
    // Login
    console.log('Attempting login...');
    socket.emit('login', {
        username: USERNAME,
        password: PASSWORD,
        token: null
    }, (response) => {
        if (response.ok) {
            console.log('✓ Login successful');
            
            // Get list of monitors
            console.log('Fetching monitors...');
            socket.emit('getMonitorList', (monitorList) => {
                console.log(`Found ${Object.keys(monitorList).length} monitors`);
                
                // Find InfluxDB monitor
                let influxMonitor = null;
                for (const [id, monitor] of Object.entries(monitorList)) {
                    if (monitor.name && monitor.name.toLowerCase().includes('influx')) {
                        influxMonitor = monitor;
                        influxMonitor.id = parseInt(id);
                        break;
                    }
                }
                
                if (!influxMonitor) {
                    console.error('✗ InfluxDB monitor not found');
                    socket.disconnect();
                    process.exit(1);
                }
                
                console.log(`✓ Found InfluxDB monitor: "${influxMonitor.name}" (ID: ${influxMonitor.id})`);
                console.log(`  Current URL: ${influxMonitor.url}`);
                
                // Update monitor configuration
                const updatedMonitor = {
                    ...influxMonitor,
                    url: 'http://192.168.1.56:8086/ping',
                    accepted_statuscodes: ['200-299', '204'],
                    description: 'InfluxDB health check using /ping endpoint (returns HTTP 204)'
                };
                
                console.log('Updating monitor configuration...');
                console.log(`  New URL: ${updatedMonitor.url}`);
                console.log(`  Accepted status codes: ${updatedMonitor.accepted_statuscodes.join(', ')}`);
                
                socket.emit('add', updatedMonitor, (response) => {
                    if (response.ok) {
                        console.log('✓ Monitor updated successfully!');
                        console.log('');
                        console.log('Monitor Details:');
                        console.log(`  Name: ${response.monitor.name}`);
                        console.log(`  Type: ${response.monitor.type}`);
                        console.log(`  URL: ${response.monitor.url}`);
                        console.log(`  Interval: ${response.monitor.interval}s`);
                        console.log(`  Accepted Status: ${response.monitor.accepted_statuscodes}`);
                    } else {
                        console.error('✗ Failed to update monitor:', response.msg);
                    }
                    
                    socket.disconnect();
                    process.exit(response.ok ? 0 : 1);
                });
            });
        } else {
            console.error('✗ Login failed:', response.msg);
            socket.disconnect();
            process.exit(1);
        }
    });
});

socket.on('connect_error', (error) => {
    console.error('✗ Connection error:', error.message);
    process.exit(1);
});

socket.on('disconnect', () => {
    console.log('Disconnected from Uptime Kuma');
});

// Timeout after 30 seconds
setTimeout(() => {
    console.error('✗ Operation timed out');
    socket.disconnect();
    process.exit(1);
}, 30000);
