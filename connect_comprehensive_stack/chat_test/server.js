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

// AWS Configuration
const connectParticipant = new AWS.ConnectParticipant({
    region: process.env.AWS_REGION || 'eu-west-2'
});

const connect = new AWS.Connect({
    region: process.env.AWS_REGION || 'eu-west-2'
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
        console.error('Error starting chat:', error);
        res.status(500).json({ 
            error: error.message,
            code: error.code 
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
 * Get transcript
 * POST /api/get-transcript
 */
app.post('/api/get-transcript', async (req, res) => {
    try {
        const { connectionToken, maxResults, nextToken } = req.body;

        if (!connectionToken) {
            return res.status(400).json({ error: 'Missing connectionToken' });
        }

        const params = {
            ConnectionToken: connectionToken,
            MaxResults: maxResults || 15,
            SortOrder: 'ASCENDING'
        };

        if (nextToken) {
            params.NextToken = nextToken;
        }

        const response = await connectParticipant.getTranscript(params).promise();
        
        res.json({
            transcript: response.Transcript,
            nextToken: response.NextToken
        });

    } catch (error) {
        console.error('Error getting transcript:', error);
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

🔗 Open http://localhost:${PORT} in your browser to test chat
    `);
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
