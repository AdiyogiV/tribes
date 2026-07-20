/**
 * Cosmic Avatar — generate a mythic-playful celestial portrait for a user,
 * seeded by their janma nakshatra + gender.
 *
 * Mirrors first_reading.js end-to-end: build prompt -> call model -> store.
 * Difference: the model is Imagen (Vertex image gen), and the output is a PNG
 * uploaded to Storage. The download URL is cached PERMANENTLY on
 * users/{uid}.astrologyData.cosmicAvatar (birth data + nakshatra are stable,
 * so this is a one-time "fated birth" — never regenerated unless force=true).
 *
 * This is a FALLBACK avatar: the client shows it only when the user has no real
 * displayPicture. It never overwrites an uploaded photo.
 *
 * Auth: uses the function's service-account ADC (no API key). The image call
 * hits us-central1 aiplatform (Imagen's most reliable region) from inside the
 * VPC-SC perimeter, same as the existing Gemini text calls.
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { GoogleAuth } from "google-auth-library";
import { randomUUID } from "node:crypto";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";

const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || "ty-dev-516d7";
const IMAGEN_LOCATION = "us-central1"; // Imagen's broadest, most reliable region
const IMAGEN_MODEL = "imagen-3.0-generate-002";
const STORAGE_BUCKET = "ty-dev-516d7.appspot.com";

const auth = new GoogleAuth({
    scopes: "https://www.googleapis.com/auth/cloud-platform",
});

// ── The locked mythic-playful "house style". Shared across all 27 nakshatras ──
// so the whole cast reads as one coherent pantheon, not random AI art.
const HOUSE_STYLE =
    "Mythic-playful collectible character portrait, digital illustration in a warm " +
    "semi-stylized painterly style with clean shapes and soft cosmic rim-light. " +
    "Centered head-and-shoulders bust of a single friendly celestial being with big " +
    "soulful expressive eyes and an appealing, approachable face. Deep night-sky " +
    "starfield gradient background with a subtle nebula glow. Cohesive companion-avatar " +
    "aesthetic, polished and highly detailed. No text, no watermark, no logo. " +
    "Single character, one head, symmetrical friendly face.";

// ── Per-nakshatra visual archetype (short flavour, drives the character) ──
const NAKSHATRA_ARCHETYPE = {
    "Ashwini": "swift healer energy of the twin horse-riders, a subtle winged-horse motif, restless bright eyes, dawn-gold and turquoise palette, sparks of fresh-start light; youthful, quick, adventurous",
    "Bharani": "creative intensity of the life-bearer, a soft ember-and-lotus motif, deep crimson and black palette, an aura of transformation; passionate, magnetic, resolute",
    "Krittika": "sharp purifying fire of the flame-blade, golden solar sparks, red-gold palette, a determined gaze; bold, honest, radiant",
    "Rohini": "the Moon's beloved, gentle radiant beauty and creative warmth, blossoming lotus and ox-cart motifs, pearl-and-rose palette with soft silver moonlight; graceful, magnetic, calm",
    "Mrigashira": "gentle seeker energy of the deer, soft antler-light motif, silver-green palette, curious searching eyes; tender, curious, restless",
    "Ardra": "storm-child of the teardrop, subtle raincloud and lightning motif, stormy emerald and violet palette, intense feeling eyes; emotional, brilliant, transformative",
    "Punarvasu": "renewal light of the return, a quiver-of-arrows and rainbow motif, fresh sky-blue and gold palette, an optimistic serene face; wise, hopeful, nurturing",
    "Pushya": "cosmic nourisher, a lotus-and-cow's-udder abundance motif, warm saffron and cream palette, a caring protective aura; gentle, grounded, devoted",
    "Ashlesha": "clever serpent energy, subtle coiled-snake and hypnotic-eye motif, deep teal and iridescent palette, a knowing mysterious gaze; intuitive, sharp, magnetic",
    "Magha": "regal ancestral power, a throne and lion motif, royal maroon and antique gold palette, a proud noble face; commanding, dignified, honoring",
    "Purva Phalguni": "playful creative fortune, a hammock-and-blossom motif, rose and honey palette, a warm flirtatious smile; charming, artistic, generous",
    "Uttara Phalguni": "generous benefactor, a bed-of-rest and helping-hand motif, amber and cream palette, a kind steady face; reliable, warm, prosperous",
    "Hasta": "skillful craftsman of the hand, a glowing open-palm motif, jade-green and gold palette, clever bright eyes; deft, witty, resourceful",
    "Chitra": "brilliant artisan of the pearl, a shimmering gem and architecture motif, opalescent multicolor palette, a dazzling visionary gaze; creative, striking, precise",
    "Swati": "independent wind-spirit, a young reed bending in breeze and coral motif, teal and pale-gold palette, a free balanced face; adaptable, self-driven, graceful",
    "Vishakha": "purposeful achiever of the forked branch, a triumphal arch and twin-star motif, crimson and gold palette, a focused ambitious gaze; determined, goal-driven, bright",
    "Anuradha": "devoted friend of the lotus, a blooming-lotus-in-water motif, deep blue and rose-gold palette, a warm loyal face; friendly, disciplined, magnetic",
    "Jyeshtha": "protective elder chief, a talisman-and-umbrella motif, deep red and bronze palette, a wise senior gaze; guarding, sharp, dignified",
    "Mula": "root-seeker of the tied bundle, a bundle-of-roots and lion's-tail motif, dark earth and gold palette, a piercing investigative gaze; deep, intense, truth-seeking",
    "Purva Ashadha": "invincible optimist of the fan, a water-fan and elephant-tusk motif, blue and gold palette, an unshakable confident smile; buoyant, purifying, bold",
    "Uttara Ashadha": "universal victor of the tusk, an elephant and sunrise motif, gold and ivory palette, a principled noble face; righteous, steady, enduring",
    "Shravana": "listening sage of the three-footprints, a conch and ear-of-listening motif, silver-blue and cream palette, an attentive wise gaze; connected, learned, calm",
    "Dhanishtha": "musical star of the drum, a cosmic drum and flute motif, jewel-tone and silver palette, a rhythmic joyful face; talented, adaptable, abundant",
    "Shatabhisha": "hundred-healer of the empty circle, a ring-of-stars and medicine motif, electric-teal and deep-indigo palette, a mysterious independent gaze; healing, secretive, visionary",
    "Purva Bhadrapada": "quiet fiery idealism and a mystic's intensity, a subtle lion-mane silhouette, twin softly-glowing flames at the shoulders symbolising a dual nature, warm gold and silver-grey palette, a faint halo of transformation embers; serene, visionary, otherworldly",
    "Uttara Bhadrapada": "deep serene warrior of the still waters, a coiled cosmic-serpent-in-the-deep motif, midnight-blue and gold palette, a wise controlled gaze; profound, patient, kind",
    "Revati": "compassionate guide of the fish, a pair-of-fish and guiding-star motif, sea-green and pearl palette, a nurturing gentle face; kind, prosperous, protective",
};

const GENDER_DESC = {
    "Male": "depicted as a young man",
    "Female": "depicted as a young woman",
    "Other": "depicted as an androgynous celestial youth",
    "male": "depicted as a young man",
    "female": "depicted as a young woman",
    "other": "depicted as an androgynous celestial youth",
};

/** Build the Imagen prompt from nakshatra + gender. */
export function buildAvatarPrompt(nakshatra, gender) {
    const flavour =
        NAKSHATRA_ARCHETYPE[nakshatra] ||
        `embodies the ${nakshatra} nakshatra, cosmic and archetypal`;
    const who = GENDER_DESC[gender] || GENDER_DESC["Other"];
    return `A celestial companion ${who}, who embodies ${nakshatra}: ${flavour}. ${HOUSE_STYLE}`;
}

