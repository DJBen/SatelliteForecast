#!/usr/bin/env python3
"""
App Store Connect API Client for updating app version localizations.

This script allows you to update promotional text and what's new for a specific
app version localization using the App Store Connect API.

Required environment variables:
- APP_STORE_CONNECT_API_KEY_ID: Your API key ID
- APP_STORE_CONNECT_API_ISSUER_ID: Your issuer ID
- APP_STORE_CONNECT_API_PRIVATE_KEY_PATH: Path to your .p8 private key file
"""

import os
import json
import time
import jwt
import requests
from typing import Optional, Dict, Any


class AppStoreConnectAPI:
    """Client for interacting with the App Store Connect API."""
    
    BASE_URL = "https://api.appstoreconnect.apple.com"
    
    def __init__(self):
        """Initialize the API client with credentials from environment variables."""
        self.api_key_id = os.getenv("APP_STORE_CONNECT_API_KEY_ID")
        self.issuer_id = os.getenv("APP_STORE_CONNECT_API_ISSUER_ID")
        self.private_key_path = os.getenv("APP_STORE_CONNECT_API_PRIVATE_KEY_PATH")
        
        if not all([self.api_key_id, self.issuer_id, self.private_key_path]):
            raise ValueError(
                "Missing required environment variables. Please set:\n"
                "- APP_STORE_CONNECT_API_KEY_ID\n"
                "- APP_STORE_CONNECT_API_ISSUER_ID\n"
                "- APP_STORE_CONNECT_API_PRIVATE_KEY_PATH"
            )
        
        self._load_private_key()
    
    def _load_private_key(self):
        """Load the private key from the specified file path, expanding ~ if present."""
        expanded_path = os.path.expanduser(self.private_key_path)
        try:
            with open(expanded_path, 'r') as key_file:
                self.private_key = key_file.read()
        except FileNotFoundError:
            raise FileNotFoundError(f"Private key file not found: {expanded_path}")
        except Exception as e:
            raise Exception(f"Error reading private key file: {e}")
        
    def _generate_jwt_token(self) -> str:
        """Generate a JWT token for authentication."""
        current_time = int(time.time())
        
        payload = {
            "iss": self.issuer_id,
            "iat": current_time,
            "exp": current_time + 1200,  # Token expires in 20 minutes
            "aud": "appstoreconnect-v1"
        }
        
        headers = {
            "kid": self.api_key_id,
            "typ": "JWT",
            "alg": "ES256"
        }
        
        token = jwt.encode(payload, self.private_key, algorithm="ES256", headers=headers)
        return token
    
    def _make_request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict[Any, Any]:
        """Make an authenticated request to the App Store Connect API."""
        token = self._generate_jwt_token()
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        url = f"{self.BASE_URL}{endpoint}"
        
        response = requests.request(method, url, headers=headers, json=data)
        
        if response.status_code >= 400:
            try:
                error_data = response.json()
                print(f"API Error ({response.status_code}): {json.dumps(error_data, indent=2)}")
            except:
                print(f"HTTP Error ({response.status_code}): {response.text}")
            response.raise_for_status()
        
        return response.json() if response.content else {}
    
    def find_app_by_bundle_id(self, bundle_id: str) -> Optional[Dict]:
        """Find an app by its bundle ID."""
        endpoint = f"/v1/apps?filter[bundleId]={bundle_id}"
        response = self._make_request("GET", endpoint)
        
        apps = response.get("data", [])
        if not apps:
            return None
        
        return apps[0]  # Return the first matching app
    
    def find_app_by_name(self, app_name: str) -> Optional[Dict]:
        """Find an app by its name."""
        endpoint = f"/v1/apps?filter[name]={app_name}"
        response = self._make_request("GET", endpoint)
        
        apps = response.get("data", [])
        if not apps:
            return None
        
        return apps[0]  # Return the first matching app
    
    def get_app_store_versions(self, app_id: str) -> list:
        """Get all App Store versions for a given app."""
        endpoint = f"/v1/apps/{app_id}/appStoreVersions"
        response = self._make_request("GET", endpoint)
        
        return response.get("data", [])
    
    def get_app_store_version_localizations(self, app_store_version_id: str) -> list:
        """Get all localizations for a given App Store version."""
        endpoint = f"/v1/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations"
        response = self._make_request("GET", endpoint)
        
        return response.get("data", [])
    
    def update_app_store_version_localization(
        self, 
        localization_id: str,
        promotional_text: Optional[str] = None,
        whats_new: Optional[str] = None,
        description: Optional[str] = None,
        keywords: Optional[str] = None
    ) -> Dict:
        """
        Update promotional text, what's new, description, and/or keywords for a specific localization.
        
        Args:
            localization_id: The ID of the localization to update
            promotional_text: The new promotional text (optional)
            whats_new: The new what's new text (optional)
            description: The new app description (optional)
            keywords: The new keywords for the app (optional)
        
        Returns:
            The updated localization data
        """
        if not any([promotional_text, whats_new, description, keywords]):
            raise ValueError("At least one of promotional_text, whats_new, description, or keywords must be provided")
        
        data = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": localization_id,
                "attributes": {}
            }
        }
        
        if promotional_text is not None:
            data["data"]["attributes"]["promotionalText"] = promotional_text
        
        if whats_new is not None:
            data["data"]["attributes"]["whatsNew"] = whats_new
        
        if description is not None:
            data["data"]["attributes"]["description"] = description
        
        if keywords is not None:
            data["data"]["attributes"]["keywords"] = keywords
        
        endpoint = f"/v1/appStoreVersionLocalizations/{localization_id}"
        return self._make_request("PATCH", endpoint, data)
