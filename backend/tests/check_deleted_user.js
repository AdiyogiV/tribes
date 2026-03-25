/**
 * Script to check if a user is in the deletedUsers collection
 * and optionally restore them
 */

import admin from 'firebase-admin';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkAndRestoreUser(uid) {
  try {
    console.log(`\n🔍 Checking user: ${uid}`);

    // Check if user exists in deletedUsers collection
    const deletedUserRef = db.collection('deletedUsers').doc(uid);
    const deletedUserDoc = await deletedUserRef.get();

    if (deletedUserDoc.exists) {
      console.log('❌ User IS in deletedUsers collection');
      console.log('Deleted user data:', JSON.stringify(deletedUserDoc.data(), null, 2));

      // Check if user document exists in users collection
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();

      if (userDoc.exists) {
        console.log('✅ User document EXISTS in users collection');
        console.log('User data:', JSON.stringify({
          username: userDoc.data().username,
          displayName: userDoc.data().displayName,
          email: userDoc.data().email,
          createdAt: userDoc.data().createdAt,
          isDeleted: userDoc.data().isDeleted
        }, null, 2));
      } else {
        console.log('❌ User document DOES NOT exist in users collection');
      }

      // Check Firebase Auth
      try {
        const authUser = await admin.auth().getUser(uid);
        console.log('✅ Firebase Auth account EXISTS');
        console.log('Auth data:', JSON.stringify({
          email: authUser.email,
          displayName: authUser.displayName,
          disabled: authUser.disabled,
          creationTime: authUser.metadata.creationTime,
          lastSignInTime: authUser.metadata.lastSignInTime
        }, null, 2));
      } catch (authError) {
        console.log('❌ Firebase Auth account NOT found:', authError.message);
      }

      console.log('\n📋 To restore this user, you need to:');
      console.log('1. Remove them from deletedUsers collection');
      console.log('2. Ensure their document exists in users collection');
      console.log('3. Set isDeleted: false in their user document (if it exists)');

      console.log('\n❓ Do you want to restore this user? (you will need to run restoration manually or uncomment code below)');

      // UNCOMMENT THIS SECTION TO ACTUALLY RESTORE THE USER
      /*
      console.log('\n🔄 Restoring user...');
      
      // Remove from deletedUsers
      await deletedUserRef.delete();
      console.log('✅ Removed from deletedUsers collection');
      
      // Update user document if it exists
      if (userDoc.exists) {
        await userRef.update({
          isDeleted: false,
          deletedAt: admin.firestore.FieldValue.delete(),
          restoredAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Updated user document (set isDeleted: false)');
      }
      
      console.log('✅ User restoration complete! They should now be able to log in.');
      */

    } else {
      console.log('✅ User is NOT in deletedUsers collection');
      console.log('This user should be able to log in normally.');

      // Check regular user collection anyway
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();

      if (userDoc.exists) {
        console.log('✅ User document exists in users collection');
        const userData = userDoc.data();
        if (userData.isDeleted === true) {
          console.log('⚠️  WARNING: User document has isDeleted: true but is not in deletedUsers collection');
          console.log('This is an inconsistent state.');
        }
      } else {
        console.log('❌ User document DOES NOT exist in users collection');
        console.log('User may not be registered yet.');
      }
    }

  } catch (error) {
    console.error('❌ Error checking user:', error);
  }
}

// Chelsea's UID from the logs
const chelseaUID = 'nMhqTXEwrRN44XAIKeVIiLnuezs1';

checkAndRestoreUser(chelseaUID)
  .then(() => {
    console.log('\n✅ Check complete');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
