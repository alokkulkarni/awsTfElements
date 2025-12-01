package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	dynamotypes "github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/lexmodelsv2"
)

type LexEvent struct {
	SessionState    SessionState `json:"sessionState"`
	InputTranscript string       `json:"inputTranscript"`
}

type SessionState struct {
	Intent            Intent            `json:"intent"`
	DialogAction      DialogAction      `json:"dialogAction"`
	SessionAttributes map[string]string `json:"sessionAttributes,omitempty"`
}

type Intent struct {
	Name  string          `json:"name"`
	Slots map[string]Slot `json:"slots,omitempty"`
	State string          `json:"state,omitempty"`
}

type Slot struct {
	Value SlotValue `json:"value"`
}

type SlotValue struct {
	OriginalValue string `json:"originalValue"`
}

type DialogAction struct {
	Type string `json:"type"`
}

type LexResponse struct {
	SessionState SessionState `json:"sessionState"`
	Messages     []Message    `json:"messages"`
}

type Message struct {
	ContentType string `json:"contentType"`
	Content     string `json:"content"`
}

var (
	bedrockClient *bedrockruntime.Client
	lexClient     *lexmodelsv2.Client
	dynamoClient  *dynamodb.Client
	queueMap      map[string]string
	faqCacheTable string
	guardrailID   string
	guardrailVer  string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	bedrockClient = bedrockruntime.NewFromConfig(cfg)
	lexClient = lexmodelsv2.NewFromConfig(cfg)
	dynamoClient = dynamodb.NewFromConfig(cfg)

	queueMapStr := os.Getenv("QUEUE_MAP")
	if queueMapStr == "" {
		queueMapStr = "{}"
	}
	json.Unmarshal([]byte(queueMapStr), &queueMap)

	faqCacheTable = os.Getenv("FAQ_CACHE_TABLE")
	guardrailID = os.Getenv("GUARDRAIL_ID")
	guardrailVer = os.Getenv("GUARDRAIL_VERSION")
}

