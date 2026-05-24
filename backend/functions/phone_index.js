/**
 * Phone Index Functions
 * 
 * Functions for managing the phoneIndex collection used for contact discovery.
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { normalizePhone, hashPhone } from "../lib/phone_utils.js";
import { requireAuth } from "../lib/auth_utils.js";

const db = getFirestore();

/**
 * Index a single user's phone (can be called manually if needed)
 */
export async function handleIndexUserPhone(request) {
    const callerUid = requireAuth(request, "index user phone");

    const userId = request.data.userId || callerUid;

    // Get user document
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
        throw new HttpsError("not-found", "User not found");
    }

    const userData = userDoc.data();
    const phoneNumber = userData.phoneNumber || userData.phone;

    if (!phoneNumber) {
        throw new HttpsError("failed-precondition", "User has no phone number");
    }

    const normalized = normalizePhone(phoneNumber);
    if (!normalized) {
        throw new HttpsError("invalid-argument", "Invalid phone number format");
    }

    const hash = hashPhone(normalized);

    await db.collection("phoneIndex").doc(hash).set({
        userId: userId,
        createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true, hash: hash };
}
