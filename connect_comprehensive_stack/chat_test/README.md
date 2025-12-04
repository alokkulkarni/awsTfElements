# Amazon Connect Chat Test Interface

A simple web-based chat interface to test Amazon Connect chat functionality with Lex bot integration.

## 🚀 Quick Start

### Prerequisites

- Node.js (v14 or higher)
- AWS credentials configured via:
  - AWS CLI (`aws configure`)
  - AWS credentials file (`~/.aws/credentials`)
  - Environment variables
- AWS IAM permissions for:
  - `connect:StartChatContact`
  - `connect:*` (for participant operations)
- Amazon Connect instance with a contact flow configured

### Installation

```bash
cd chat_test
npm install
```

### Configuration

The server automatically uses AWS credentials from:

1. **Environment variables** (highest priority):
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
   export AWS_REGION="eu-west-2"
   ```

2. **AWS credentials file** (`~/.aws/credentials`):
   ```ini
   [default]
   aws_access_key_id = your-access-key
   aws_secret_access_key = your-secret-key
   ```

3. **AWS config file** (`~/.aws/config`):
   ```ini
   [default]
   region = eu-west-2
   ```

4. **AWS Profile** (optional):
   ```bash
   export AWS_PROFILE="your-profile-name"
   ```

The server will use the `default` profile unless `AWS_PROFILE` is set.

### Running the Server

```bash
npm start
```

The server will start on `http://localhost:3000`

For development with auto-reload:
```bash
npm run dev
```

## 📖 Usage

### Method 1: Backend-Powered Chat (Recommended)

1. Start the backend server: `npm start`
2. Open `http://localhost:3000/chat.html` in your browser
3. Enter your Connect instance ID and contact flow ID
4. Click "Start Chat"
5. Type messages to interact with your bot

### Method 2: Direct API (Requires AWS Credentials in Browser)

1. Open `index.html` directly in your browser
2. Enter your Connect instance ID and contact flow ID
3. Note: This method has CORS limitations and is for reference only

## 🏗️ Architecture

```
┌─────────────┐      ┌──────────────┐      ┌──────────────────┐
│   Browser   │─────▶│  Node.js API │─────▶│ Amazon Connect   │
│  (Chat UI)  │◀─────│   (Proxy)    │◀─────│  + Lex Bot      │
└─────────────┘      └──────────────┘      └──────────────────┘
```

### API Endpoints

- `POST /api/start-chat` - Start a new chat contact
- `POST /api/create-connection` - Create participant connection
- `POST /api/send-message` - Send a message
- `POST /api/get-transcript` - Get chat transcript
- `POST /api/disconnect` - End the chat session
- `GET /health` - Health check endpoint

## 🔧 Configuration

### Required Information

- **Instance ID**: Your Amazon Connect instance ID (e.g., `6e728dc7-049b-46e6-addb-be0784cbb3ef`)
- **Contact Flow ID**: The ID of your contact flow (e.g., `efa7998c-4862-4f2e-9a7b-dde80a266dc7`)
- **AWS Region**: The region where your Connect instance is deployed (default: `eu-west-2`)

### Finding Your IDs

#### Instance ID
```bash
aws connect list-instances --region eu-west-2
```

#### Contact Flow ID
```bash
aws connect list-contact-flows --instance-id YOUR_INSTANCE_ID --region eu-west-2
```

Or check your Terraform outputs:
```bash
cd ../
terraform output connect_instance_id
```

## 🧪 Testing Features

### Chat Capabilities

1. **Start Chat Session**
   - Initializes connection to Amazon Connect
   - Creates participant token
   - Establishes WebSocket or polling connection

2. **Send Messages**
   - Type messages and press Enter or click Send
   - Messages are sent to Lex bot for processing
   - Responses appear in real-time

3. **Receive Responses**
   - Bot responses appear automatically
   - System messages show connection status
   - Timestamp displayed for each message

4. **End Chat**
   - Gracefully disconnects from the session
   - Cleans up resources
   - Displays end-of-chat message

### Testing Scenarios

1. **Basic Intent Testing**
   ```
   User: "check my balance"
   Bot: [Response from Lex bot]
   ```

2. **Error Handling (3 Retries)**
   ```
   User: "ajshdkajshd"
   Bot: "I did not understand. Please try again."
   [After 3 attempts]
   Bot: "I'm sorry, I'm still having trouble..."
   ```

3. **Multiple Intents**
   - Check balance
   - Loan inquiry
   - Onboarding status
   - Transfer to agent

## 🔐 Security Notes

### Production Deployment

For production use:

1. **Never expose AWS credentials in the browser**
2. **Use backend API proxy** (provided in `server.js`)
3. **Implement authentication** for your API endpoints
4. **Use IAM roles** instead of access keys when possible
5. **Enable HTTPS** for all connections
6. **Implement rate limiting** on API endpoints

### Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "connect:StartChatContact"
      ],
      "Resource": "arn:aws:connect:REGION:ACCOUNT_ID:instance/INSTANCE_ID"
    },
    {
      "Effect": "Allow",
      "Action": [
        "connect:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🐛 Troubleshooting

### Issue: "Failed to start chat"

**Solution:**
- Check AWS credentials are configured
- Verify instance ID and contact flow ID are correct
- Ensure IAM permissions are granted
- Check CloudWatch logs for Connect errors

### Issue: "Messages not appearing"

**Solution:**
- Check browser console for errors
- Verify WebSocket connection is established
- Check network tab for failed API calls
- Ensure contact flow is published and active

### Issue: "Connection timeout"

**Solution:**
- Verify Connect instance is in the correct region
- Check security groups and network connectivity
- Ensure contact flow is not in draft state
- Review Connect service quotas

## 📊 Monitoring

### Server Logs

The backend server logs important events:
- Chat session start/end
- Message send/receive
- Errors and exceptions
- Active session count

### CloudWatch Logs

Enable logging in your contact flow to see:
- Contact flow execution
- Lex bot interactions
- Lambda invocations
- Error details

## 🔄 Development

### File Structure

```
chat_test/
├── package.json          # Node.js dependencies
├── server.js             # Backend API server
├── chat.html             # Chat interface (with backend)
├── index.html            # Standalone chat (reference)
└── README.md             # This file
```

### Adding Features

1. **Custom Attributes**: Modify `startChat()` in `server.js` to include additional attributes
2. **Message Formatting**: Update CSS in `chat.html` for custom styling
3. **Additional Events**: Extend WebSocket handlers for more event types
4. **Analytics**: Add tracking to `sendMessage()` and message handlers

## 📝 License

MIT

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues related to:
- **Amazon Connect**: Check AWS Support or AWS Forums
- **This Test Interface**: Create an issue in the repository
- **Lex Bot Configuration**: Refer to AWS Lex documentation
