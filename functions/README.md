# IncreMat scheduled health-check functions

`dailyHealthCheck` runs once a day and pushes a reminder to a senior's
caregivers when:

- their **sit-to-stand pace declines** (same thresholds as `analyseMobility()`
  in `lib/providers/mobility_alert_provider.dart` — keep the two in sync), or
- a **monthly chair-stand retest is due**.

This delivers the safety alerts even when the caregiver app is closed; the
in-app watcher only runs while the app is open.

## Requirements
- Firebase **Blaze** plan (scheduled functions + FCM).
- The caregiver app stores each device's FCM token under
  `caregiver_access/{caregiverId}.fcmTokens` (done by `PushService`).

## Deploy
```bash
cd functions
npm install
npm run deploy      # firebase deploy --only functions
```

## Notes
- Dedup markers are written back to each senior doc
  (`lastDeclineSig`, `lastChairStandReminderSig`) so an event notifies once.
- This was authored but **not deployed or run** from the app sandbox — verify in
  the Firebase emulator (`npm run serve`) before shipping.
