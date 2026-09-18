# Architecture

1. iOS client gets `{pushToken}` with Google Cloud Messaging.
2. iOS client updates the location with `{pushToken}` and insert into Firebase
```
users/{pushToken}
```
```
Fields: lat,lon,alt,geoHash5
```

3. Cloud function `@on_document_write` reacts to `users/{pushToken}` and triggers computing transit, and store transit info into Firebase.

```
transits/{satId_geoHash5}
Fields: last_scan_time
Subcollection: records
```

4. A scheduled Cloud Run job fetches all push token that has transits with the same geoHash5, which will occur in the next 24 hours. 
  a. Schedules the notification into task queue.
  b. Writes the scheduled notification to for record keeping.

5. The scheduled job will call `/notify` endpoint with the transit information, which will send the push notification payload.