func HandleRequest(ctx context.Context, event LexEvent) (LexResponse, error) {
	eventJSON, _ := json.Marshal(event)
	log.Printf("Received event: %s", string(eventJSON))

	intentName := event.SessionState.Intent.Name
	userMessage := event.InputTranscript

	if intentName == "TalkToAgent" {
		departmentSlot, ok := event.SessionState.Intent.Slots["Department"]
		var department string
		if ok {
			department = departmentSlot.Value.OriginalValue
		}

		if arn, ok := queueMap[department]; ok {
			return LexResponse{
				SessionState: SessionState{
					DialogAction: DialogAction{Type: "Close"},
					Intent:       Intent{Name: intentName, State: "Fulfilled"},
					SessionAttributes: map[string]string{
						"TargetQueue":    department,
						"TargetQueueArn": arn,
					},
				},
				Messages: []Message{{ContentType: "PlainText", Content: fmt.Sprintf("Transferring you to %s...", department)}},
			}, nil
		} else {
			departments := make([]string, 0, len(queueMap))
			for k := range queueMap {
				departments = append(departments, k)
			}
			return closeResponse(event, fmt.Sprintf("Sorry, I couldn't find a queue for %s. Available departments are: %s.", department, strings.Join(departments, ", "))), nil
		}
	}

	if intentName == "FallbackIntent" {
		// 1. Check Cache
		hash := sha256.Sum256([]byte(strings.TrimSpace(strings.ToLower(userMessage))))
		questionHash := hex.EncodeToString(hash[:])

		if faqCacheTable != "" {
			resp, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
				TableName: aws.String(faqCacheTable),
				Key: map[string]dynamotypes.AttributeValue{
					"QuestionHash": &dynamotypes.AttributeValueMemberS{Value: questionHash},
				},
			})
			if err == nil && resp.Item != nil {
				ttlAttr, ok := resp.Item["TTL"].(*dynamotypes.AttributeValueMemberN)
				if ok {
					ttl, _ := strconv.ParseInt(ttlAttr.Value, 10, 64)
					if ttl > time.Now().Unix() {
						answerAttr, ok := resp.Item["Answer"].(*dynamotypes.AttributeValueMemberS)
						if ok {
							log.Println("Cache Hit! Returning cached answer.")
							return closeResponse(event, answerAttr.Value), nil
						}
					}
				}
			}
		}

		// 2. Bedrock Call
		departments := make([]string, 0, len(queueMap))
		for k := range queueMap {
			departments = append(departments, k)
		}

		locale := os.Getenv("LOCALE")
		if locale == "" {
			locale = "en_US"
		}

		prompt := fmt.Sprintf(`You are an intelligent intent classifier for a customer service bot. 
		The available departments are: %s.
		The user's locale is: %s. Please respond appropriately for this locale.
		
		User message: "%s"
		
		Instructions:
		1. If the user wants to speak to a specific department, reply with ONLY the department name (e.g., "Sales").
		2. If the user is asking a general question, reply with the answer to the question.
		`, strings.Join(departments, ", "), locale, userMessage)

		payload := map[string]interface{}{
			"anthropic_version": "bedrock-2023-05-31",
			"max_tokens":        1000,
			"messages": []map[string]interface{}{
				{
					"role": "user",
					"content": []map[string]string{
						{"type": "text", "text": prompt},
					},
				},
			},
		}

		payloadBytes, _ := json.Marshal(payload)

		input := &bedrockruntime.InvokeModelInput{
			ModelId:     aws.String("anthropic.claude-3-haiku-20240307-v1:0"),
			ContentType: aws.String("application/json"),
			Accept:      aws.String("application/json"),
			Body:        payloadBytes,
			Trace:       types.TraceEnabled,
		}

		if guardrailID != "" && guardrailVer != "" {
			input.GuardrailIdentifier = aws.String(guardrailID)
			input.GuardrailVersion = aws.String(guardrailVer)
		}

		resp, err := bedrockClient.InvokeModel(ctx, input)

		if err != nil {
			log.Printf("Error invoking Bedrock: %v", err)
			return closeResponse(event, "I'm having trouble understanding right now. Please try again."), nil
		}

		var responseBody struct {
			Content []struct {
				Text string `json:"text"`
			} `json:"content"`
		}
		json.Unmarshal(resp.Body, &responseBody)
		completion := strings.TrimSpace(responseBody.Content[0].Text)

		// Self-Learning Logic
		if arn, ok := queueMap[completion]; ok {
			log.Printf("Bedrock classified intent as: %s. Initiating self-learning...", completion)
			go updateLexIntent(userMessage, completion) // Fire and forget (goroutine)
			return LexResponse{
				SessionState: SessionState{
					DialogAction: DialogAction{Type: "Close"},
					Intent:       Intent{Name: "TalkToAgent", State: "Fulfilled"},
					SessionAttributes: map[string]string{
						"TargetQueue":    completion,
						"TargetQueueArn": arn,
					},
				},
				Messages: []Message{{ContentType: "PlainText", Content: fmt.Sprintf("I understand you want to speak to %s. Transferring you now...", completion)}},
			}, nil
		} else {
			// General Answer - Cache it
			if faqCacheTable != "" {
				ttl := time.Now().Add(24 * time.Hour).Unix()
				dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
					TableName: aws.String(faqCacheTable),
					Item: map[string]dynamotypes.AttributeValue{
						"QuestionHash": &dynamotypes.AttributeValueMemberS{Value: questionHash},
						"Question":     &dynamotypes.AttributeValueMemberS{Value: userMessage}, // Truncate if needed
						"Answer":       &dynamotypes.AttributeValueMemberS{Value: completion},
						"TTL":          &dynamotypes.AttributeValueMemberN{Value: fmt.Sprintf("%d", ttl)},
					},
				})
			}
			return closeResponse(event, completion), nil
		}
	}

	return closeResponse(event, "I didn't understand that."), nil
}

func closeResponse(event LexEvent, message string) LexResponse {
	return LexResponse{
		SessionState: SessionState{
			DialogAction: DialogAction{Type: "Close"},
			Intent:       Intent{Name: event.SessionState.Intent.Name, State: "Fulfilled"},
		},
		Messages: []Message{{ContentType: "PlainText", Content: message}},
	}
}

func updateLexIntent(utterance, department string) {
	// Implementation omitted for brevity, similar logic to Python/Node
	// Requires DescribeIntent, append utterance, UpdateIntent
	log.Printf("Updating Lex intent for %s with utterance %s", department, utterance)
}

func main() {
	lambda.Start(HandleRequest)
}
