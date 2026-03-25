/**
 * Script to restore Chelsea's deleted account
 * This will allow her to log back in
 */

import admin from 'firebase-admin';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function restoreUser(uid) {
  try {
    console.log(`\n🔄 Starting restoration for user: ${uid}`);

    // Step 1: Check current state
    const deletedUserRef = db.collection('deletedUsers').doc(uid);
    const deletedUserDoc = await deletedUserRef.get();

    if (!deletedUserDoc.exists) {
      console.log('❌ User is not in deletedUsers collection. Nothing to restore.');
      return;
    }

    console.log('✅ Confirmed user is in deletedUsers collection');
    const deletedData = deletedUserDoc.data();
    console.log('Deletion info:', JSON.stringify(deletedData, null, 2));

    // Step 2: Check if user document exists
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      console.log('✅ User document exists in users collection');
      const userData = userDoc.data();
      console.log('Current user data:', JSON.stringify({
        username: userData.username,
        displayName: userData.displayName,
        email: userData.email,
        phoneNumber: userData.phoneNumber,
        isDeleted: userData.isDeleted,
        deletedAt: userData.deletedAt
      }, null, 2));
    } else {
      console.log('⚠️  User document does NOT exist in users collection');
      console.log('You may need to recreate the user document or this is expected for this user type');
    }

    // Step 3: Perform restoration
    console.log('\n🚀 Performing restoration...');

    // Remove from deletedUsers collection
    await deletedUserRef.delete();
    console.log('✅ Step 1/2: Removed from deletedUsers collection');

    // Update user document if it exists
    if (userDoc.exists) {
      const updateData = {
        isDeleted: false,
        restoredAt: admin.firestore.FieldValue.serverTimestamp(),
        // Remove deletion timestamp if present
        deletedAt: admin.firestore.FieldValue.delete()
      };

      await userRef.update(updateData);
      console.log('✅ Step 2/2: Updated user document (set isDeleted: false, removed deletedAt)');
    } else {
      console.log('⏭️  Step 2/2: Skipped (no user document to update)');
    }

    console.log('\n🎉 RESTORATION COMPLETE!');
    console.log('Chelsea should now be able to log in with phone: ' + (deletedData.phoneNumber || 'unknown'));

    // Verify restoration
    console.log('\n🔍 Verifying restoration...');
    const verifyDeleted = await deletedUserRef.get();
    if (!verifyDeleted.exists) {
      console.log('✅ Verified: User is NO LONGER in deletedUsers collection');
    } else {
      console.log('❌ WARNING: User still in deletedUsers collection!');
    }

    if (userDoc.exists) {
      const verifyUser = await userRef.get();
      const verifyData = verifyUser.data();
      if (verifyData.isDeleted === false) {
        console.log('✅ Verified: User document has isDeleted: false');
      } else {
        console.log('❌ WARNING: User document still has isDeleted: true or undefined');
      }
    }

    console.log('\n✅ User can now log in successfully!');

  } catch (error) {
    console.error('❌ Error during restoration:', error);
    throw error;
  }
}

// Chelsea's UID from the logs
const chelseaUID = 'nMhqTXEwrRN44XAIKeVIiLnuezs1';

console.log('═══════════════════════════════════════════════');
console.log('  RESTORE DELETED USER ACCOUNT');
console.log('═══════════════════════════════════════════════');
console.log('This script will restore Chelsea\'s account');
console.log('UID:', chelseaUID);
console.log('═══════════════════════════════════════════════');

restoreUser(chelseaUID)
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
