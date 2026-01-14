# AWS Connect Flow Editor - How to Create Conversation Loops

## 🎯 Understanding the Get Customer Input Block

When you click on your **GatewayBot** block in the flow editor, you'll see it's a **"Get customer input"** block type that connects to Lex.

## 📍 Finding the Connection Points

### Visual Layout of the Block

```
┌─────────────────────────────────┐
│     Get customer input          │ ← Click here to select the block
│      (GatewayBot)               │
├─────────────────────────────────┤
│  Lex Bot: connect-comprehensive │
│  Alias: prod                    │
└─────────────────────────────────┘
        │   │   │   │
        │   │   │   └─ Timeout
        │   │   └───── Error  
        │   └───────── Intent: TransferToAgent
        └───────────── Default (Success)
```

### Where Are the Connection Points?

The **bottom of the block** has small circular dots/nodes:

1. **Default** (leftmost) - This is the "Success" path
2. **Intent conditions** - Your custom conditions (like "TransferToAgent")
3. **Error** - When bot has errors
4. **Timeout** - When user doesn't speak in time

---

## 🔧 How to Create the Loop Back

### Method 1: In the Flow Editor (Visual)

1. **Open the flow**: Routing → Contact Flows → BedrockPrimaryFlow

2. **Locate your GatewayBot block** - it should look like a rectangular box

3. **Look at the BOTTOM of the block** - you'll see small circles/dots

4. **Find the "Default" output**:
   - It's usually the leftmost circle at the bottom
   - Hover over it - it should say "Default" or show a label
   - Currently, this is connected to "SetQueueForTransfer"

5. **Disconnect the current connection**:
   - Click on the line going from "Default" to "SetQueueForTransfer"
   - Press **Delete** key OR right-click → Remove

6. **Create the loop back**:
   - Click and hold on the **Default** output circle (bottom left)
   - Drag your mouse back to the **TOP** of the same GatewayBot block
   - Release when you see the block highlight
   - You should now see a curved arrow looping back

### Method 2: Using the Block Settings Panel

1. **Click on the GatewayBot block** to select it

2. **Look at the right side panel** - this shows block properties

3. **Scroll down to "Branches" or "Transitions"** section

4. **You'll see a list like**:
   ```
   Default: → SetQueueForTransfer
   TransferToAgent: → SetQueueForTransfer  
   Error: → SetQueueForTransfer
   Timeout: → SetQueueForTransfer
   ```

5. **Click on the dropdown next to "Default"**

6. **Select the block name**: Look for your **GatewayBot** block in the dropdown

7. **Do the same for "Timeout"**: Change it to loop back to **GatewayBot**

8. **Keep "TransferToAgent"**: Leave this pointing to **SetQueueForTransfer**

9. **For "Error"**: 
   - First add an error message block (see below)
   - Then point Error to that message block
   - That message block loops back to GatewayBot

---

## 🎨 Visual Representation

### Before (Current - WRONG):
```
┌─────────────┐
│InitialGreet │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ GatewayBot  │
└──────┬──────┘
       │ Default
       ▼
┌─────────────┐
│SetQueueFor  │
│  Transfer   │
└──────┬──────┘
       │
       ▼
   Disconnect
```

### After (Correct - FIXED):
```
       ┌──────────────────┐
       │                  │ ← Loop back arrow
       │                  │
┌──────┴──────┐           │
│InitialGreet │           │
└──────┬──────┘           │
       │                  │
       ▼                  │
┌─────────────┐           │
│ GatewayBot  │───────────┘
└──────┬──────┘   Default
       │
       │ TransferToAgent
       │
       ▼
┌─────────────┐
│SetQueueFor  │
│  Transfer   │
└──────┬──────┘
       │
       ▼
   Disconnect
```

---

## 🔍 Troubleshooting: Can't Find the Connection Points?

### Issue 1: Block is too small
**Solution**: Zoom in using the zoom controls (bottom right of editor)

### Issue 2: Connections are hidden
**Solution**: Click the block to select it - connections will highlight

### Issue 3: Can't drag connections
**Solution**: 
- Make sure you're clicking on the small circle at the bottom (not the block itself)
- The cursor should change to a crosshair when hovering over connection points

