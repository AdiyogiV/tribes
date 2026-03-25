/**
 * Test script to understand what happens if a restored user
 * tries to create a new account with the same phone number
 */

import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function analyzePhoneSignupScenario(uid, phoneNumber) {
  console.log('\n═══════════════════════════════════════════════');
  console.log('  PHONE NUMBER SIGNUP SCENARIO ANALYSIS');
  console.log('═══════════════════════════════════════════════');
  console.log(`UID: ${uid}`);
  console.log(`Phone: ${phoneNumber}`);
  console.log('═══════════════════════════════════════════════\n');

  // Scenario: User tries to sign up again with same phone number
  console.log('📱 SCENARIO: User attempts to sign up again with same phone number\n');

  // 1. Check if Firebase Auth account exists
  console.log('1️⃣ Checking Firebase Auth...');
  let authExists = false;
  try {
    const authUser = await admin.auth().getUser(uid);
    authExists = true;
    console.log('   ✅ Firebase Auth account EXISTS');
    console.log('   📱 Phone:', authUser.phoneNumber);
    console.log('   🔓 Disabled:', authUser.disabled);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      console.log('   ❌ Firebase Auth account DELETED');
    } else {
      console.log('   ❌ Error:', e.message);
    }
  }

  // 2. Check if user document exists
  console.log('\n2️⃣ Checking user document in Firestore...');
  const userDoc = await db.collection('users').doc(uid).get();
  let hasUserDoc = false;
  let hasNickname = false;

  if (userDoc.exists) {
    hasUserDoc = true;
    const userData = userDoc.data();
    hasNickname = !!userData.nickname;
    console.log('   ✅ User document EXISTS');
    console.log('   👤 Has nickname:', hasNickname);
    console.log('   📊 Field count:', Object.keys(userData).length);
    console.log('   📱 Phone in doc:', userData.phoneNumber);
  } else {
    console.log('   ❌ User document DOES NOT exist');
  }

  // 3. Check phoneIndex
  console.log('\n3️⃣ Checking phoneIndex...');
  const phoneIndexSnap = await db.collection('phoneIndex')
    .where('phoneNumber', '==', phoneNumber)
    .get();

  if (!phoneIndexSnap.empty) {
    console.log('   ⚠️  Phone number EXISTS in phoneIndex');
    phoneIndexSnap.forEach(doc => {
      const data = doc.data();
      console.log('   📋 Entry:', JSON.stringify({
        docId: doc.id,
        phoneNumber: data.phoneNumber,
        userId: data.userId
      }));
    });
  } else {
    console.log('   ✅ Phone number NOT in phoneIndex');
  }

  // 4. Check if there are other accounts with same phone
  console.log('\n4️⃣ Checking for duplicate phone numbers in users collection...');
  const usersWithPhone = await db.collection('users')
    .where('phoneNumber', '==', phoneNumber)
    .get();

  if (usersWithPhone.size > 0) {
    console.log(`   ⚠️  Found ${usersWithPhone.size} user(s) with this phone number:`);
    usersWithPhone.forEach(doc => {
      const data = doc.data();
      console.log(`   📋 User ${doc.id}:`, {
        nickname: data.nickname,
        name: data.name,
        phoneNumber: data.phoneNumber,
        hasNickname: !!data.nickname
      });
    });
  } else {
    console.log('   ✅ No users found with this phone number');
  }

  // ANALYSIS
  console.log('\n═══════════════════════════════════════════════');
  console.log('📋 WHAT WILL HAPPEN IF USER SIGNS UP AGAIN?');
  console.log('═══════════════════════════════════════════════\n');

  if (authExists && hasUserDoc && hasNickname) {
    console.log('✅ SCENARIO 1: User will be treated as EXISTING user');
    console.log('   • Firebase Auth exists → user can sign in');
    console.log('   • User doc exists with nickname → checkRegistration() returns false');
    console.log('   • User will be logged into their EXISTING account');
    console.log('   • NO new account will be created');
    console.log('   ✅ OUTCOME: No duplicate account, user accesses old data\n');
  } else if (authExists && hasUserDoc && !hasNickname) {
    console.log('⚠️  SCENARIO 2: User will be treated as NEW user (partial registration)');
    console.log('   • Firebase Auth exists → user can sign in');
    console.log('   • User doc exists BUT no nickname → checkRegistration() returns true');
    console.log('   • User will go through registration/onboarding flow');
    console.log('   • registerNewUser() will OVERWRITE existing user document (using SET with merge)');
    console.log('   ⚠️  OUTCOME: Old data preserved, user completes registration\n');
  } else if (authExists && !hasUserDoc) {
    console.log('⚠️  SCENARIO 3: Auth exists but no user document');
    console.log('   • Firebase Auth exists → user can sign in');
    console.log('   • No user doc → checkRegistration() returns true (new user)');
    console.log('   • User goes through registration');
    console.log('   • registerNewUser() creates NEW user document');
    console.log('   ✅ OUTCOME: User completes registration, starts fresh\n');
  } else if (!authExists) {
    console.log('❌ SCENARIO 4: No auth account exists');
    console.log('   • When user tries to sign up with phone number:');
    console.log('   • Firebase Auth will create a NEW Auth user with SAME phone');
    console.log('   • This NEW Auth user will have a DIFFERENT UID!');
    console.log('   • The old user document (with old UID) will be orphaned');
    console.log('   ⚠️  OUTCOME: New account created, old data becomes inaccessible\n');
  }

  // CRITICAL ISSUE
  if (authExists && phoneIndexSnap.size > 0) {
    console.log('🚨 CRITICAL ISSUE: phoneIndex cleanup needed!');
    console.log('   • phoneIndex still has entry for this phone number');
    console.log('   • This could cause contact discovery issues');
    console.log('   • The deletion Cloud Function should have cleaned this up');
    console.log('   • This indicates incomplete deletion cleanup\n');
  }

  if (usersWithPhone.size > 1) {
    console.log('🚨 CRITICAL ISSUE: DUPLICATE phone numbers detected!');
    console.log(`   • Found ${usersWithPhone.size} users with phone: ${phoneNumber}`);
    console.log('   • This should NOT be possible with proper phone auth');
    console.log('   • Indicates data corruption or migration issue');
    console.log('   • Recommend manual cleanup\n');
  }

  console.log('═══════════════════════════════════════════════\n');
}

// Chelsea's info
const chelseaUID = 'nMhqTXEwrRN44XAIKeVIiLnuezs1';
const chelseaPhone = '+14167006061';

analyzePhoneSignupScenario(chelseaUID, chelseaPhone)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
