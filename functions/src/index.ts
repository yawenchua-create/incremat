/**
 * Scheduled health-check push notifications for the IncreMat caregiver app.
 *
 * Runs once a day, evaluates each senior for a sit-to-stand decline or a due
 * monthly chair-stand retest, and pushes a reminder to their caregivers — so
 * the alert lands even when the caregiver app is closed (the in-app watcher
 * only runs while the app is open).
 *
 * NOTE: the decline thresholds here MUST mirror analyseMobility() in
 * lib/providers/mobility_alert_provider.dart. Keep the two in sync, or move
 * both to a shared contract.
 *
 * Deploy: `npm install && npm run deploy` (needs the Blaze plan + FCM).
 */
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

const DAY_RATIO = 1.3;
const DAY_ABSOLUTE = 3.0;
const WEEK_RATIO = 1.15;
const RETEST_DAYS = 30;
const WINDOW_DAYS = 28;

interface Session {
  timestamp: number;
  firstFiveRepsSeconds: number;
}

interface Decline {
  kind: "day" | "week";
  pct: number;
  sig: string;
}

const dayKey = (ms: number): string => {
  const d = new Date(ms);
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
};

const median = (v: number[]): number => {
  if (v.length === 0) return 0;
  const s = [...v].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

const mean = (v: number[]): number =>
  v.length === 0 ? 0 : v.reduce((a, b) => a + b, 0) / v.length;

/** Best (fastest) 5-rep time per active day. */
function bestPerDay(sessions: Session[]): Map<string, {secs: number; ms: number}> {
  const map = new Map<string, {secs: number; ms: number}>();
  for (const s of sessions) {
    if (!s.firstFiveRepsSeconds || s.firstFiveRepsSeconds <= 0) continue;
    const key = dayKey(s.timestamp);
    const cur = map.get(key);
    if (!cur || s.firstFiveRepsSeconds < cur.secs) {
      map.set(key, {secs: s.firstFiveRepsSeconds, ms: s.timestamp});
    }
  }
  return map;
}

/** Mirrors analyseMobility() in the Dart app. */
function analyseMobility(sessions: Session[], now: number): Decline | null {
  const perDay = bestPerDay(sessions);
  if (perDay.size < 2) return null;

  const days = [...perDay.entries()].sort((a, b) => a[1].ms - b[1].ms);

  // Day-over-day sudden drop.
  const [latestKey, latest] = days[days.length - 1];
  const prior = days.slice(0, days.length - 1);
  if (prior.length >= 3) {
    const recent = prior.slice(Math.max(0, prior.length - 7)).map((e) => e[1].secs);
    const baseline = median(recent);
    if (
      baseline > 0 &&
      latest.secs >= baseline * DAY_RATIO &&
      latest.secs - baseline >= DAY_ABSOLUTE
    ) {
      return {
        kind: "day",
        pct: Math.round((latest.secs / baseline - 1) * 100),
        sig: `decline-day|${latestKey}`,
      };
    }
  }

  // Week-over-week decline.
  const weekAgo = now - 7 * 86400000;
  const twoWeeksAgo = now - 14 * 86400000;
  const thisWeek: number[] = [];
  const lastWeek: number[] = [];
  for (const [, v] of days) {
    if (v.ms >= weekAgo) thisWeek.push(v.secs);
    else if (v.ms >= twoWeeksAgo) lastWeek.push(v.secs);
  }
  if (thisWeek.length >= 2 && lastWeek.length >= 2) {
    const thisAvg = mean(thisWeek);
    const lastAvg = mean(lastWeek);
    if (lastAvg > 0 && thisAvg >= lastAvg * WEEK_RATIO) {
      const monday = new Date(now);
      monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
      return {
        kind: "week",
        pct: Math.round((thisAvg / lastAvg - 1) * 100),
        sig: `decline-week|${dayKey(monday.getTime())}`,
      };
    }
  }
  return null;
}

/** FCM tokens of every caregiver linked to this senior. */
async function tokensForSenior(seniorId: string): Promise<string[]> {
  const snap = await db
    .collection("caregiver_access")
    .where("seniorIds", "array-contains", seniorId)
    .get();
  const tokens = new Set<string>();
  for (const doc of snap.docs) {
    for (const t of (doc.data().fcmTokens as string[]) ?? []) tokens.add(t);
  }
  return [...tokens];
}

async function notify(
  seniorId: string,
  seniorRef: FirebaseFirestore.DocumentReference,
  field: string,
  sig: string,
  title: string,
  body: string,
  alreadySent: string | undefined
): Promise<void> {
  if (alreadySent === sig) return; // deduped: already pushed for this event
  const tokens = await tokensForSenior(seniorId);
  if (tokens.length > 0) {
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
    });
  }
  await seniorRef.update({[field]: sig});
}

export const dailyHealthCheck = onSchedule(
  {schedule: "every day 09:00", timeZone: "Asia/Singapore"},
  async () => {
    const now = Date.now();
    const since = now - WINDOW_DAYS * 86400000;
    const seniors = await db.collection("seniors").get();

    for (const doc of seniors.docs) {
      const senior = doc.data();
      const seniorId = doc.id;
      const name = (senior.name as string) || "Your loved one";

      // 1. Sit-to-stand decline.
      const sessionsSnap = await doc.ref
        .collection("sessions")
        .where("timestamp", ">=", since)
        .get();
      const sessions: Session[] = sessionsSnap.docs.map((s) => ({
        timestamp: (s.data().timestamp as number) ?? 0,
        firstFiveRepsSeconds: (s.data().firstFiveRepsSeconds as number) ?? 0,
      }));
      const decline = analyseMobility(sessions, now);
      if (decline) {
        const body =
          decline.kind === "day"
            ? `${name}'s sit-to-stand was ${decline.pct}% slower than usual today. It may be worth checking in on them.`
            : `${name}'s sit-to-stand has slowed ${decline.pct}% this week. It may be worth checking in on them.`;
        await notify(
          seniorId,
          doc.ref,
          "lastDeclineSig",
          decline.sig,
          "Mobility check-in",
          body,
          senior.lastDeclineSig as string | undefined
        );
      }

      // 2. Monthly chair-stand retest due (only for already-tested seniors).
      const testedAt = senior.chairStandTestAt as number | undefined;
      if (testedAt && now - testedAt >= RETEST_DAYS * 86400000) {
        await notify(
          seniorId,
          doc.ref,
          "lastChairStandReminderSig",
          `cs|${testedAt}`,
          "Fitness check due",
          `It's time for ${name}'s monthly chair stand test.`,
          senior.lastChairStandReminderSig as string | undefined
        );
      }
    }
  }
);
