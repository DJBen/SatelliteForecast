# Support website

Static marketing, privacy and support site for Space Station Passes, served by
Firebase Hosting from the `pass-prediction` project on the `space-station-passes`
site: https://space-station-passes.web.app

| Path | Purpose |
| --- | --- |
| `/` | Overview with the live next-pass peek and the screenshot showcase |
| `/privacy` | Privacy policy; this is the App Store Connect privacy policy URL for every locale |
| `/support` | FAQ, contact and app details |
| `/api/orbital?category=25544` | Hosting rewrite to the `orbital_data` Cloud Function (same-origin, CORS `*`) |

## Deploy

```sh
cd Website
firebase deploy --only hosting --project pass-prediction
```

Only Hosting is deployed from this folder. Cloud Functions still deploy from
`pass-prediction/`. Bump the `?v=` query on the asset links in the HTML when
`assets/*.css` or `assets/*.js` change so browsers refetch them; images are cached
for a day.

## How the pieces work

- **Smart App Banner.** Every page carries
  `<meta name="apple-itunes-app" content="app-id=1578649430, app-argument=satelliteforecast://satellite">`.
  Safari on iOS draws Apple's banner from it. Other browsers get the site's own
  dismissable banner from `assets/site.js`, which hides itself when it detects
  Safari on iOS so the two never stack.
- **Live next-pass peek.** `assets/peek.js` fetches the two station TLEs through
  `/api/orbital`, propagates them with the vendored `satellite.js` 5.0.0, and lists
  passes that are above 10°, sunlit, and seen against a sky with the Sun below −6°.
  The observer is a city from the built-in list (defaulting to the visitor's time
  zone) or the browser geolocation after a tap; nothing is sent to the server.
- **Screenshots.** `img/` holds the en-US 2.0.0 store screenshots resized to 720 px
  wide. Refresh them from `Documentation/AppStore/<version>/screenshots/en-US` when
  the app's look changes.

## Contact address

The privacy and support pages publish the App Review contact email. Change it in
both `public/privacy/index.html` and `public/support/index.html` together.
