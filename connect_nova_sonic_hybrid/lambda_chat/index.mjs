import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  const intentName = event.sessionState.intent.name;
  const userMessage = event.inputTranscript;

  if (intentName === "FallbackIntent") {
    return close(event, "I'm sorry, I didn't understand that. Could you please repeat?");
  }

  try {
    // Invoke Bedrock with Guardrail
    const prompt = `You are a helpful customer service assistant. Answer the following user query: ${userMessage}`;
    
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
    const completion = responseBody.content[0].text;

    return close(event, completion);

  } catch (error) {
    console.error("Error invoking Bedrock:", error);
    
    // Check if it was a Guardrail intervention
    if (error.name === "ValidationException" && error.message.includes("guardrail")) {
       return close(event, "I cannot answer that question due to our safety policies.");
    }

    return close(event, "I'm having trouble connecting to my brain right now. Please try again later.");
  }
};

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
