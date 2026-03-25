import { z } from "zod";
import { HttpsError } from "firebase-functions/v2/https";

// =============================================================================
// CORE ENTITY SCHEMAS
// =============================================================================

export const UserSchema = z.object({
    name: z.string().min(1),
    displayPicture: z.string().optional(),
    fcmToken: z.string().optional(), // Legacy single token (for backward compatibility)
    fcmTokens: z.array(z.string()).optional(), // Multi-device support: array of device tokens
});

export const PostSchema = z.object({
    author: z.string().min(1),
    thumbnail: z.string().optional(),
    space: z.string().min(1),
    replyTo: z.string().optional(),
});

export const SpaceSchema = z.object({
    spaceType: z.number(),
    limitedVisibility: z.boolean().optional(),
});

// =============================================================================
// API REQUEST SCHEMAS
// =============================================================================

/**
 * Schema for astrology calculation requests
 */
export const AstroCalculationRequestSchema = z.object({
    birthDate: z.string().min(1, "Birth date is required"),
    birthTime: z.string().min(1, "Birth time is required"),
    birthPlace: z.string().min(1, "Birth place is required"),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    timezone: z.number().min(-12).max(14),
});

/**
 * Schema for compatibility calculation requests
 */
export const CompatibilityRequestSchema = z.object({
    targetUserId: z.string().min(1, "Target user ID is required"),
});

/**
 * Schema for contact matching requests
 */
export const ContactSchema = z.object({
    phoneNumbers: z.array(z.string()).optional(),
    name: z.string().optional(),
});

export const ContactMatchRequestSchema = z.object({
    contacts: z.array(ContactSchema).max(1000, "Maximum 1000 contacts allowed"),
});

/**
 * Schema for namaste (greeting) requests
 */
export const NamasteRequestSchema = z.object({
    recipientId: z.string().min(1, "Recipient ID is required"),
    message: z.string().max(500, "Message must be 500 characters or less").optional(),
});

/**
 * Schema for chat message requests
 */
export const ChatMessageRequestSchema = z.object({
    spaceId: z.string().min(1, "Space ID is required"),
    content: z.string().min(1, "Message content is required").max(10000, "Message too long"),
    type: z.enum(["text", "audio", "image"]).default("text"),
    replyToId: z.string().optional(),
});

/**
 * Schema for Agora token generation
 */
export const AgoraTokenRequestSchema = z.object({
    channelName: z.string().min(1, "Channel name is required"),
    uid: z.number().int().nonnegative("UID must be a non-negative integer"),
});

/**
 * Schema for notification requests
 */
export const NotificationRequestSchema = z.object({
    userId: z.string().min(1, "User ID is required"),
    title: z.string().min(1).max(100),
    body: z.string().min(1).max(500),
    type: z.string().min(1),
    data: z.record(z.string()).optional(),
});

/**
 * Schema for astro sync requests
 */
export const AstroSyncRequestSchema = z.object({
    birthDate: z.string().min(1),
    birthTime: z.string().min(1),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    timezone: z.number().min(-12).max(14),
    placeName: z.string().optional(),
});

/**
 * Schema for geo location search
 */
export const GeoSearchRequestSchema = z.object({
    query: z.string().min(1, "Search query is required").max(200),
});

// =============================================================================
// VALIDATION HELPERS
// =============================================================================

/**
 * Validate request data against a schema
 * Throws HttpsError if validation fails
 * 
 * @param {z.ZodSchema} schema - Zod schema to validate against
 * @param {unknown} data - Data to validate
 * @param {string} functionName - Name of the function (for error messages)
 * @returns {T} Validated and typed data
 * @throws {HttpsError} If validation fails
 */
export function validateRequest(schema, data, functionName = "function") {
    const result = schema.safeParse(data);
    
    if (!result.success) {
        const errors = result.error.errors.map(e => {
            const path = e.path.length > 0 ? `${e.path.join(".")}: ` : "";
            return `${path}${e.message}`;
        });
        
        throw new HttpsError(
            "invalid-argument",
            `Validation failed in ${functionName}: ${errors.join(", ")}`
        );
    }
    
    return result.data;
}

/**
 * Validate request data and return result object (non-throwing)
 * 
 * @param {z.ZodSchema} schema - Zod schema to validate against
 * @param {unknown} data - Data to validate
 * @returns {{ success: boolean, data?: T, errors?: string[] }}
 */
export function safeValidateRequest(schema, data) {
    const result = schema.safeParse(data);
    
    if (!result.success) {
        const errors = result.error.errors.map(e => {
            const path = e.path.length > 0 ? `${e.path.join(".")}: ` : "";
            return `${path}${e.message}`;
        });
        
        return { success: false, errors };
    }
    
    return { success: true, data: result.data };
}

/**
 * Create a partial schema (all fields optional)
 * Useful for update operations
 * 
 * @param {z.ZodSchema} schema - Base schema
 * @returns {z.ZodSchema} Partial schema
 */
export function createPartialSchema(schema) {
    return schema.partial();
}

// =============================================================================
// CUSTOM VALIDATORS
// =============================================================================

/**
 * Phone number validator (E.164 format)
 */
export const phoneNumberSchema = z.string().regex(
    /^\+?[1-9]\d{1,14}$/,
    "Invalid phone number format"
);

/**
 * Firebase UID validator
 */
export const firebaseUidSchema = z.string()
    .min(1)
    .max(128)
    .regex(/^[a-zA-Z0-9_-]+$/, "Invalid Firebase UID format");

/**
 * ISO date string validator
 */
export const isoDateSchema = z.string().refine(
    (val) => !isNaN(Date.parse(val)),
    "Invalid date format"
);

/**
 * Coordinates validator
 */
export const coordinatesSchema = z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
});


