# App Store Connect API Client

This Python script allows you to update promotional text and what's new for specific app version localizations using the App Store Connect API.

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Get App Store Connect API Credentials

You'll need to create an API key in App Store Connect:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to Users and Access > Keys
3. Click the "+" button to create a new API key
4. Give it a name and select the appropriate role (App Manager or Admin)
5. Download the `.p8` private key file (keep it secure!)
6. Note down the Key ID and Issuer ID

### 3. Set Environment Variables

Set the following environment variables:

```bash
export APP_STORE_CONNECT_API_KEY_ID="your_key_id_here"
export APP_STORE_CONNECT_API_ISSUER_ID="your_issuer_id_here"
export APP_STORE_CONNECT_API_PRIVATE_KEY_PATH="/path/to/your/AuthKey_XXXXXXXXXX.p8"
```

Or create a `.env` file in this directory:

```bash
APP_STORE_CONNECT_API_KEY_ID=your_key_id_here
APP_STORE_CONNECT_API_ISSUER_ID=your_issuer_id_here
APP_STORE_CONNECT_API_PRIVATE_KEY_PATH=/path/to/your/AuthKey_XXXXXXXXXX.p8
```

## Usage

### Convert Markdown to JSON

If you have localization content in markdown files, you can convert them to JSON format with App Store Connect API field names:

```bash
python3 convert_md_to_json.py
```

This will convert all `.md` files in the `locales/` directory to `.json` files with the proper field mapping:
- "Promotional Text" → `promotionalText`
- "Description" → `description`
- "What's New in This Version" → `whatsNew`
- "Keywords" → `keywords`
- "Marketing URL" → `marketingUrl`
- "Support URL" → `supportUrl`

### Bulk Update from JSON Files

Update multiple localizations at once from JSON files:

```bash
# Update all localizations for version 1.0.0
python3 bulk_update_localizations.py --bundle-id com.yourcompany.yourapp --version 1.0.0

# Update only specific locales
python3 bulk_update_localizations.py --bundle-id com.yourcompany.yourapp --version 1.0.0 --locales en es fr

# Use app name instead of bundle ID
python3 bulk_update_localizations.py --app-name "Your App Name" --version 1.0.0
```

### Single Localization Update (Basic Usage)

Edit the `main()` function in `update_app_version_localization.py` to specify:

- `BUNDLE_ID`: Your app's bundle identifier
- `VERSION_STRING`: The version you want to update (e.g., "1.0.0")
- `LOCALE`: The locale you want to update (e.g., "en-US")

Then run:

```bash
python3 update_app_version_localization.py
```

### Programmatic Usage

You can also use the `AppStoreConnectAPI` class directly:

```python
from update_app_version_localization import AppStoreConnectAPI

# Initialize the API client
api = AppStoreConnectAPI()

# Find your app
app = api.find_app_by_bundle_id("com.yourcompany.yourapp")
app_id = app["id"]

# Get app store versions
versions = api.get_app_store_versions(app_id)

# Find the version you want to update
target_version = None
for version in versions:
    if version["attributes"]["versionString"] == "1.0.0":
        target_version = version
        break

# Get localizations for this version
localizations = api.get_app_store_version_localizations(target_version["id"])

# Find the localization you want to update
target_localization = None
for localization in localizations:
    if localization["attributes"]["locale"] == "en-US":
        target_localization = localization
        break

# Update the localization
updated = api.update_app_store_version_localization(
    target_localization["id"],
    promotional_text="Your new promotional text here",
    whats_new="• Bug fixes\n• New features\n• Performance improvements"
)
```

## JSON File Structure

The JSON localization files should follow this structure:

```json
{
  "promotionalText": "Your promotional text here",
  "description": "Your app description here",
  "whatsNew": "• Bug fixes\n• New features\n• Performance improvements",
  "keywords": "keyword1,keyword2,keyword3",
  "marketingUrl": "https://yourwebsite.com",
  "supportUrl": "https://support.yourwebsite.com",
  "locale": "en"
}
```

All fields except `locale` are optional. The `locale` field should match the App Store Connect locale codes (e.g., `en`, `es`, `fr`, `zh-Hans`, `pt-BR`).

## API Methods

### `AppStoreConnectAPI` Class

- `find_app_by_bundle_id(bundle_id)` - Find an app by its bundle ID
- `find_app_by_name(app_name)` - Find an app by its name
- `get_app_store_versions(app_id)` - Get all App Store versions for an app
- `get_app_store_version_localizations(version_id)` - Get all localizations for a version
- `update_app_store_version_localization(localization_id, promotional_text, whats_new)` - Update promotional text and/or what's new

## Notes

- The JWT tokens automatically expire after 20 minutes and are regenerated as needed
- Both `promotional_text` and `whats_new` parameters are optional in the update method
- The script includes comprehensive error handling and will show detailed error messages
- Make sure your API key has the necessary permissions to modify app metadata

## Security

- Keep your `.p8` private key file secure and never commit it to version control
- Use environment variables or a `.env` file to store sensitive credentials
- Consider using a secrets management system in production environments

## Error Handling

The script will provide detailed error messages if:
- Required environment variables are missing
- The private key file cannot be found or read
- The app, version, or localization cannot be found
- API requests fail due to authentication or permission issues
