import requests
import json
import os
from datetime import datetime, timedelta

# Read sensitive data from local JSON file
def load_secrets():
    secrets_path = os.path.expanduser("~/tmp/.secrets/test.json")
    try:
        with open(secrets_path, 'r') as f:
            secrets = json.load(f)
        return secrets
    except FileNotFoundError:
        print(f"Error: Secrets file not found at {secrets_path}")
        print("Please create the file with the following structure:")
        print('{\n  "ACCESS_TOKEN": "your_token_here",\n  "ACCOUNT_ID": "your_account_id_here",\n  "accountNumber": 12345678\n}')
        exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in {secrets_path}")
        exit(1)
    except Exception as e:
        print(f"Error reading secrets file: {e}")
        exit(1)

# Load secrets from file
secrets = load_secrets()
ACCESS_TOKEN = secrets.get('ACCESS_TOKEN')
ACCOUNT_ID = secrets.get('ACCOUNT_ID')
accountNumber = secrets.get('accountNumber')
SYMBOL = secrets.get('SYMBOL')

# Validate that all required secrets are present
if not all([ACCESS_TOKEN, ACCOUNT_ID, accountNumber]):
    print("Error: Missing required secrets in test.json file")
    print("Required fields: ACCESS_TOKEN, ACCOUNT_ID, accountNumber")
    exit(1)


## Schedule release time: Tomorrow @ 09:40
#tomorrow = datetime.now().astimezone() + timedelta(days=1)
#release_time =  tomorrow.replace(hour=9, minute=30, second=0, microsecond=0).isoformat()
#cancel_time  =  tomorrow.replace(hour=9, minute=40, second=0, microsecond=0).isoformat()

url = f'https://api.schwabapi.com/trader/v1/accounts/{ACCOUNT_ID}/orders'

headers = {
    'Authorization': f'Bearer {ACCESS_TOKEN}',
    'Content-Type': 'application/json'
}

# (Min BE) SELL -6 IPX Entry 39.02 Target 37.53 Exit 36.05 Cost/Share 34.56 GTC
# BUY 10 IPX BID >= 46.53 TS = 5.0% Target = 48.84 TargetGain = 34.7%

sell_quantity = 1
sell_trailing_stop_limit_to_target_price = 10
#activation_price = 46.53
sell_target_price = 42.1

buy_target_price = 9.21
buy_quantity = 1
buy_trailing_stop_limit_to_target_price = 5

# Load order payload from JSON file
def load_order_payload():
    json_file_path = os.path.join(os.path.dirname(__file__), 'sample_order_agi.json')
    try:
        with open(json_file_path, 'r') as f:
            order_payload = json.load(f)
        
        # Update account number from secrets
        for child_strategy in order_payload.get('childOrderStrategies', []):
            child_strategy['accountNumber'] = accountNumber
        
        return order_payload
    except FileNotFoundError:
        print(f"Error: Order JSON file not found at {json_file_path}")
        exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in {json_file_path}")
        exit(1)
    except Exception as e:
        print(f"Error reading order JSON file: {e}")
        exit(1)

order_payload = load_order_payload()

response = requests.post(url, headers=headers, json=order_payload)

print("Status Code:", response.status_code)
try:
    print(json.dumps(response.json(), indent=2))
except:
    print(response.text)


