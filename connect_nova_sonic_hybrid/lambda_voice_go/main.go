package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
)

type VoiceEvent struct {
	AudioChunk string `json:"audioChunk"`
}

type Response struct {
	StatusCode     int    `json:"statusCode"`
	Body           string `json:"body,omitempty"`
	Action         string `json:"action,omitempty"`
	TargetQueue    string `json:"targetQueue,omitempty"`
	TargetQueueArn string `json:"targetQueueArn,omitempty"`
	Message        string `json:"message,omitempty"`
}

var (
	bedrockClient *bedrockruntime.Client
	guardrailID   string
	guardrailVer  string
	queueMap      map[string]string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	bedrockClient = bedrockruntime.NewFromConfig(cfg)
	guardrailID = os.Getenv("GUARDRAIL_ID")
	guardrailVer = os.Getenv("GUARDRAIL_VERSION")

	queueMapStr := os.Getenv("QUEUE_MAP")
	if queueMapStr == "" {
		queueMapStr = "{}"
	}
	json.Unmarshal([]byte(queueMapStr), &queueMap)
}

func HandleRequest(ctx context.Context, event VoiceEvent) (Response, error) {
	log.Printf("Received Voice Stream Event")

	locale := os.Getenv("LOCALE")
	if locale == "" {
		locale = "en_US"
	}

	departments := make([]string, 0, len(queueMap))
	for k := range queueMap {
		departments = append(departments, k)
	}

	systemPrompt := fmt.Sprintf(`You are a helpful voice assistant. 
	If the user asks to speak to a human agent or a specific department, output the tag [HANDOVER: DepartmentName].
	Available departments: %s.
	If the department is not found, output [HANDOVER: Default].`, strings.Join(departments, ", "))

	payload := map[string]interface{}{
		"audio":        event.AudioChunk,
		"stream":       true,
		"locale":       locale,
		"systemPrompt": systemPrompt,
	}

	payloadBytes, _ := json.Marshal(payload)

	input := &bedrockruntime.InvokeModelWithResponseStreamInput{
		ModelId:     aws.String("amazon.nova-sonic-v1:0"), // Hypothetical Model ID
		ContentType: aws.String("application/json"),
		Accept:      aws.String("application/json"),
		Body:        payloadBytes,
		Trace:       types.TraceEnabled,
	}

	if guardrailID != "" && guardrailVer != "" {
		input.GuardrailIdentifier = aws.String(guardrailID)
		input.GuardrailVersion = aws.String(guardrailVer)
	}

	output, err := bedrockClient.InvokeModelWithResponseStream(ctx, input)
	if err != nil {
		log.Printf("Error invoking Bedrock: %v", err)
		return Response{StatusCode: 500, Body: "Error processing audio"}, err
	}

	stream := output.GetStream()
	for event := range stream.Events() {
		if v, ok := event.(*types.ResponseStreamMemberChunk); ok {
			decoded := string(v.Value.Bytes)
			log.Printf("Received Stream Chunk: %s", decoded)

			if containsGuardrailIntervention(decoded) {
				log.Println("Content blocked by Guardrail")
				return Response{StatusCode: 400, Body: "Content blocked"}, nil
			}

			// Check for Handover Signal
			if strings.Contains(decoded, "[HANDOVER:") {
				start := strings.Index(decoded, "[HANDOVER: ") + len("[HANDOVER: ")
				end := strings.Index(decoded[start:], "]")
				if end != -1 {
					department := decoded[start : start+end]
					targetArn, ok := queueMap[department]
					if !ok {
						// Fallback to Default or first available
						if def, ok := queueMap["Default"]; ok {
							targetArn = def
						} else {
							for _, v := range queueMap {
								targetArn = v
								break
							}
						}
					}

					log.Printf("Handover requested to %s (%s)", department, targetArn)
					return Response{
						StatusCode:     200,
						Action:         "transfer",
						TargetQueue:    department,
						TargetQueueArn: targetArn,
						Message:        fmt.Sprintf("Transferring you to %s...", department),
					}, nil
				}
			}
		}
	}

	return Response{StatusCode: 200, Body: "Stream processed successfully"}, nil
}

func containsGuardrailIntervention(text string) bool {
	// Simplified check
	return len(text) > 0 && (text == "guardrail_intervention" ||
		// Add other checks as needed based on actual Nova Sonic response format
		false)
}

func main() {
	lambda.Start(HandleRequest)
}
