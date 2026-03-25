/**
 * Check if a user's account data is complete or if it was deleted
 */

import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkUserDataCompleteness(uid) {
  console.log(`\n🔍 Checking data completeness for user: ${uid}\n`);

  const results = {
    coreData: {},
    subcollections: {},
    relationships: {},
    summary: {}
  };

  // 1. Check main user document
  console.log('1️⃣ Checking main user document...');
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      results.coreData.userDocument = {
        exists: true,
        fields: Object.keys(userData).length,
        hasUsername: !!userData.username,
        hasDisplayName: !!userData.displayName,
        hasPhoneNumber: !!userData.phoneNumber,
        hasEmail: !!userData.email,
        isDeleted: userData.isDeleted,
        createdAt: userData.createdAt,
        restoredAt: userData.restoredAt
      };
      console.log('   ✅ User document EXISTS');
      console.log('   📊 Fields:', Object.keys(userData).length);
      console.log('   📱 Phone:', userData.phoneNumber || 'N/A');
      console.log('   📧 Email:', userData.email || 'N/A');
      console.log('   👤 Username:', userData.username || 'N/A');
      console.log('   🏷️  Display Name:', userData.displayName || 'N/A');
      console.log('   🗑️  isDeleted:', userData.isDeleted);
    } else {
      results.coreData.userDocument = { exists: false };
      console.log('   ❌ User document DOES NOT exist');
    }
  } catch (e) {
    results.coreData.userDocument = { error: e.message };
    console.log('   ❌ Error checking user doc:', e.message);
  }

  // 2. Check deletedUsers status
  console.log('\n2️⃣ Checking deletedUsers audit record...');
  try {
    const deletedDoc = await db.collection('deletedUsers').doc(uid).get();
    if (deletedDoc.exists) {
      const deletedData = deletedDoc.data();
      results.coreData.deletedUsers = {
        exists: true,
        status: deletedData.status,
        deletionRequestedAt: deletedData.deletionRequestedAt,
        deletedAt: deletedData.deletedAt,
        completedAt: deletedData.completedAt,
        summary: deletedData.summary
      };
      console.log('   ⚠️  FOUND in deletedUsers collection');
      console.log('   📊 Status:', deletedData.status);
      console.log('   ⏰ Deletion requested:', deletedData.deletionRequestedAt?.toDate?.() || deletedData.deletionRequestedAt);
      if (deletedData.completedAt) {
        console.log('   ✅ Cleanup completed:', deletedData.completedAt?.toDate?.() || deletedData.completedAt);
      }
      if (deletedData.summary) {
        console.log('   📋 Cleanup summary:', JSON.stringify(deletedData.summary, null, 2));
      }
    } else {
      results.coreData.deletedUsers = { exists: false };
      console.log('   ✅ NOT in deletedUsers collection');
    }
  } catch (e) {
    results.coreData.deletedUsers = { error: e.message };
    console.log('   ❌ Error:', e.message);
  }

  // 3. Check Firebase Auth
  console.log('\n3️⃣ Checking Firebase Authentication...');
  try {
    const authUser = await admin.auth().getUser(uid);
    results.coreData.firebaseAuth = {
      exists: true,
      email: authUser.email,
      phoneNumber: authUser.phoneNumber,
      disabled: authUser.disabled,
      creationTime: authUser.metadata.creationTime,
      lastSignInTime: authUser.metadata.lastSignInTime
    };
    console.log('   ✅ Firebase Auth account EXISTS');
    console.log('   📱 Phone:', authUser.phoneNumber || 'N/A');
    console.log('   📧 Email:', authUser.email || 'N/A');
    console.log('   🔓 Disabled:', authUser.disabled);
    console.log('   🕐 Created:', authUser.metadata.creationTime);
    console.log('   🕐 Last sign-in:', authUser.metadata.lastSignInTime);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      results.coreData.firebaseAuth = { exists: false, reason: 'deleted' };
      console.log('   ❌ Firebase Auth account DELETED');
    } else {
      results.coreData.firebaseAuth = { error: e.message };
      console.log('   ❌ Error:', e.message);
    }
  }

  // 4. Check key subcollections
  console.log('\n4️⃣ Checking subcollections...');
  const subcollections = [
    { path: `users/${uid}/dailyInsights`, name: 'Daily Insights' },
    { path: `users/${uid}/astrology`, name: 'Astrology' },
    { path: `userFollowing/${uid}/following`, name: 'Following' },
    { path: `userFollowers/${uid}/followers`, name: 'Followers' },
    { path: `userSpaces/${uid}/spaces`, name: 'Spaces' },
    { path: `userFeed/${uid}/posts`, name: 'Feed' }
  ];

  for (const sub of subcollections) {
    try {
      const snapshot = await db.collection(sub.path).limit(1).get();
      const count = snapshot.size;
      results.subcollections[sub.name] = { exists: count > 0, sampleCount: count };
      console.log(`   ${count > 0 ? '✅' : '⚪'} ${sub.name}: ${count > 0 ? 'HAS DATA' : 'empty'}`);
    } catch (e) {
      results.subcollections[sub.name] = { error: e.message };
      console.log(`   ❌ ${sub.name}: error -`, e.message);
    }
  }

  // 5. Check posts
  console.log('\n5️⃣ Checking user posts...');
  try {
    const postsSnapshot = await db.collection('posts')
      .where('author', '==', uid)
      .limit(1)
      .get();
    results.relationships.posts = { count: postsSnapshot.size };
    console.log(`   ${postsSnapshot.size > 0 ? '✅' : '⚪'} Posts: ${postsSnapshot.size > 0 ? 'HAS POSTS' : 'no posts'}`);
  } catch (e) {
    results.relationships.posts = { error: e.message };
    console.log('   ❌ Error checking posts:', e.message);
  }

  // Summary
  console.log('\n═══════════════════════════════════════════════');
  console.log('📋 SUMMARY');
  console.log('═══════════════════════════════════════════════');

  const hasUserDoc = results.coreData.userDocument?.exists;
  const hasAuthAccount = results.coreData.firebaseAuth?.exists;
  const inDeletedUsers = results.coreData.deletedUsers?.exists;
  const deletionCompleted = results.coreData.deletedUsers?.status === 'completed';

  console.log(`\n🔍 Account Status:`);
  console.log(`   User Document: ${hasUserDoc ? '✅ EXISTS' : '❌ MISSING'}`);
  console.log(`   Firebase Auth: ${hasAuthAccount ? '✅ EXISTS' : '❌ DELETED'}`);
  console.log(`   In deletedUsers: ${inDeletedUsers ? '⚠️  YES' : '✅ NO'}`);
  if (inDeletedUsers) {
    console.log(`   Deletion Status: ${results.coreData.deletedUsers.status}`);
  }

  console.log(`\n🎯 Diagnosis:`);
  if (hasAuthAccount && inDeletedUsers && deletionCompleted) {
    console.log(`   ⚠️  INCONSISTENT STATE: Auth exists but deletion was completed`);
    console.log(`   This means the user can authenticate but app blocks them`);
    console.log(`   This happened because:`);
    console.log(`   1. User initiated deletion (added to deletedUsers)`);
    console.log(`   2. Cloud Function ran and cleaned up Firestore data`);
    console.log(`   3. But Firebase Auth deletion FAILED (user still exists)`);
    console.log(`   4. Now user can sign in but gets blocked by deletedUsers check`);
    console.log(`\n   ✅ SOLUTION: The restoration script already removed them from deletedUsers`);
    console.log(`              User should be able to log in now, but their data is gone.`);
  } else if (hasAuthAccount && inDeletedUsers && !deletionCompleted) {
    console.log(`   ⚠️  DELETION IN PROGRESS or FAILED`);
    console.log(`   Status: ${results.coreData.deletedUsers.status}`);
  } else if (hasAuthAccount && !inDeletedUsers && !hasUserDoc) {
    console.log(`   ⚠️  USER CAN LOG IN but has NO DATA`);
    console.log(`   This is a restored account with deleted data`);
    console.log(`   User needs to complete registration again`);
  } else if (hasAuthAccount && !inDeletedUsers && hasUserDoc) {
    console.log(`   ✅ FULLY FUNCTIONAL ACCOUNT`);
    console.log(`   User can log in normally`);
  } else {
    console.log(`   ❌ ACCOUNT FULLY DELETED`);
    console.log(`   Both Auth and Firestore data removed`);
  }

  console.log('\n═══════════════════════════════════════════════\n');

  return results;
}

// Chelsea's UID
const chelseaUID = 'nMhqTXEwrRN44XAIKeVIiLnuezs1';

checkUserDataCompleteness(chelseaUID)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
