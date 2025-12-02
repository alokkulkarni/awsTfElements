import { BedrockRuntimeClient, InvokeModelWithResponseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

// Note: In a real production scenario, this Lambda would likely be a WebSocket handler 
// or a containerized service to maintain the persistent bidirectional stream.
// This code demonstrates the API usage and Guardrail integration.

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  console.log("Received Voice Stream Event:", JSON.stringify(event, null, 2));
  
  // Available Queues for Routing Logic
  const queueMap = JSON.parse(process.env.QUEUE_MAP || '{}');
  const departments = Object.keys(queueMap).join(", ");
  console.log("Available Queues:", departments);

  // Simulated Audio Input (Base64) from Connect
  const audioChunk = event.audioChunk; 
  const locale = process.env.LOCALE || 'en_US';

  try {
    const input = {
      modelId: "amazon.nova-sonic-v1:0", // Hypothetical Model ID for Nova Sonic
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        audio: audioChunk,
        stream: true, // Enable bidirectional streaming
        locale: locale,
        systemPrompt: `You are a helpful voice assistant. 
        If the user asks to speak to a human agent or a specific department, output the tag [HANDOVER: DepartmentName].
        Available departments: ${departments}.
        If the department is not found, output [HANDOVER: Default].`
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
        if (decoded.includes("guardrail_intervention")) {
            console.warn("Content blocked by Guardrail");
            return {
                statusCode: 400,
                body: "Content blocked"
            };
        }

        // Check for Handover Signal
        const handoverMatch = decoded.match(/\[HANDOVER: (.*?)\]/);
        if (handoverMatch) {
            const department = handoverMatch[1];
            const targetArn = queueMap[department] || queueMap['Default'] || Object.values(queueMap)[0];
            console.log(`Handover requested to ${department} (${targetArn})`);
            
            return {
                statusCode: 200,
                action: "transfer",
                targetQueue: department,
                targetQueueArn: targetArn,
                message: `Transferring you to ${department}...`
            };
        }
      }
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
