# Custom CCP Branding & Microsoft Dynamics Integration Guide

This guide provides instructions on how to customize the branding of your Amazon Connect Contact Control Panel (CCP) and integrate it into Microsoft Dynamics 365.

## 1. Security & Architecture

Your Custom CCP is deployed with a robust security posture:
*   **HTTPS Only**: Served via CloudFront with a valid SSL certificate.
*   **WAF Protected**: An AWS Web Application Firewall (WAF) is attached to the CloudFront distribution to protect against common web exploits (SQLi, XSS, etc.).
*   **Private Origin**: The S3 bucket hosting the content is private and only accessible via CloudFront using Origin Access Control (OAC).

## 2. Branding the Custom CCP

The custom CCP is a web application hosted on S3 and served via CloudFront. It wraps the standard Amazon Connect CCP (iframe) with your own custom HTML, CSS, and JavaScript using the [Amazon Connect Streams API](https://github.com/amazon-connect/amazon-connect-streams).

### File Location
The source file for the CCP is located at:
`connect_comprehensive_stack/ccp_site/index.html.tftpl`

### Customization Steps

#### A. Changing the Logo and Colors
1.  **Open** `index.html.tftpl`.
2.  **Update CSS**: Modify the `<style>` block to match your corporate brand.
    *   Change `background-color` in `body` and `#ccp-container`.
    *   Update fonts in `font-family`.
    *   Style the headers (`h1`, `h3`) with your brand colors.
3.  **Add Logo**: Insert an `<img>` tag in the `#content` div or header area.
    ```html
    <div id="header">
        <img src="https://your-cdn.com/logo.png" alt="Company Logo" height="50">
    </div>
    ```

#### B. Custom Layout
The current layout uses a simple flexbox split:
*   **Left Panel (`#ccp-container`)**: The actual Amazon Connect softphone.
*   **Right Panel (`#content`)**: Your custom workspace (CRM data, scripts, etc.).

You can resize these or change the layout to a top/bottom split by modifying the `#container` CSS.

#### C. Adding Custom Functionality
You can extend the JavaScript to add features like:
*   **Screen Pops**: Automatically open a customer profile when a call arrives.
*   **Custom Buttons**: Add buttons to trigger Lambda functions or external APIs.
*   **Task Management**: Display tasks from external systems alongside the call.

Example: Screen Pop on Incoming Call
```javascript
connect.contact(function(contact) {
    contact.onIncoming(function(contact) {
        var attributes = contact.getAttributes();
        var customerId = attributes.customerId ? attributes.customerId.value : null;
        if (customerId) {
            // Logic to open CRM record
            window.open(`https://crm.example.com/customers/${customerId}`, '_blank');
        }
    });
});
```

### Deploying Changes
After modifying the `index.html.tftpl` file, apply the Terraform configuration to upload the new version:
```bash
terraform apply -auto-approve
```
*Note: You may need to invalidate the CloudFront cache if changes don't appear immediately.*

---

## 2. Integration with Microsoft Dynamics 365

To embed this custom CCP (or the standard one) into Microsoft Dynamics 365, you typically use the **Channel Integration Framework (CIF)**.

### Prerequisites
*   **Dynamics 365 Instance**: You must have admin access.
*   **Channel Integration Framework App**: Install "Channel Integration Framework v2.0" from the Microsoft AppSource if not already present.
*   **CCP URL**: The CloudFront URL output from your Terraform deployment (`ccp_url`).

### Configuration Steps

1.  **Login to Dynamics 365** as an Administrator.
2.  Navigate to **Channel Integration Framework**.
3.  Click **+ New** to create a new Channel Provider.
4.  **Fill in the Configuration**:
    *   **Name**: `AmazonConnectVoice`
    *   **Label**: `Amazon Connect`
    *   **Channel URL**: Enter your CloudFront CCP URL (e.g., `https://d12345.cloudfront.net/index.html`).
    *   **Enable Outbound Communication**: `Yes` (allows click-to-dial).
    *   **Channel Order**: `1`
    *   **API Version**: `2.0`
    *   **Trusted Domain**: Enter your CloudFront domain (e.g., `https://d12345.cloudfront.net`).
5.  **Select Unified Interface Apps**:
    *   Choose the Dynamics apps where you want the phone to appear (e.g., "Customer Service Hub", "Sales Hub").
6.  **Select Roles**:
    *   Assign the security roles that should see the dialer (e.g., "Customer Service Representative").
7.  **Save and Close**.

### Enabling Click-to-Dial (Optional)
To enable click-to-dial from Dynamics phone number fields:
1.  Ensure your custom CCP code (`index.html.tftpl`) includes logic to handle the `clickToAct` event from the CIF JavaScript API.
2.  Add the Microsoft CIF library to your `index.html.tftpl`:
    ```html
    <script src="https://xrm-cdn.crm.dynamics.com/webclient/cif/2.0/Microsoft.CIFramework.js"></script>
    ```
3.  Add a handler in your script:
    ```javascript
    Microsoft.CIFramework.addHandler("onclicktoact", function(payload) {
        var phoneNumber = JSON.parse(payload).value;
        // Use Connect Streams to dial
        var agent = new connect.Agent();
        agent.connect(connect.Address.byPhoneNumber(phoneNumber), {});
        return Promise.resolve();
    });
    ```

### Testing the Integration
1.  Open the **Customer Service Hub** app in Dynamics 365.
2.  You should see the **Amazon Connect widget** on the right side or as a minimized panel.
3.  **Log in** to the CCP.
4.  **Make a test call** to verify audio and connectivity.

### Security Note
Ensure that your **Amazon Connect Approved Origins** (managed by the Terraform `null_resource`) includes the Dynamics 365 domain if you are embedding the standard CCP directly. Since we are embedding a *custom* CCP hosted on CloudFront, the CloudFront domain is the one that needs to be whitelisted in Connect (which is already handled by the Terraform script). However, Dynamics 365 might require Cross-Origin Resource Sharing (CORS) adjustments if your custom CCP tries to make direct API calls back to Dynamics.