/** Call Imagen via the Vertex REST predict endpoint. Returns a PNG Buffer. */
async function callImagen(prompt) {
    const client = await auth.getClient();
    const { token } = await client.getAccessToken();
    const url =
        `https://${IMAGEN_LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT}` +
        `/locations/${IMAGEN_LOCATION}/publishers/google/models/${IMAGEN_MODEL}:predict`;

    const body = {
        instances: [{ prompt }],
        parameters: {
            sampleCount: 1,
            aspectRatio: "1:1",
            personGeneration: "allow_adult",
            safetySetting: "block_only_high",
        },
    };

    const res = await fetch(url, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${token}`,
            "Content-Type": "application/json; charset=utf-8",
        },
        body: JSON.stringify(body),
    });

    if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Imagen ${res.status}: ${errText.slice(0, 400)}`);
    }

    const data = await res.json();
    const b64 = data?.predictions?.[0]?.bytesBase64Encoded;
    if (!b64) {
        throw new Error("Imagen returned no image bytes (possibly safety-blocked)");
    }
    return Buffer.from(b64, "base64");
}

/**
 * Core: generate + store a cosmic avatar. Returns the public download URL.
 * Exported so astro_sync can call it during the onboarding reveal later.
 */
export async function generateCosmicAvatar(uid, gender, astroData) {
    const nakshatra = astroData.nakshatra || astroData.moonNakshatra;
    if (!nakshatra) {
        throw new Error("No nakshatra available to seed the cosmic avatar");
    }

    const prompt = buildAvatarPrompt(nakshatra, gender);
    logger.info("Generating cosmic avatar", { uid, nakshatra, gender });

    const png = await callImagen(prompt);

    // Upload to Storage with a Firebase download token so the URL is public-read.
    const bucket = getStorage().bucket(STORAGE_BUCKET);
    const path = `cosmic_avatars/${uid}.png`;
    const downloadToken = randomUUID();
    await bucket.file(path).save(png, {
        resumable: false,
        metadata: {
            contentType: "image/png",
            metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
    });

    const url =
        `https://firebasestorage.googleapis.com/v0/b/${STORAGE_BUCKET}/o/` +
        `${encodeURIComponent(path)}?alt=media&token=${downloadToken}`;

    await db.collection("users").doc(uid).update({
        "astrologyData.cosmicAvatar": {
            url,
            nakshatra,
            gender: gender || null,
            prompt,
            generatedAt: FieldValue.serverTimestamp(),
            version: 1,
        },
    });

    logger.info("Cosmic avatar stored", { uid, nakshatra, bytes: png.length });
    return url;
}

/**
 * onCall handler (via insightGateway `generateCosmicAvatar`): generate the
 * avatar (or return the permanent cached one). Pass { force: true } to re-roll.
 */
export async function handleGenerateCosmicAvatar(request) {
    const uid = requireAuth(request, "generate cosmic avatar");
    const force = request.data?.force === true;
    const startTime = Date.now();
    logger.info("generateCosmicAvatar invoked", { uid, force });

    try {
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found");

        const userData = userSnap.data();
        const astroData = userData.astrologyData;
        if (!astroData) {
            return { success: false, error: "No astrology data found", data: null };
        }

        // Fast path — avatar already exists (permanent, one fated birth).
        if (!force && astroData.cosmicAvatar?.url) {
            logger.info("Cosmic avatar cache hit", { uid, latency: Date.now() - startTime });
            return {
                success: true,
                alreadyExists: true,
                data: { url: astroData.cosmicAvatar.url, nakshatra: astroData.cosmicAvatar.nakshatra },
            };
        }

        const nakshatra = astroData.nakshatra || astroData.moonNakshatra;
        if (!nakshatra) {
            return { success: false, error: "Astro data not ready (no nakshatra yet)", data: null };
        }

        const gender = astroData.gender || userData.gender || "Other";
        const url = await generateCosmicAvatar(uid, gender, astroData);

        logger.info("Cosmic avatar complete", { uid, latency: Date.now() - startTime });
        return { success: true, alreadyExists: false, data: { url, nakshatra } };
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("Cosmic avatar failed", {
            uid,
            error: error.message,
            stack: error.stack?.substring(0, 300),
            latency: Date.now() - startTime,
        });
        return { success: false, error: error.message, data: null };
    }
}