### Issue 4: "Default" output doesn't show
**Solution**: 
- The "Default" output might be labeled as the **branch that's NOT a condition**
- In your case, you have:
  - Condition: "TransferToAgent" ✓
  - Everything else goes to: "Default" ← This is the one to loop back

---

## 📝 Step-by-Step with Screenshots Description

### Step 1: Select the Block
- **What you see**: Block has a blue border when selected
- **Right panel shows**: Block properties and settings

### Step 2: Look at the Bottom Edge
- **What you see**: Small circles (connection nodes) at the bottom
- **Number of circles**: Should have 3-4 circles depending on conditions

### Step 3: Identify Each Circle
Hover over each circle to see the label:
- **Circle 1** (left): "Default" or unlabeled (this is your success path)
- **Circle 2**: "TransferToAgent" (your condition)
- **Circle 3**: "Error"
- **Circle 4** (right): "Timeout"

### Step 4: Working with Default
- **Current**: Line goes DOWN to SetQueueForTransfer
- **Goal**: Line should curve UP and LEFT back to the top of GatewayBot block
- **How**: Click the line, delete it, then drag from circle back to block top

---

## 🎯 Alternative: Use the JSON Editor

If the visual editor is confusing, you can edit the flow JSON:

### Step 1: Export the Flow
1. In flow editor, click **Save** dropdown
2. Select **Export flow (beta)**
3. Download the JSON file

### Step 2: Find GatewayBot in JSON
Look for the action with your bot:
```json
{
  "Identifier": "GatewayBot",
  "Type": "ConnectParticipantWithLexBot",
  "Transitions": {
    "NextAction": "SetQueueForTransfer",  ← Change this
    "Conditions": [
      {
        "NextAction": "SetQueueForTransfer",
        "Condition": {...}
      }
    ],
    "Errors": [
      {
        "NextAction": "SetQueueForTransfer",  ← Change this
        "ErrorType": "NoMatchingError"
      }
    ]
  }
}
```

### Step 3: Change the NextAction
```json
{
  "Identifier": "GatewayBot",
  "Type": "ConnectParticipantWithLexBot",
  "Transitions": {
    "NextAction": "GatewayBot",  ← Loop back to itself
    "Conditions": [
      {
        "NextAction": "SetQueueForTransfer",  ← Keep this
        "Condition": {...}
      }
    ],
    "Errors": [
      {
        "NextAction": "GatewayBot",  ← Loop back on error too
        "ErrorType": "NoMatchingError"
      }
    ]
  }
}
```

### Step 4: Import the Modified Flow
1. In Connect, create a NEW flow or go to existing
2. Click **Save** dropdown
3. Select **Import flow (beta)**
4. Upload your modified JSON
5. Publish

---

## ✅ How to Verify the Loop is Created

After making changes:

1. **Visual check**: You should see a curved arrow from GatewayBot back to itself
2. **Test flow**: Click "Test flow" button in the editor
3. **Simulate conversation**: Type test inputs and verify it doesn't immediately end

---

## 🚨 Common Mistakes

### Mistake 1: Connecting to InitialGreeting instead of GatewayBot
**Wrong**: Default → InitialGreeting (will play welcome message repeatedly)
**Right**: Default → GatewayBot (continues conversation)

### Mistake 2: Looping TransferToAgent
**Wrong**: TransferToAgent → GatewayBot (will never transfer)
**Right**: TransferToAgent → SetQueueForTransfer (allows transfer)

### Mistake 3: Creating infinite loop with no exit
**Problem**: If every path goes back to bot, user can never escape
**Solution**: Keep at least one condition (TransferToAgent) going to transfer/disconnect

---

## 📞 Need More Help?

If you're still stuck, you can:

1. **Export the current flow** and share the JSON
2. **Take a screenshot** of the flow editor showing the GatewayBot block
3. **Describe what you see** when you click on the block

I can then provide more specific guidance based on what you're seeing!

---

## 🎬 Quick Video Description

Imagine watching this:
1. Camera zooms to GatewayBot block
2. Mouse hovers over bottom-left circle (Default)
3. Cursor changes to crosshair
4. Click and hold on the circle
5. Drag mouse upward
6. Mouse moves to the top edge of the same GatewayBot block
7. Block highlights in blue
8. Release mouse button
9. Curved arrow appears, looping back
10. Done! ✅

That's the exact motion you need to create the loop!
