import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendPush(
  token: string | undefined,
  payload: PushPayload
): Promise<void> {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (err) {
    // Invalid/expired tokens are expected churn — log and move on.
    logger.warn("FCM send failed", { error: String(err) });
  }
}

export async function sendPushMulti(
  tokens: string[],
  payload: PushPayload
): Promise<void> {
  const valid = tokens.filter(Boolean);
  if (valid.length === 0) return;
  try {
    await getMessaging().sendEachForMulticast({
      tokens: valid,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (err) {
    logger.warn("FCM multicast failed", { error: String(err) });
  }
}
