# Contact Flow Fix Instructions

## 🚨 Problem Identified

Your BedrockPrimaryFlow is immediately disconnecting calls because:

1. **5-second timeout** - Not enough time to speak
2. **All paths lead to disconnect** - No conversation loop

## 📋 Step-by-Step Fix in AWS Connect Console

### Step 1: Open the Flow
1. Log into: https://my-connect-instance-demo-123.my.connect.aws
2. Go to **Routing** → **Contact Flows**
3. Open **BedrockPrimaryFlow** (ID: d4c0bfe5-5c97-40ac-8df4-7e482612be27)

---

### Step 2: Fix the GatewayBot Block

Click on the **GatewayBot** block (the one that says "Get customer input with Lex bot"):

#### A. Increase Timeout
In the **Session attributes** section:
- Find: `x-amz-lex:audio:start-timeout-ms`
- Change from: `5000`
- Change to: `15000` (15 seconds - gives user time to think and speak)

#### B. Fix the Transitions
The block currently has these outputs:
- **Success** (default)
- **TransferToAgent** (condition)
- **Error**
- **Timeout**

**Configure them as follows:**

1. **Success (Default)** → Connect back to **GatewayBot** itself (creates conversation loop)
2. **TransferToAgent** → Connect to **SetQueueForTransfer** ✅ (already correct)
3. **Error** → Connect to an "Error Message" block (create new one)
4. **Timeout** → Connect back to **GatewayBot** (give user another chance)

---

### Step 3: Create Error Handling

Add a new **Play prompt** block:
- **Name**: "ErrorMessage"
- **Text**: "I'm sorry, I didn't quite catch that. Let me try again."
- **Next Action**: Connect back to **GatewayBot**

---

### Step 4: Fix Other Bot Blocks

Do the same for **BankingBot** and **SalesBot** blocks:
- Increase timeout to `15000`
- Success → Loop back to themselves
- TransferToAgent → SetQueueForTransfer
- Error/Timeout → ErrorMessage → Loop back

---

### Step 5: Verify the Flow

The final flow should look like:

```
┌─────────────────┐
│ InitialGreeting │
│   (Welcome msg) │
└────────┬────────┘
         │
         ▼
    ┌─────────────┐
    │ GatewayBot  │◄──┐
    │  (Lex Bot)  │   │
    └─────┬───────┘   │
          │           │
    ┌─────┴───────────┴────────┐
    │                           │
    │ Success/Timeout           │ TransferToAgent
    │ (loop back)               │
    │                           ▼
    │                    ┌──────────────────┐
    │                    │ SetQueueForTransfer│
    │                    └─────────┬─────────┘
    │                              │
    │                              ▼
    │                         ┌─────────┐
    │                         │Disconnect│
    │                         └─────────┘
    │
    │ Error
    ▼
┌──────────────┐
│ ErrorMessage │
└──────┬───────┘
       │
       │ (loop back to GatewayBot)
       │
       └──────────────┘
```

---

### Step 6: Save and Publish

1. Click **Save**
2. Click **Publish**
3. Confirm the publish

---

## 🧪 Test After Fix

Call: **+44 20 4632 2399**

**Expected behavior:**
1. ✅ Welcome message plays
2. ✅ Bot says "Hi, How may i help u?"
3. ✅ You have **15 seconds** to respond
4. ✅ You say: "I want to check my balance"
5. ✅ Bot processes and responds
6. ✅ **Conversation continues** (doesn't disconnect)
7. ✅ You can ask more questions
8. ✅ Say "speak to an agent" to trigger transfer
9. ✅ Only then should it disconnect (after queue transfer)

---

## 🔍 Quick Visual Check

In the visual flow editor, you should see:
- **Curved arrows** looping from bot blocks back to themselves (this is the conversation loop)
- **Straight arrow** from TransferToAgent to SetQueueForTransfer
- **NO direct path** from bot blocks to Disconnect

---

## ⚙️ Optional: Advanced Configuration

If you want even better user experience:

### Add Max Loops
To prevent infinite loops, add a **Set contact attributes** block before GatewayBot:
- Set attribute: `LoopCount`
- Increment on each loop
- Add a **Check contact attributes** block:
  - If `LoopCount > 5` → Play "Let me transfer you to an agent" → SetQueueForTransfer

### Add No Input Handling
- If user is silent for too long, play a prompt:
  - "Are you still there? Please say something or I'll transfer you to an agent."

---

## 📊 Monitoring After Fix

After making these changes, you can monitor:

```bash
# Watch Lex conversation logs
aws logs tail /aws/lex/connect-comprehensive-bot --region eu-west-2 --follow

# Watch Lambda logs
aws logs tail /aws/lambda/connect-comprehensive-bedrock-mcp --region eu-west-2 --follow
```

You should now see:
- Multiple conversation turns in the logs
- Lambda being invoked repeatedly (once per user input)
- Session continuing until user says "transfer to agent" or hangs up

---

## 🎯 Summary

**Root Cause**: Contact flow was terminating after first bot interaction
**Solution**: Create conversation loop by connecting bot success back to itself
**Timeout Fix**: Increased from 5s to 15s to give user time to speak

After this fix, your bot will behave like a proper conversational AI!
