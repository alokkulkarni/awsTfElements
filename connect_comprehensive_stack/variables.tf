variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "connect-comprehensive"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "connect_instance_alias" {
  description = "Alias for the Connect Instance"
  type        = string
  default     = "my-connect-instance-demo-123" # Needs to be globally unique
}

variable "locale" {
  description = "Locale for the bot (e.g., en_US, en_GB)"
  type        = string
  default     = "en_GB"
}

variable "voice_id" {
  description = "Voice ID for the bot (e.g., Danielle, Amy)"
  type        = string
  default     = "Amy"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "ConnectComprehensive"
    ManagedBy = "Terraform"
  }
}

variable "queues" {
  description = "Map of queues to create"
  type = map(object({
    description = string
  }))
  default = {
    "GeneralAgentQueue" = { description = "Queue for general agents" }
    "AccountQueue"      = { description = "Queue for account services" }
    "LendingQueue"      = { description = "Queue for lending services" }
    "OnboardingQueue"   = { description = "Queue for onboarding services" }
  }
}

variable "lex_intents" {
  description = "Map of Lex intents to create"
  type = map(object({
    description         = string
    utterances          = list(string)
    fulfillment_enabled = bool
  }))
  default = {
    # Account Services
    "CheckBalance" = {
      description         = "Check account balance"
      utterances          = ["check balance", "what is my balance", "how much money do I have", "account balance", "show my balance", "balance inquiry", "what's in my account"]
      fulfillment_enabled = true
    }
    "TransactionHistory" = {
      description         = "View recent transactions"
      utterances          = ["show my transactions", "recent transactions", "what did I spend", "transaction history", "view transactions", "last transactions", "show spending"]
      fulfillment_enabled = true
    }
    "AccountDetails" = {
      description         = "Get account details like sort code and account number"
      utterances          = ["account details", "account number", "sort code", "my account info", "account information", "bank details"]
      fulfillment_enabled = true
    }
    "RequestStatement" = {
      description         = "Request bank statement"
      utterances          = ["send statement", "email statement", "I need a statement", "bank statement", "request statement", "mail statement"]
      fulfillment_enabled = true
    }
    
    # Card Services
    "ActivateCard" = {
      description         = "Activate a new card"
      utterances          = ["activate card", "activate my card", "new card activation", "I got a new card", "turn on my card", "enable card"]
      fulfillment_enabled = true
    }
    "ReportLostStolenCard" = {
      description         = "Report lost or stolen card - CRITICAL"
      utterances          = ["lost card", "stolen card", "my card is lost", "card was stolen", "I lost my card", "can't find my card", "block my card", "cancel card"]
      fulfillment_enabled = true
    }
    "ReportFraud" = {
      description         = "Report fraudulent activity - CRITICAL"
      utterances          = ["report fraud", "fraudulent charge", "fraud on my account", "suspicious activity", "I didn't make this transaction", "unauthorized transaction", "someone is using my card"]
      fulfillment_enabled = true
    }
    "ChangePIN" = {
      description         = "Change card PIN"
      utterances          = ["change PIN", "update PIN", "reset PIN", "new PIN", "I forgot my PIN", "change card PIN"]
      fulfillment_enabled = true
    }
    "DisputeTransaction" = {
      description         = "Dispute a transaction"
      utterances          = ["dispute transaction", "dispute charge", "wrong charge", "incorrect transaction", "challenge payment", "refund request"]
      fulfillment_enabled = true
    }
    
    # Transfer Services
    "InternalTransfer" = {
      description         = "Transfer between own accounts"
      utterances          = ["transfer money", "move money", "internal transfer", "transfer between accounts", "move funds", "transfer to savings"]
      fulfillment_enabled = true
    }
    "ExternalTransfer" = {
      description         = "Transfer to external account"
      utterances          = ["external transfer", "send money", "pay someone", "transfer to another bank", "bank transfer", "send payment"]
      fulfillment_enabled = true
    }
    "WireTransfer" = {
      description         = "International wire transfer"
      utterances          = ["wire transfer", "international transfer", "send money abroad", "SWIFT transfer", "overseas payment"]
      fulfillment_enabled = true
    }
    
    # Loan Services
    "LoanStatus" = {
      description         = "Check loan status"
      utterances          = ["loan status", "check my loan", "loan balance", "how much do I owe", "loan payment due", "mortgage status"]
      fulfillment_enabled = true
    }
    "LoanPayment" = {
      description         = "Make loan payment"
      utterances          = ["pay loan", "make loan payment", "loan payment", "pay mortgage", "payoff amount", "schedule payment"]
      fulfillment_enabled = true
    }
    "LoanApplication" = {
      description         = "Apply for a loan"
      utterances          = ["apply for loan", "loan application", "business loan", "personal loan", "mortgage application", "get a loan"]
      fulfillment_enabled = true
    }
    
    # General Services
    "TransferToAgent" = {
      description         = "Transfer to a human agent (BasicQueue)"
      utterances          = ["speak to agent", "talk to person", "human agent", "customer service", "speak to someone", "agent please", "help me"]
      fulfillment_enabled = true
    }
    "TransferToSpecialist" = {
      description         = "Transfer to specialist agent (Main Profile queues)"
      utterances          = ["speak to specialist", "need expert help", "escalate", "senior agent", "specialized help", "complex issue", "transfer to specialist"]
      fulfillment_enabled = true
    }
    "BranchLocator" = {
      description         = "Find nearest branch"
      utterances          = ["find branch", "nearest branch", "branch location", "where is the branch", "bank location", "ATM location"]
      fulfillment_enabled = true
    }
    "RoutingNumber" = {
      description         = "Get routing number"
      utterances          = ["routing number", "sort code", "bank routing", "what is the routing number", "branch code"]
      fulfillment_enabled = true
    }
  }
}

variable "lex_fallback_lambda" {
  description = "Configuration for the Lex Fallback Lambda"
  type = object({
    source_dir = string
    handler    = string
    runtime    = string
    timeout    = number
  })
  default = {
    source_dir = "lambda/lex_fallback"
    handler    = "lex_handler.lambda_handler"
    runtime    = "python3.11"
    timeout    = 30
  }
}

variable "enable_voice_id" {
  description = "Enable Voice ID biometric validation in the Lambda fulfillment"
  type        = bool
  default     = false
}

variable "enable_pin_validation" {
  description = "Enable PIN-based validation in the Lambda fulfillment"
  type        = bool
  default     = false
}

variable "enable_companion_auth" {
  description = "Enable Companion App Authentication"
  type        = bool
  default     = true
}

variable "mock_data" {
  description = "JSON string containing mock customer data for the Lambda"
  type        = string
  default     = "{\" +15550100\": {\"name\": \"John Doe\", \"pin\": \"1234\", \"balance\": \"$15,450.00\"}, \"+447700900000\": {\"name\": \"Jane Smith\", \"pin\": \"5678\", \"balance\": \"£2,300.00\"}}"
}

variable "contact_flow_template_path" {
  description = "Path to the Contact Flow template file"
  type        = string
  default     = "contact_flows/main_flow.json.tftpl"
}
