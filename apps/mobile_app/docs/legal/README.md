# Google Docs — Legal & Help Setup

Upload these files to Google Docs, then paste the document IDs into `lib/config/app_config.dart`.

## Documents to create

| Doc | Source file | AppConfig constant |
|-----|-------------|-------------------|
| Privacy Policy (EN) | `privacy-policy-en.md` | `privacyUrl` |
| Terms of Service (EN) | `terms-of-service-en.md` | `termsUrl` |
| Help Center (EN) | `help-center-en.md` | `helpUrl` |
| Privacy (TR, optional) | `privacy-policy-tr.md` | — or separate TR listing |

**Play Store requires a privacy policy URL** — use the English privacy doc for the store listing.

## Steps

1. Go to [Google Docs](https://docs.google.com) → **Blank document**
2. Copy all text from the `.md` file and paste into the doc
3. Format headings if you want (optional)
4. **Share** (top right):
   - General access → **Anyone with the link** → **Viewer**
5. Copy the link. Example:
   ```
   https://docs.google.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890/edit
   ```
6. Take the ID between `/d/` and `/edit`:
   ```
   1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890
   ```
7. Put it in `app_config.dart`:
   ```dart
   static const privacyUrl =
       'https://docs.google.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890/view';
   ```
   Use `/view` at the end (not `/edit`) — opens read-only in the browser.

## Optional: Publish to web

For a cleaner mobile view (no Google toolbar):

1. **File → Share → Publish to web**
2. Choose **Link** → **Publish**
3. Use the `/pub` URL Google gives you instead of `/view`

Example:
```
https://docs.google.com/document/d/e/2PACX-1vXXXXXXXX/pub
```

## Support email

All docs use: **support@hun.social**

Create this inbox or replace with your real email in:
- All `.md` files in this folder
- `AppConfig.supportEmail`

## Play Console fields

| Field | Value |
|-------|--------|
| Privacy policy | `https://hun.social/privacy` |
| Website | `https://hun.social` |
| Terms of service | `https://hun.social/terms` |
| Contact email | `support@hun.social` |
