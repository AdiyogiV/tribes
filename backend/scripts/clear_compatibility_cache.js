// One-time script to clear compatibility cache
// Run with: node scripts/clear_compatibility_cache.js

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
  readFileSync('./serviceAccountKey.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function clearCompatibilityCache() {
  console.log('🗑️  Clearing compatibility cache...');
  
  const cacheRef = db.collection('compatibilityScores');
  const snapshot = await cacheRef.get();
  
  if (snapshot.empty) {
    console.log('✅ Cache is already empty');
    return;
  }
  
  console.log(`Found ${snapshot.size} cached compatibility scores`);
  
  // Delete in batches of 500 (Firestore limit)
  const batchSize = 500;
  let deleted = 0;
  
  while (true) {
    const batch = db.batch();
    const docs = await cacheRef.limit(batchSize).get();
    
    if (docs.empty) break;
    
    docs.forEach(doc => {
      batch.delete(doc.ref);
      deleted++;
    });
    
    await batch.commit();
    console.log(`Deleted ${deleted} documents...`);
  }
  
  console.log(`✅ Successfully deleted ${deleted} cached compatibility scores`);
  console.log('New scores will be calculated with the v3 8-pillar system');
}

clearCompatibilityCache()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });

