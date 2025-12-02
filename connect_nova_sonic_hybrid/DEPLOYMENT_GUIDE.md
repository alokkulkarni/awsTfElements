# Deployment Guide: Customizing Queues and Contact Flows

This guide explains how to customize the Amazon Connect Queues and Contact Flows without modifying the core Terraform code. This approach allows you to design flows visually in the AWS Console, export them, and deploy them as part of your Infrastructure as Code pipeline.

## 1. Customizing Queues

Instead of hardcoding queues in the Terraform logic, you can define them in a `terraform.tfvars` file.

> **Tip:** A sample file named `terraform.tfvars.example` is included in the project. You can copy it to `terraform.tfvars` and modify it.

1.  Create a file named `terraform.tfvars` in the `connect_nova_sonic_hybrid` directory (or copy `terraform.tfvars.example`).
2.  Add your queues using the `connect_queues` variable:

```hcl
connect_queues = {
  "Sales" = {
    description = "Sales Department Queue"
  }
  "Support" = {
    description = "Customer Support Queue"
  }
  "Billing" = {
    description = "Billing & Payments Queue"
  }
  "Returns" = {
    description = "Product Returns and Refunds"
  }
}
```

**What happens next?**
*   Terraform will create these queues in Amazon Connect.
*   The Amazon Lex Chatbot will automatically update its "Department" slot to include these new queues.
*   The Chatbot will update its prompt to ask users about these specific departments.
*   The Lambda functions will automatically receive the ARNs for these queues to handle routing.

## 2. Configuration: Localization and Runtimes

### 2.1 Setting the Locale
The architecture supports dynamic localization for validation, currency, and AI responses. You can configure this in your `terraform.tfvars` file:

```hcl
# Available options: en_US, en_GB, fr_FR, de_DE
locale = "en_GB"
```

**Effects of changing the locale:**
*   **MCP Server**:
    *   `update_address`: Validates postcodes according to the region (e.g., 5 digits for US, alphanumeric for UK).
    *   `get_account_balance`: Returns the appropriate currency (USD, GBP, EUR).
*   **Voice & Chat**: The AI models (Claude 3 Haiku and Nova Sonic) are prompted to respond in the appropriate language and cultural context.

### 2.2 Choosing a Runtime
The project includes Lambda implementations in **Node.js**, **Python**, and **Go**.
*   By default, the Terraform configuration points to the **Node.js** handlers.
*   To switch runtimes, modify the `source_dir` and `handler` in `main.tf` (or the specific module definition) to point to the desired language folder (e.g., `lambda_chat_python`, `lambda_voice_go`).

## 3. Creating and Exporting Contact Flows

You are expected to design your Contact Flows using the Amazon Connect Visual Editor, as it is much easier than writing JSON manually.

### Step 2.1: Design the Flow
1.  Log in to your Amazon Connect Instance.
2.  Go to **Routing** -> **Contact Flows**.
3.  Create a new flow or edit an existing one.
4.  Add your logic (Play Prompts, Get Input, Invoke Lambda, etc.).
5.  **Crucial**: When you need to reference a Lambda or a Queue, pick *any* placeholder resource for now. We will replace it in the next step.

### Step 2.2: Export the Flow
1.  Save and Publish the flow (optional, but good for validation).
2.  Click the **Show additional flow information** (arrow icon) next to the Save button.
3.  Click **Export flow (beta)** or **Download**.
4.  Save the JSON file to your local machine.

## 3. Templatizing the Contact Flow (Automated)

The exported JSON contains hardcoded ARNs (Amazon Resource Names) specific to your current environment. To make this flow deployable anywhere, these ARNs must be replaced with Terraform variables.

We have provided a script to automate this process.

### Prerequisites
Ensure you have applied your Terraform configuration at least once so that the resources (Queues, Lambdas) exist.

```bash
terraform apply
```

### Running the Script
Run the `templatize_flow.py` script, passing the path to your exported JSON file.

```bash
python3 scripts/templatize_flow.py /path/to/your/exported_flow.json
```

**What the script does:**
1.  Queries Terraform to get the *current* ARNs of your Queues, Lambda, and Lex Bot.
2.  Scans your exported JSON file.
3.  Automatically replaces the hardcoded ARNs with the correct Terraform template variables (e.g., `${queues["Sales"]}`, `${voice_lambda_arn}`).
4.  Saves the result to `contact_flows/nova_sonic_ivr.json.tftpl` (or a custom path if specified).

### Advanced: Dynamic Routing Logic
If you want to use advanced dynamic loops (like `%{ for ... }`) inside your flow, you will still need to add those manually or ensure your flow design in Connect uses a pattern that the script can recognize (currently, the script only performs ARN substitution).

## 4. Deploying the Custom Flow

Once your `.tftpl` file is ready:

1.  Update your `terraform.tfvars` to point to your new file:

```hcl
contact_flow_template_file = "contact_flows/my_custom_flow.json.tftpl"
```

2.  Run Terraform:

```bash
terraform apply
```

Terraform will:
1.  Read your JSON template.
2.  Inject the correct ARNs for the current environment.
3.  Create/Update the Contact Flow in Amazon Connect.

## Summary of Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `connect_queues` | Map of queues to create. | Sales, Support, Billing |
| `contact_flow_template_file` | Path to the JSON template. | `contact_flows/nova_sonic_ivr.json.tftpl` |

