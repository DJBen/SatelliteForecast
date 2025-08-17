#!/usr/bin/env python3
"""
Bulk update App Store Connect localizations from JSON files.

This script reads JSON files from the locales directory and updates
the corresponding App Store version localizations using the App Store Connect API.
"""

import os
import json
import argparse
from pathlib import Path
from dotenv import load_dotenv
from app_store_connect_api import AppStoreConnectAPI


def load_localization_data(locales_dir: str, version: str) -> dict:
    """
    Load all JSON localization files from version-specific directory.
    
    Args:
        locales_dir: Path to the base locales directory
        version: App version string to create subdirectory path
        
    Returns:
        Dictionary mapping locale codes to localization data
    """
    # Create version-specific path: locales/<version>/
    locales_path = Path(locales_dir) / version
    localizations = {}
    
    if not locales_path.exists():
        print(f"❌ Locales directory not found: {locales_path}")
        return localizations
    
    json_files = list(locales_path.glob("*.json"))
    print(f"🔍 Found {len(json_files)} JSON localization files in {locales_path}")
    
    for json_file in json_files:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                locale = data.get('locale')
                if locale:
                    localizations[locale] = data
                    print(f"  ✅ Loaded {locale} from {json_file.name}")
                else:
                    print(f"  ⚠️  No locale field in {json_file.name}")
        except Exception as e:
            print(f"  ❌ Error loading {json_file.name}: {e}")
    
    return localizations


def update_app_localizations(
    api: AppStoreConnectAPI,
    app_id: str,
    version_string: str,
    localizations: dict,
    locales_to_update: list = None
):
    """
    Update app store version localizations.
    
    Args:
        api: AppStoreConnectAPI instance
        app_id: App ID
        version_string: Version string to update
        localizations: Dictionary of localization data
        locales_to_update: List of specific locales to update (optional)
    """
    print(f"\n📱 Getting app store versions...")
    versions = api.get_app_store_versions(app_id)
    
    # Find the target version
    target_version = None
    for version in versions:
        if version["attributes"]["versionString"] == version_string:
            target_version = version
            break
    
    if not target_version:
        print(f"❌ Version '{version_string}' not found")
        available_versions = [v["attributes"]["versionString"] for v in versions]
        print(f"Available versions: {', '.join(available_versions)}")
        return False
    
    version_id = target_version["id"]
    version_state = target_version["attributes"]["appStoreState"]
    print(f"✅ Found version: {version_string} (ID: {version_id}, State: {version_state})")
    
    # Get existing localizations
    print(f"🌍 Getting existing localizations...")
    existing_localizations = api.get_app_store_version_localizations(version_id)
    
    # Create a mapping of locale to localization ID
    locale_to_id = {}
    for loc in existing_localizations:
        locale_code = loc["attributes"]["locale"]
        locale_to_id[locale_code] = loc["id"]
    
    print(f"Found existing localizations: {', '.join(locale_to_id.keys())}")
    
    # Update each localization
    updated_count = 0
    for locale, data in localizations.items():
        # Skip if we're only updating specific locales
        if locales_to_update and locale not in locales_to_update:
            continue
            
        if locale not in locale_to_id:
            print(f"⚠️  Localization for locale '{locale}' not found in app store version")
            continue
        
        localization_id = locale_to_id[locale]
        
        try:
            print(f"\n📝 Updating {locale} localization...")
            
            # Extract the fields to update (excluding 'locale' field)
            update_data = {k: v for k, v in data.items() if k != 'locale'}
            
            # Update the localization
            updated = api.update_app_store_version_localization(
                localization_id,
                promotional_text=update_data.get('promotionalText'),
                whats_new=update_data.get('whatsNew')
            )
            
            print(f"  ✅ Successfully updated {locale}")
            
            # Show what was updated
            attributes = updated["data"]["attributes"]
            if update_data.get('promotionalText'):
                promo_text = attributes.get('promotionalText', 'N/A')
                print(f"  📢 Promotional Text: {promo_text[:100]}{'...' if len(promo_text) > 100 else ''}")
            
            if update_data.get('whatsNew'):
                whats_new = attributes.get('whatsNew', 'N/A')
                print(f"  🆕 What's New: {whats_new[:100]}{'...' if len(whats_new) > 100 else ''}")
            
            updated_count += 1
            
        except Exception as e:
            print(f"  ❌ Error updating {locale}: {e}")
    
    print(f"\n🎉 Successfully updated {updated_count} localizations!")
    return updated_count > 0


def main():
    # Load environment variables from .env file
    load_dotenv()
    
    parser = argparse.ArgumentParser(
        description="Bulk update App Store Connect localizations from JSON files",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # App identification
    parser.add_argument(
        "--bundle-id", 
        help="App bundle ID (e.g., com.example.app). If not provided, will read from APP_BUNDLE_ID environment variable."
    )
    
    # Required arguments
    parser.add_argument(
        "--version", 
        required=True,
        help="App version string (e.g., 1.0.0)"
    )
    
    # Optional arguments
    parser.add_argument(
        "--locales-dir",
        default="locales",
        help="Base directory containing version subdirectories with JSON localization files (default: locales). Files should be organized as locales/<version>/<locale>.json"
    )
    parser.add_argument(
        "--locales",
        nargs="+",
        help="Specific locales to update (e.g., en es fr). If not specified, all available locales will be updated."
    )
    
    args = parser.parse_args()
    
    try:
        # Initialize API client
        print("🔐 Initializing App Store Connect API client...")
        api = AppStoreConnectAPI()
        
        # Get bundle ID from argument or environment variable
        bundle_id = args.bundle_id or os.environ.get('APP_BUNDLE_ID')
        
        if not bundle_id:
            print("❌ Bundle ID is required. Provide it via --bundle-id argument or APP_BUNDLE_ID environment variable.")
            return 1
        
        # Find the app
        print(f"🔍 Looking for app with bundle ID '{bundle_id}'...")
        app = api.find_app_by_bundle_id(bundle_id)
        
        if not app:
            print(f"❌ App with bundle ID '{bundle_id}' not found")
            return 1
        
        app_id = app["id"]
        app_name = app["attributes"]["name"]
        print(f"✅ Found app: {app_name} (ID: {app_id})")
        
        # Load localization data
        print(f"\n📂 Loading localization data from {args.locales_dir}/{args.version}...")
        localizations = load_localization_data(args.locales_dir, args.version)
        
        if not localizations:
            print("❌ No localization data found")
            return 1
        
        # Update localizations
        success = update_app_localizations(
            api, 
            app_id, 
            args.version, 
            localizations,
            args.locales
        )
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n⚠️  Operation cancelled by user")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1


if __name__ == "__main__":
    import sys
    sys.exit(main())
