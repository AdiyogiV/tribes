/**
 * One-time cleanup script for stale globalFeed entries
 * 
 * Run with: node scripts/cleanup_global_feed.js
 * 
 * This removes entries from globalFeed that reference non-existent posts
 * or posts stuck in uploading state.
 */

import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase Admin (uses GOOGLE_APPLICATION_CREDENTIALS env var)
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = getFirestore();

async function cleanupGlobalFeed() {
    console.log('Starting globalFeed cleanup...');
    
    let deleted = 0;
    let checked = 0;
    let batchSize = 100;
    
    // Get all globalFeed entries
    const globalFeedRef = db.collection('globalFeed');
    let lastDoc = null;
    
    while (true) {
        let query = globalFeedRef.orderBy('timestamp', 'desc').limit(batchSize);
        
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }
        
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            break;
        }
        
        const batch = db.batch();
        let batchCount = 0;
        
        for (const doc of snapshot.docs) {
            checked++;
            const postId = doc.id;
            
            // Check if post exists and is complete
            const postDoc = await db.collection('posts').doc(postId).get();
            
            let shouldDelete = false;
            
            if (!postDoc.exists) {
                console.log(`  ❌ Post not found: ${postId}`);
                shouldDelete = true;
            } else {
                const postData = postDoc.data();
                if (postData?.uploading === true) {
                    // Check if stuck (>1 hour old)
                    const timestamp = postData.timestamp?.toDate?.() || new Date(0);
                    const ageHours = (Date.now() - timestamp.getTime()) / (1000 * 60 * 60);
                    
                    if (ageHours > 1) {
                        console.log(`  ⏳ Stuck upload (${ageHours.toFixed(1)}h): ${postId}`);
                        shouldDelete = true;
                    }
                }
            }
            
            if (shouldDelete) {
                batch.delete(doc.ref);
                batchCount++;
                deleted++;
            }
        }
        
        if (batchCount > 0) {
            await batch.commit();
            console.log(`  Committed batch: ${batchCount} deletions`);
        }
        
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        console.log(`  Progress: ${checked} checked, ${deleted} deleted`);
    }
    
    console.log('\n✅ Cleanup complete!');
    console.log(`   Total checked: ${checked}`);
    console.log(`   Total deleted: ${deleted}`);
}

// Run cleanup
cleanupGlobalFeed()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('Cleanup failed:', error);
        process.exit(1);
    });
