import { BedrockRuntimeClient, InvokeModelWithResponseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

// Note: In a real production scenario, this Lambda would likely be a WebSocket handler 
// or a containerized service to maintain the persistent bidirectional stream.
// This code demonstrates the API usage and Guardrail integration.

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  console.log("Received Voice Stream Event:", JSON.stringify(event, null, 2));

  // Simulated Audio Input (Base64) from Connect
  const audioChunk = event.audioChunk; 

  try {
    const input = {
      modelId: "amazon.nova-sonic-v1:0", // Hypothetical Model ID for Nova Sonic
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        audio: audioChunk,
        stream: true // Enable bidirectional streaming
      }),
      guardrailIdentifier: process.env.GUARDRAIL_ID,
      guardrailVersion: process.env.GUARDRAIL_VERSION,
      trace: "ENABLED"
    };

    // In a real implementation, this would be a persistent stream
    // For this Lambda, we simulate a single turn of the stream
    const command = new InvokeModelWithResponseStreamCommand(input);
    const response = await client.send(command);

    for await (const chunk of response.body) {
      if (chunk.chunk) {
        const decoded = new TextDecoder().decode(chunk.chunk.bytes);
        console.log("Received Stream Chunk:", decoded);
        
        // Check for Guardrail Intervention in the stream
        // Nova Sonic would emit specific events if content is blocked
        if (decoded.includes("guardrail_intervention")) {
            console.warn("Content blocked by Guardrail");
            return {
                statusCode: 400,
                body: "Content blocked"
            };
        }
      }
    }

    return {
      statusCode: 200,
      body: "Stream processed successfully"
    };

  } catch (error) {
    console.error("Error in Voice Stream:", error);
    return {
      statusCode: 500,
      body: "Internal Error"
    };
  }
};
