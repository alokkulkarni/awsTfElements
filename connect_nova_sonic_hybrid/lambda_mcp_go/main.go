package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"
	"unicode"

	"github.com/aws/aws-lambda-go/lambda"
)

// MCPEvent represents the incoming event structure for the MCP server
type MCPEvent struct {
	Tool      string                 `json:"tool"`
	Arguments map[string]interface{} `json:"arguments"`
}

// MCPResponse represents the standard response structure
type MCPResponse struct {
	Status        string                 `json:"status"`
	Message       string                 `json:"message,omitempty"`
	UpdatedFields map[string]interface{} `json:"updated_fields,omitempty"`
	Timestamp     string                 `json:"timestamp,omitempty"`
	Balance       float64                `json:"balance,omitempty"`
	Currency      string                 `json:"currency,omitempty"`
}

func HandleRequest(ctx context.Context, event MCPEvent) (MCPResponse, error) {
	eventJSON, _ := json.Marshal(event)
	log.Printf("MCP Server Received Event: %s", string(eventJSON))

	if event.Tool == "" {
		return MCPResponse{
			Status:  "error",
			Message: "Invalid Tool Invocation: Tool name missing",
		}, nil
	}

	switch event.Tool {
	case "update_address":
		return handleUpdateAddress(event.Arguments)
	case "get_account_balance":
		return handleGetAccountBalance()
	default:
		return MCPResponse{
			Status:  "error",
			Message: fmt.Sprintf("Tool %s not found", event.Tool),
		}, nil
	}
}

func handleUpdateAddress(args map[string]interface{}) (MCPResponse, error) {
	street, _ := args["street"].(string)
	city, _ := args["city"].(string)
	zipCode, _ := args["zip_code"].(string)

	log.Printf("Updating address to: %s, %s, %s", street, city, zipCode)

	locale := os.Getenv("LOCALE")
	if locale == "" {
		locale = "en_US"
	}

	if locale == "en_US" {
		if len(zipCode) != 5 || !isNumeric(zipCode) {
			return MCPResponse{
				Status:  "error",
				Message: "Invalid US Zip Code (must be 5 digits)",
			}, nil // Returning error as response with status error, or could return actual error
		}
	} else if locale == "en_GB" {
		// Simple check for UK postcode format (alphanumeric)
		if len(zipCode) < 5 || len(zipCode) > 8 {
			return MCPResponse{
				Status:  "error",
				Message: "Invalid UK Postcode",
			}, nil
		}
	}

	if zipCode == "00000" {
		return MCPResponse{
			Status:  "error",
			Message: "Invalid Zip Code",
		}, nil
	}

	return MCPResponse{
		Status:  "success",
		Message: "Address updated successfully",
		UpdatedFields: map[string]interface{}{
			"street":   street,
			"city":     city,
			"zip_code": zipCode,
		},
		Timestamp: time.Now().Format(time.RFC3339),
	}, nil
}

func handleGetAccountBalance() (MCPResponse, error) {
	locale := os.Getenv("LOCALE")
	if locale == "" {
		locale = "en_US"
	}

	currency := "USD"
	if locale == "en_GB" {
		currency = "GBP"
	} else if locale == "eu_FR" || locale == "eu_DE" {
		currency = "EUR"
	}

	return MCPResponse{
		Status:   "success",
		Balance:  100.00,
		Currency: currency,
	}, nil
}

func isNumeric(s string) bool {
	for _, c := range s {
		if !unicode.IsDigit(c) {
			return false
		}
	}
	return true
}

func main() {
	lambda.Start(HandleRequest)
}
