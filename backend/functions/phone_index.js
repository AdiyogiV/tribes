/**
 * Phone Index Functions
 * 
 * Functions for managing the phoneIndex collection used for contact discovery.
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { normalizePhone, normalizePhoneMultiple, hashPhone } from "../lib/phone_utils.js";
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

/**
 * Check whether a phone number already belongs to a Firebase Auth account.
 *
 * The web login flow needs this BEFORE consuming the SMS code so it can decide
 * between LINKing the phone to the current anonymous guest (new number → keep
 * their guest data) and plain sign-in (existing number → sign into that
 * account). On web, a failed link throws `credential-already-in-use` with a
 * null credential, leaving no way to recover — so we must branch up front
 * rather than link-and-recover the way native does.
 *
 * Auth-gated (callers are already anonymous guests) to limit enumeration.
 * Returns only a boolean — never any account detail.
 *
 * @param {Object} request - onCall request: { phone: "<E.164 or local>" }
 * @returns {{exists: boolean}}
 */
export async function handleCheckPhoneExists(request) {
    requireAuth(request, "check phone");

    const rawPhone = request.data?.phone;
    if (!rawPhone || typeof rawPhone !== "string") {
        throw new HttpsError("invalid-argument", "phone is required");
    }

    // Firebase Auth stores numbers in E.164; try each normalized variant so a
    // number saved as "+91…" still matches a "…" client input and vice-versa.
    const variants = normalizePhoneMultiple(rawPhone);
    if (variants.length === 0) {
        throw new HttpsError("invalid-argument", "Invalid phone number format");
    }

    const auth = getAuth();
    for (const candidate of variants) {
        try {
            await auth.getUserByPhoneNumber(candidate);
            return { exists: true };
        } catch (e) {
            if (e.code === "auth/user-not-found") continue;
            // Any other error (e.g. malformed candidate) — skip this variant.
            if (e.code === "auth/invalid-phone-number") continue;
            throw new HttpsError("internal", "phone check failed");
        }
    }

    return { exists: false };
}
