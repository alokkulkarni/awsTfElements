import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";
import { LexModelsV2Client, DescribeIntentCommand, UpdateIntentCommand, BuildBotLocaleCommand } from "@aws-sdk/client-lex-models-v2";

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });
const lexClient = new LexModelsV2Client({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  const intentName = event.sessionState.intent.name;
  const userMessage = event.inputTranscript;
  const queueMap = JSON.parse(process.env.QUEUE_MAP || '{}');

  if (intentName === "TalkToAgent") {
    const departmentSlot = event.sessionState.intent.slots.Department;
    const department = departmentSlot ? departmentSlot.value.originalValue : null;

    if (department && queueMap[department]) {
        // Valid department, set session attribute for Connect
        return {
            sessionState: {
                dialogAction: { type: "Close" },
                intent: { name: intentName, state: "Fulfilled" },
                sessionAttributes: {
                    "TargetQueue": department,
                    "TargetQueueArn": queueMap[department]
                }
            },
            messages: [{ contentType: "PlainText", content: `Transferring you to ${department}...` }]
        };
    } else {
        return close(event, `Sorry, I couldn't find a queue for ${department}. Available departments are: ${Object.keys(queueMap).join(", ")}.`);
    }
  }

  // Fallback Intent: Use Bedrock for Classification or QA
  if (intentName === "FallbackIntent") {
    try {
      const departments = Object.keys(queueMap).join(", ");
      const prompt = `You are an intelligent intent classifier for a customer service bot. 
      The available departments are: ${departments}.
      
      User message: "${userMessage}"
      
      Instructions:
      1. If the user wants to speak to a specific department, reply with ONLY the department name (e.g., "Sales").
      2. If the user is asking a general question, reply with the answer to the question.
      `;
      
      const input = {
        modelId: "anthropic.claude-3-haiku-20240307-v1:0",
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify({
          anthropic_version: "bedrock-2023-05-31",
          max_tokens: 1000,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: prompt
                }
              ]
            }
          ]
        }),
        guardrailIdentifier: process.env.GUARDRAIL_ID,
        guardrailVersion: process.env.GUARDRAIL_VERSION,
        trace: "ENABLED" 
      };
  
      const command = new InvokeModelCommand(input);
      const response = await client.send(command);
      
      const responseBody = JSON.parse(new TextDecoder().decode(response.body));
      const completion = responseBody.content[0].text.trim();

      // Check if completion matches a department (Self-Learning)
      if (queueMap[completion]) {
        console.log(`Bedrock classified intent as: ${completion}. Initiating self-learning...`);
        
        // 1. Fulfill the request
        const fulfillmentResponse = {
            sessionState: {
                dialogAction: { type: "Close" },
                intent: { name: "TalkToAgent", state: "Fulfilled" },
                sessionAttributes: {
                    "TargetQueue": completion,
                    "TargetQueueArn": queueMap[completion]
                }
            },
            messages: [{ contentType: "PlainText", content: `I understand you want to speak to ${completion}. Transferring you now...` }]
        };

        // 2. Update Lex (Async - Fire and Forget)
        await updateLexIntent(userMessage, completion);
        
        return fulfillmentResponse;

      } else {
        // It's a general answer
        return close(event, completion);
      }

    } catch (error) {
      console.error("Error in Fallback/Bedrock:", error);
      return close(event, "I'm having trouble understanding right now. Please try again.");
    }
  }

  return close(event, "I didn't understand that.");
};

async function updateLexIntent(utterance, department) {
  try {
    const botId = process.env.BOT_ID;
    const botVersion = process.env.BOT_VERSION;
    const localeId = process.env.LOCALE_ID;
    const intentId = process.env.INTENT_ID;

    // 1. Get current intent definition
    const describeCommand = new DescribeIntentCommand({
      botId, botVersion, localeId, intentId
    });
    const intentDef = await lexClient.send(describeCommand);

    // 2. Add new utterance
    // Note: In a real scenario, we should check for duplicates
    const newUtterance = { utterance: utterance };
    if (!intentDef.sampleUtterances) intentDef.sampleUtterances = [];
    intentDef.sampleUtterances.push(newUtterance);

    // 3. Update Intent
    const updateCommand = new UpdateIntentCommand({
      botId, botVersion, localeId, intentId,
      intentName: intentDef.intentName,
      sampleUtterances: intentDef.sampleUtterances,
      dialogCodeHook: intentDef.dialogCodeHook,
      fulfillmentCodeHook: intentDef.fulfillmentCodeHook,
      slotPriorities: intentDef.slotPriorities,
      intentClosingSetting: intentDef.intentClosingSetting,
      // We need to map other fields carefully or use the object spread if compatible
      // For simplicity, we are just passing back what we got + new utterance
    });
    
    await lexClient.send(updateCommand);
    console.log(`Successfully added utterance "${utterance}" to intent ${intentId}`);

    // 4. Trigger Build (Optional - can be expensive)
    // await lexClient.send(new BuildBotLocaleCommand({ botId, botVersion, localeId }));

  } catch (err) {
    console.error("Failed to update Lex intent:", err);
    // Don't fail the user request just because self-learning failed
  }
}

function close(event, message) {
  return {
    sessionState: {
      dialogAction: {
        type: "Close",
      },
      intent: {
        name: event.sessionState.intent.name,
        state: "Fulfilled",
      },
    },
    messages: [
      {
        contentType: "PlainText",
        content: message,
      },
    ],
  };
}
