/**
 * One-time cleanup script for stale VoIP tokens.
 *
 * Run with: node scripts/cleanup_voip_tokens.js
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to be set.
 */

import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = getFirestore();

async function cleanupVoipTokens() {
  console.log('Starting VoIP token cleanup...');

  let updated = 0;
  let checked = 0;
  const batchSize = 200;
  let lastDoc = null;

  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(batchSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let batchUpdates = 0;

    for (const doc of snapshot.docs) {
      checked++;
      const data = doc.data();
      if (data && Object.prototype.hasOwnProperty.call(data, 'voipToken')) {
        batch.update(doc.ref, { voipToken: admin.firestore.FieldValue.delete() });
        batchUpdates++;
        updated++;
      }
    }

    if (batchUpdates > 0) {
      await batch.commit();
      console.log(`Committed batch: ${batchUpdates} updates`);
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Progress: ${checked} checked, ${updated} updated`);
  }

  console.log('✅ VoIP token cleanup complete');
  console.log(`Total checked: ${checked}`);
  console.log(`Total updated: ${updated}`);
}

cleanupVoipTokens()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Cleanup failed:', error);
    process.exit(1);
  });
