package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

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
	StatusCode int    `json:"statusCode"`
	Body       string `json:"body"`
}

var (
	bedrockClient *bedrockruntime.Client
	guardrailID   string
	guardrailVer  string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	bedrockClient = bedrockruntime.NewFromConfig(cfg)
	guardrailID = os.Getenv("GUARDRAIL_ID")
	guardrailVer = os.Getenv("GUARDRAIL_VERSION")
}

func HandleRequest(ctx context.Context, event VoiceEvent) (Response, error) {
	log.Printf("Received Voice Stream Event")

	locale := os.Getenv("LOCALE")
	if locale == "" {
		locale = "en_US"
	}

	payload := map[string]interface{}{
		"audio":  event.AudioChunk,
		"stream": true,
		"locale": locale,
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
