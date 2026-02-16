import requests
from django.conf import settings

def send_authkey_otp(mobile: str, otp: str) -> dict:
    """
    Sends OTP using AuthKey API.
    
    Args:
        mobile: 10-digit mobile number.
        otp: The OTP to send.
    
    Returns:
        dict: The JSON response from AuthKey or error details.
    """
    
    base_url = "https://api.authkey.io/request"
    
    params = {
        "authkey": settings.AUTHKEY_API_KEY,
        "mobile": mobile,
        "country_code": "91",
        "sid": settings.AUTHKEY_SID,
        "company": settings.AUTHKEY_COMPANY,
        "otp": otp,
        "wid": settings.AUTHKEY_WID,
        "val": otp,
        "code": otp,
        "1": otp,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        print(f"AuthKey OTP Request Failed: {e}")
        return {"status": "error", "message": str(e)}


def send_onboarding_request_whatsapp(mobile: str, name: str) -> dict:
    """
    Sends Onboarding Request via WhatsApp using AuthKey.
    """
    base_url = "https://api.authkey.io/request"
    
    # Clean name default
    if not name:
        name = "Operator"

    params = {
        "authkey": settings.AUTHKEY_API_KEY,
        "mobile": mobile,
        "country_code": "91",
        "wid": "9848",
        # "name": name,  # Removed: might confuse gateway if not mapped
        "1": name, # Mapping Name to variable {1}
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        # response.raise_for_status() # AuthKey sometimes returns 200 with error msg, so strict raise might be overkill but good for debug
        print(f"AuthKey WhatsApp Response: {response.text}")
        return response.json()
    except Exception as e:
        print(f"AuthKey WhatsApp Request Failed: {e}")
        return {"status": "error", "message": str(e)}

def send_assignment_notification_whatsapp(mobile: str, role: str) -> dict:
    """
    Sends Assignment Notification via WhatsApp using AuthKey.
    Template ID (wid): 9718
    Variable {1}: Role
    """
    base_url = "https://api.authkey.io/request"
    
    params = {
        "authkey": settings.AUTHKEY_API_KEY,
        "mobile": mobile,
        "country_code": "91",
        "wid": "9718",
        "1": role, 
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        print(f"AuthKey Assignment Notification Response: {response.text}")
        return response.json()
    except Exception as e:
        print(f"AuthKey Assignment Notification Failed: {e}")
        return {"status": "error", "message": str(e)}

import re
import secrets

def normalize_mobile(m: str) -> str:
    """Store/search mobile in a canonical form: last 10 digits."""
    digits = "".join(ch for ch in (m or "") if ch.isdigit())
    if len(digits) >= 10:
        digits = digits[-10:]
    return digits


def is_valid_indian_mobile(mobile: str) -> bool:
    """Check if the string matches Indian mobile number regex (10 digits starting with 6-9)."""
    pattern = r'^[6789]\d{9}$'
    return bool(re.match(pattern, mobile))


def generate_operator_username(mobile_10: str) -> str:
    """Collision-safe username generator."""
    suffix = mobile_10[-6:] if len(mobile_10) >= 6 else mobile_10
    rand = secrets.token_hex(3)  # 6 hex chars
    return f"op_{suffix}_{rand}"
