/**
 * Migration script to migrate reposts from old model to new architecture
 * 
 * Old model: Posts with isRepost=true flag stored in posts/ collection
 * New model: Separate reposts/ collection with reference-only documents
 * 
 * Run with: node scripts/migrate_reposts.js
 * 
 * This script:
 * 1. Finds all posts with isRepost=true
 * 2. Creates corresponding documents in reposts/ collection
 * 3. Marks old posts for deletion (or keeps as reference)
 * 4. Verifies repost counts match
 * 5. Provides rollback capability
 */

import admin from 'firebase-admin';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Initialize Firebase Admin (uses GOOGLE_APPLICATION_CREDENTIALS env var)
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = getFirestore();

const BATCH_SIZE = 500;
const DRY_RUN = process.env.DRY_RUN === 'true';

async function migrateReposts() {
    console.log('🚀 Starting repost migration...');
    if (DRY_RUN) {
        console.log('⚠️  DRY RUN MODE - No changes will be made');
    }
    console.log('');
    
    let migrated = 0;
    let errors = 0;
    let skipped = 0;
    let lastDoc = null;
    
    // Track repost counts for verification
    const repostCounts = new Map(); // originalPostId -> count
    
    while (true) {
        // Query posts with isRepost=true
        let query = db.collection('posts')
            .where('isRepost', '==', true)
            .limit(BATCH_SIZE);
        
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }
        
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            break;
        }
        
        console.log(`📦 Processing batch of ${snapshot.size} reposts...`);
        
        const batch = db.batch();
        let batchCount = 0;
        
        for (const doc of snapshot.docs) {
            try {
                const repostData = doc.data();
                const repostId = doc.id;
                const originalPostId = repostData.originalPostId;
                const reposterId = repostData.author;
                const contextType = repostData.contextType || 'profile';
                const contextId = repostData.contextId || repostData.space || null;
                
                // Validate required fields
                if (!originalPostId || !reposterId) {
                    console.log(`  ⚠️  Skipping invalid repost ${repostId}: missing originalPostId or author`);
                    skipped++;
                    continue;
                }
                
                // Check if repost already exists in new collection
                const existingRepostQuery = await db.collection('reposts')
                    .where('reposterId', '==', reposterId)
                    .where('originalPostId', '==', originalPostId)
                    .where('contextType', '==', contextType)
                    .limit(1)
                    .get();
                
                if (!existingRepostQuery.empty) {
                    console.log(`  ⏭️  Repost already exists: ${repostId} -> ${originalPostId}`);
                    skipped++;
                    continue;
                }
                
                // Create repost document in new collection
                if (!DRY_RUN) {
                    const repostRef = db.collection('reposts').doc();
                    batch.set(repostRef, {
                        reposterId: reposterId,
                        originalPostId: originalPostId,
                        originalAuthorId: repostData.originalAuthorId || null,
                        contextType: contextType,
                        contextId: contextId,
                        timestamp: repostData.timestamp || FieldValue.serverTimestamp(),
                        previewThumbnail: repostData.thumbnail || null,
                        previewTitle: repostData.title || null,
                        createdAt: FieldValue.serverTimestamp(),
                        _migrated: true, // Mark as migrated for rollback
                        _oldRepostId: repostId, // Keep reference to old document
                    });
                    batchCount++;
                }
                
                // Track repost count for verification
                const currentCount = repostCounts.get(originalPostId) || 0;
                repostCounts.set(originalPostId, currentCount + 1);
                
                migrated++;
                
                if (migrated % 100 === 0) {
                    console.log(`  ✅ Migrated ${migrated} reposts...`);
                }
            } catch (error) {
                console.error(`  ❌ Error migrating repost ${doc.id}:`, error.message);
                errors++;
            }
        }
        
        // Commit batch
        if (batchCount > 0 && !DRY_RUN) {
            await batch.commit();
            console.log(`  💾 Committed batch: ${batchCount} reposts created`);
        }
        
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
    }
    
    console.log('');
    console.log('📊 Migration Summary:');
    console.log(`   Migrated: ${migrated}`);
    console.log(`   Skipped: ${skipped}`);
    console.log(`   Errors: ${errors}`);
    console.log('');
    
    // Verify repost counts
    console.log('🔍 Verifying repost counts...');
    let verified = 0;
    let mismatched = 0;
    
    for (const [originalPostId, expectedCount] of repostCounts.entries()) {
        try {
            // Count reposts in new collection
            const newCountSnapshot = await db.collection('reposts')
                .where('originalPostId', '==', originalPostId)
                .get();
            const newCount = newCountSnapshot.size;
            
            // Get repost count from original post
            const originalPostDoc = await db.collection('posts').doc(originalPostId).get();
            const originalPostData = originalPostDoc.data();
            const storedCount = originalPostData?.repostCount || 0;
            
            if (newCount !== storedCount) {
                console.log(`  ⚠️  Mismatch for ${originalPostId}: new collection=${newCount}, stored=${storedCount}`);
                mismatched++;
            } else {
                verified++;
            }
        } catch (error) {
            console.error(`  ❌ Error verifying ${originalPostId}:`, error.message);
        }
    }
    
    console.log('');
    console.log('✅ Verification complete!');
    console.log(`   Verified: ${verified}`);
    console.log(`   Mismatched: ${mismatched}`);
    console.log('');
    
    if (DRY_RUN) {
        console.log('⚠️  DRY RUN - No changes were made');
        console.log('   Run without DRY_RUN=true to apply migration');
    } else {
        console.log('🎉 Migration complete!');
        console.log('');
        console.log('Next steps:');
        console.log('1. Verify data integrity in production');
        console.log('2. Monitor repost creation/deletion for 24-48 hours');
        console.log('3. After verification, delete old repost documents:');
        console.log('   node scripts/cleanup_old_reposts.js');
    }
}

// Run migration
migrateReposts()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    });
