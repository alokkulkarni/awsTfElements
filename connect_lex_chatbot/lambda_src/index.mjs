import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

const bedrock = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  const intentName = event.sessionState.intent.name;
  const inputTranscript = event.inputTranscript;
  const guardrailId = process.env.GUARDRAIL_ID;
  const guardrailVersion = process.env.GUARDRAIL_VERSION;

  // 1. Content Moderation (Input) - Handled by Bedrock Guardrails API if needed, 
  // or we can rely on the LLM call to include guardrail check.
  // For this example, we'll assume the LLM call includes the guardrail check.

  try {
    // 2. Call LLM (Claude 3 Haiku)
    const prompt = `You are a helpful banking assistant. The user said: "${inputTranscript}". Provide a concise and helpful response.`;
    
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
      guardrailIdentifier: guardrailId,
      guardrailVersion: guardrailVersion,
      trace: "ENABLED"
    };

    const command = new InvokeModelCommand(input);
    const response = await bedrock.send(command);
    
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));
    const botResponse = responseBody.content[0].text;

    // 3. Return to Lex
    return {
      sessionState: {
        dialogAction: {
          type: "Close"
        },
        intent: {
          name: intentName,
          state: "Fulfilled"
        }
      },
      messages: [
        {
          contentType: "PlainText",
          content: botResponse
        }
      ]
    };

  } catch (error) {
    console.error("Error invoking Bedrock:", error);
    
    // Handle Guardrail Intervention or other errors
    let errorMessage = "I'm sorry, I encountered an error processing your request.";
    
    if (error.name === 'ValidationException' && error.message.includes('Guardrail')) {
        errorMessage = "I cannot answer that question due to safety guidelines.";
    }

    return {
      sessionState: {
        dialogAction: {
          type: "Close"
        },
        intent: {
          name: intentName,
          state: "Failed"
        }
      },
      messages: [
        {
          contentType: "PlainText",
          content: errorMessage
        }
      ]
    };
  }
};
