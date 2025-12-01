import json
import datetime
import os
from fastmcp import FastMCP
from pydantic import BaseModel, Field

# Initialize FastMCP
mcp = FastMCP("NovaSonicTools")

# Define Tools using FastMCP decorators
@mcp.tool()
def update_address(street: str, city: str, zip_code: str) -> dict:
    """Updates the user's address."""
    print(f"Updating address to: {street}, {city}, {zip_code}")
    
    locale = os.environ.get('LOCALE', 'en_US')
    
    if locale == 'en_US':
        if len(zip_code) != 5 or not zip_code.isdigit():
            raise ValueError("Invalid US Zip Code (must be 5 digits)")
    elif locale == 'en_GB':
        # Simple check for UK postcode format (alphanumeric)
        if len(zip_code) < 5 or len(zip_code) > 8:
             raise ValueError("Invalid UK Postcode")
    
    if zip_code == "00000":
        raise ValueError("Invalid Zip Code")
        
    return {
        'status': 'success',
        'message': 'Address updated successfully',
        'updated_fields': {'street': street, 'city': city, 'zip_code': zip_code},
        'timestamp': datetime.datetime.now().isoformat()
    }

@mcp.tool()
def get_account_balance() -> dict:
    """Retrieves the current account balance."""
    locale = os.environ.get('LOCALE', 'en_US')
    
    currency = 'USD'
    if locale == 'en_GB':
        currency = 'GBP'
    elif locale == 'eu_FR' or locale == 'eu_DE':
        currency = 'EUR'
        
    return {
        'status': 'success',
        'balance': 100.00,
        'currency': currency
    }

def handler(event, context):
    print("MCP Server Received Event:", json.dumps(event, indent=2))
    
    tool_name = event.get('tool')
    args = event.get('arguments', {})
    
    if not tool_name:
        return {
            'status': 'error',
            'message': 'Invalid Tool Invocation: Tool name missing'
        }
        
    try:
        # FastMCP doesn't expose a direct 'call_tool' in its public API easily for this use case,
        # but we can access the tool function directly if we know the name.
        # In a real FastMCP server, this is handled by the protocol loop.
        # Here we act as a bridge.
        
        # Note: FastMCP stores tools in an internal registry. 
        # We can iterate or check if the function exists in the local scope if we imported it,
        # but FastMCP's registry is cleaner.
        
        # Accessing internal tool registry (implementation detail of FastMCP)
        # If FastMCP changes internals, this might break. 
        # Alternative: Maintain our own map or use `mcp.list_tools()` to find it.
        
        # Let's try to find the tool in the mcp object
        target_tool = None
        # Depending on FastMCP version, tools might be in mcp._tools or similar.
        # For safety in this generated code, we'll use a manual lookup map 
        # OR assume the function name matches the tool name (which it does by default).
        
        local_tools = {
            "update_address": update_address,
            "get_account_balance": get_account_balance
        }
        
        if tool_name in local_tools:
            # FastMCP tools are wrapped, but calling them directly usually works 
            # or we call the underlying function.
            # The decorator usually returns the wrapper which is callable.
            result = local_tools[tool_name](**args)
            return result
        else:
             return {
                'status': 'error',
                'message': f"Tool {tool_name} not found"
            }

    except Exception as e:
        print(f"MCP Execution Error: {e}")
        return {
            'status': 'error',
            'message': f"Internal MCP Error: {str(e)}"
        }

