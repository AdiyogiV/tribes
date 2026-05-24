/**
 * Agora RTC Token Generation for Group Calls
 */

import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "../lib/firebase.js";
import { agoraAppCertificate, agoraAppId } from "../lib/secrets.js";
import pkg from 'agora-token';
const { RtcTokenBuilder, RtcRole } = pkg;

// Token validity: 1 hour (configurable via config.js if needed)
const TOKEN_EXPIRY_SECONDS = 3600;

/**
 * Generate an Agora RTC token for group calls
 * 
 * SECURITY: App Certificate is stored in Firebase Secrets
 * To set it: firebase functions:secrets:set AGORA_APP_CERTIFICATE
 */
/** Handler: Generate Agora RTC token. Extracted for gateway reuse. */
export async function handleGenerateAgoraToken(request) {
  // Log auth state for debugging
  logger.info('generateAgoraToken called', { 
    hasAuth: !!request.auth,
    authUid: request.auth?.uid || 'none',
    rawRequest: !!request.rawRequest,
  });

  // NOTE: On web, request.auth can be null even for authenticated users due to
  // Firebase Functions v2 auth context issues. For development, we allow this
  // but log a warning. In production, you may want to implement custom token
  // verification or use a different authentication method.
  if (!request.auth) {
    logger.warn('No auth context in request - proceeding anyway for web compatibility');
    // In production, uncomment the following to require auth:
    // throw new HttpsError('unauthenticated', 'User must be authenticated to generate token');
  }

  const { channelName, uid } = request.data;

  // Validate inputs
  if (!channelName || typeof channelName !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'Channel name is required and must be a string'
    );
  }

  if (uid === undefined || typeof uid !== 'number') {
    throw new HttpsError(
      'invalid-argument',
      'User ID is required and must be a number'
    );
  }

  try {
    // Get the App Certificate from Firebase Secrets
    // Note: Ensure the secret has no trailing newlines (use echo -n when setting)
    const appCertificate = agoraAppCertificate.value()?.trim();
    
    if (!appCertificate || appCertificate.length !== 32) {
      logger.error('AGORA_APP_CERTIFICATE secret is invalid', {
        length: appCertificate?.length || 0,
        expected: 32,
      });
      throw new HttpsError(
        'failed-precondition',
        'Agora credentials not configured correctly. Please contact support.'
      );
    }

    // Calculate expiry timestamp
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + TOKEN_EXPIRY_SECONDS;

    // Generate token with publisher role
    const appId = agoraAppId.value();
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs
    );

    if (!token) {
      logger.error('RtcTokenBuilder returned empty token');
      throw new HttpsError('internal', 'Token generation failed');
    }

    logger.info(`Generated Agora token for channel ${channelName}`, {
      uid,
      tokenLength: token.length,
    });

    return { token };
  } catch (error) {
    logger.error('Error generating Agora token:', error);
    throw new HttpsError(
      'internal',
      'Failed to generate Agora token: ' + error.message
    );
  }
}
