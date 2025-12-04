const AWS = require('aws-sdk');
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// Redirect root to chat.html
app.get('/', (req, res) => {
    res.redirect('/chat.html');
});

// AWS Configuration - Load credentials from AWS config/environment
// This will automatically use credentials from:
// 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
// 2. AWS credentials file (~/.aws/credentials)
// 3. AWS config file (~/.aws/config)
// 4. IAM role (if running on EC2)

// Use default credential provider chain instead of forcing SharedIniFileCredentials
// This allows AWS SDK to automatically find credentials
const awsConfig = {
    region: process.env.AWS_REGION || 'eu-west-2'
};

// Only set profile if explicitly specified
if (process.env.AWS_PROFILE) {
    awsConfig.credentials = new AWS.SharedIniFileCredentials({ profile: process.env.AWS_PROFILE });
}

AWS.config.update(awsConfig);

const connectParticipant = new AWS.ConnectParticipant();
const connect = new AWS.Connect();

// Verify credentials on startup
AWS.config.getCredentials((err) => {
    if (err) {
        console.error('❌ Failed to load AWS credentials:', err.message);
        console.error('Please ensure AWS credentials are configured:');
        console.error('  - Run "aws configure" to set up credentials');
        console.error('  - Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables');
        console.error('  - Or set AWS_PROFILE environment variable to use a specific profile');
    } else {
        console.log('✅ AWS credentials loaded successfully');
        console.log(`   Region: ${AWS.config.region}`);
        console.log(`   Access Key ID: ${AWS.config.credentials.accessKeyId.substring(0, 5)}***`);
    }
});

// Store active chat sessions
const activeSessions = new Map();

/**
 * Start a new chat contact
 * POST /api/start-chat
 */
app.post('/api/start-chat', async (req, res) => {
    try {
        const { instanceId, contactFlowId, customerName, attributes } = req.body;

        if (!instanceId || !contactFlowId) {
            return res.status(400).json({ 
                error: 'Missing required fields: instanceId and contactFlowId' 
            });
        }

        // Start chat contact
        const params = {
            InstanceId: instanceId,
            ContactFlowId: contactFlowId,
            ParticipantDetails: {
                DisplayName: customerName || 'Anonymous Customer'
            },
            Attributes: {
                customerName: customerName || 'Anonymous',
                ...attributes
            }
        };

        console.log('Starting chat with params:', JSON.stringify(params, null, 2));

        const response = await connect.startChatContact(params).promise();
        
        console.log('Chat started successfully:', {
            ContactId: response.ContactId,
            ParticipantId: response.ParticipantId
        });

        // Store session info
        activeSessions.set(response.ContactId, {
            participantToken: response.ParticipantToken,
            participantId: response.ParticipantId,
            startTime: new Date()
        });

        res.json({
            contactId: response.ContactId,
            participantId: response.ParticipantId,
            participantToken: response.ParticipantToken
        });

    } catch (error) {
        console.error('❌ Error starting chat:', {
            message: error.message,
            code: error.code,
            statusCode: error.statusCode,
            requestId: error.requestId
        });
        res.status(500).json({ 
            error: error.message,
            code: error.code,
            details: 'Check server logs for more information'
        });
    }
});

/**
 * Create participant connection
 * POST /api/create-connection
 */
app.post('/api/create-connection', async (req, res) => {
    try {
        const { participantToken } = req.body;

        if (!participantToken) {
            return res.status(400).json({ error: 'Missing participantToken' });
        }

        const params = {
            ParticipantToken: participantToken,
            Type: ['WEBSOCKET', 'CONNECTION_CREDENTIALS']
        };

        const response = await connectParticipant.createParticipantConnection(params).promise();
        
        res.json({
            websocket: response.Websocket,
            connectionCredentials: response.ConnectionCredentials
        });

    } catch (error) {
        console.error('Error creating connection:', error);
        res.status(500).json({ 
            error: error.message,
            code: error.code 
        });
    }
});

/**
 * Send message
 * POST /api/send-message
 */
app.post('/api/send-message', async (req, res) => {
    try {
        const { connectionToken, message, contentType } = req.body;
        console.log('📤 Sending message:', message);

        if (!connectionToken || !message) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        const params = {
            ConnectionToken: connectionToken,
            Content: message,
            ContentType: contentType || 'text/plain'
        };

        const response = await connectParticipant.sendMessage(params).promise();
        
        res.json({
            id: response.Id,
            absoluteTime: response.AbsoluteTime
        });

    } catch (error) {
        console.error('Error sending message:', error);
        res.status(500).json({ 
            error: error.message,
            code: error.code 
        });
    }
});



/**
 * Disconnect participant
 * POST /api/disconnect
 */
app.post('/api/disconnect', async (req, res) => {
    try {
        const { connectionToken } = req.body;

        if (!connectionToken) {
            return res.status(400).json({ error: 'Missing connectionToken' });
        }

        const params = {
            ConnectionToken: connectionToken
        };

        await connectParticipant.disconnectParticipant(params).promise();
        
        res.json({ success: true });

    } catch (error) {
        console.error('Error disconnecting:', error);
        res.status(500).json({ 
            error: error.message,
            code: error.code 
        });
    }
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date(),
        activeSessions: activeSessions.size
    });
});

/**
 * Serve the HTML chat interface
 */
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Start server
app.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════════════════════════╗
║   Amazon Connect Chat Test Server                         ║
╠════════════════════════════════════════════════════════════╣
║   Server running at: http://localhost:${PORT}                ║
║   Health check:      http://localhost:${PORT}/health         ║
║   AWS Region:        ${process.env.AWS_REGION || 'eu-west-2'}                     ║
╚════════════════════════════════════════════════════════════╝

📝 Make sure your AWS credentials are configured:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_SESSION_TOKEN (if using temporary credentials)

🔗 Open http://localhost:${PORT}/chat.html in your browser to test chat

💡 Test the server health: curl http://localhost:${PORT}/health
    `);
    
    // Log all registered routes
    console.log('\n📋 Available endpoints:');
    console.log('   GET  /health - Health check');
    console.log('   POST /api/start-chat - Start chat contact');
    console.log('   POST /api/create-connection - Create participant connection');
    console.log('   POST /api/send-message - Send chat message');
    console.log('   POST /api/get-transcript - Get chat transcript');
    console.log('   POST /api/disconnect - Disconnect chat');
});

// Cleanup old sessions every hour
setInterval(() => {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    for (const [contactId, session] of activeSessions.entries()) {
        if (session.startTime < oneHourAgo) {
            activeSessions.delete(contactId);
            console.log(`Cleaned up old session: ${contactId}`);
        }
    }
}, 60 * 60 * 1000);
