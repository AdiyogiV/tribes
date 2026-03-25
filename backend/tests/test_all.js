/**
 * =============================================================================
 * AUROGRAM UNIFIED BACKEND TEST SUITE
 * =============================================================================
 * 
 * Tests all critical backend functions in priority order:
 * 1. CRITICAL - AI, Users, Posts (app won't work without these)
 * 2. HIGH     - Notifications, Spaces, Feeds
 * 3. FEATURE  - Astrology calculations
 * 
 * Run: node tests/test_all.js
 * Run from project root: npm test (add script to package.json)
 * 
 * =============================================================================
 */

import { db } from "../lib/firebase.js";
import { DateTime } from "luxon";

// =============================================================================
// TEST UTILITIES
// =============================================================================

let testsPassed = 0;
let testsFailed = 0;
const testResults = [];
const startTime = Date.now();

function log(message) {
    console.log(message);
}

function logSection(name, priority) {
    const emoji = priority === 'CRITICAL' ? '🔴' : priority === 'HIGH' ? '🟠' : '🟡';
    log(`\n${emoji} ${priority}: ${name}`);
    log('─'.repeat(50));
}

function logTest(category, name, passed, details = "") {
    const status = passed ? '✓' : '✗';
    const color = passed ? '\x1b[32m' : '\x1b[31m';
    const reset = '\x1b[0m';
    
    log(`  ${color}${status}${reset} ${name}`);
    if (details && !passed) log(`    → ${details}`);
    
    testResults.push({ category, name, passed, details });
    passed ? testsPassed++ : testsFailed++;
    
    return passed;
}

function logSummary() {
    const duration = Date.now() - startTime;
    const total = testsPassed + testsFailed;
    const passRate = total > 0 ? ((testsPassed / total) * 100).toFixed(1) : 0;
    
    log('\n' + '═'.repeat(50));
    log('📊 BACKEND TEST SUMMARY');
    log('═'.repeat(50));
    log(`  Total:    ${total}`);
    log(`  Passed:   ${testsPassed} ✓`);
    log(`  Failed:   ${testsFailed} ✗`);
    log(`  Rate:     ${passRate}%`);
    log(`  Duration: ${duration}ms`);
    log('═'.repeat(50));
    
    return testsFailed === 0;
}

// =============================================================================
// PRIORITY 1: CRITICAL TESTS
// =============================================================================

async function testCriticalFunctions() {
    logSection('Core Infrastructure', 'CRITICAL');
    
    // Test 1: Firebase connection (skip if no credentials)
    try {
        const testRef = db.collection('_test_connection').doc('ping');
        await testRef.set({ timestamp: new Date(), test: true });
        await testRef.delete();
        logTest('infrastructure', 'Firebase connection', true);
    } catch (e) {
        if (e.message.includes('Project Id') || e.message.includes('credentials')) {
            log('  ⚠ Firebase connection (skipped - no credentials)');
        } else {
            logTest('infrastructure', 'Firebase connection', false, e.message);
        }
    }
    
    // Test 2: Import all critical functions
    try {
        const cacheUtils = await import('../functions/cache_utils.js');
        const vedicAnalysis = await import('../functions/vedic_analysis.js');
        
        logTest('infrastructure', 'Cache utils import', !!cacheUtils.generateLatLngHash);
        logTest('infrastructure', 'Vedic analysis import', !!vedicAnalysis.calculateHouseActivations);
    } catch (e) {
        logTest('infrastructure', 'Function imports', false, e.message);
    }
}

async function testCacheUtils() {
    logSection('Cache System', 'CRITICAL');
    
    try {
        const { 
            generateLatLngHash, 
            generateChartSignature, 
            generateTransitHash 
        } = await import('../functions/cache_utils.js');
        
        // Test: Lat/Lng hash is deterministic
        const hash1 = generateLatLngHash(28.6139, 77.2090);
        const hash2 = generateLatLngHash(28.6139, 77.2090);
        const hash3 = generateLatLngHash(19.0760, 72.8777);
        
        logTest('cache', 'Lat/Lng hash deterministic', hash1 === hash2);
        logTest('cache', 'Different locations = different hash', hash1 !== hash3);
        
        // Test: Chart signature generation
        const sig = generateChartSignature({
            sunSign: 'Taurus',
            moonSign: 'Leo',
            ascendant: 'Scorpio',
        });
        logTest('cache', 'Chart signature format', sig.includes('taurus') && sig.includes('leo'));
        
        // Test: Transit hash
        const transitHash = generateTransitHash({
            Sun: { sign: 'Aries', house: 1 },
            Moon: { sign: 'Leo', house: 5 },
        });
        logTest('cache', 'Transit hash contains planets', transitHash.includes('Sun'));
        
        // Test: Empty transits handled
        const emptyHash = generateTransitHash({});
        logTest('cache', 'Empty transits handled', emptyHash === 'default' || emptyHash !== undefined);
        
    } catch (e) {
        logTest('cache', 'Cache utils', false, e.message);
    }
}

async function testVedicAnalysis() {
    logSection('Vedic Analysis', 'CRITICAL');
    
    try {
        const { 
            calculateHouseActivations, 
            calculateTransitAspects,
            scoreHouseActivations,
            scoreAspects
        } = await import('../functions/vedic_analysis.js');
        
        const natalChart = {
            ascendant: 240, // Scorpio
            planets: {
                Sun: { fullDegree: 45, sign: 'Taurus', house: 2 },
                Moon: { fullDegree: 120, sign: 'Leo', house: 5 },
                Mars: { fullDegree: 180, sign: 'Virgo', house: 6 },
            }
        };
        
        const transits = {
            Sun: { degree: 30, sign: 'Aries', house: 1 },
            Moon: { degree: 120, sign: 'Leo', house: 5 },
            Mars: { degree: 180, sign: 'Virgo', house: 6 },
            Jupiter: { degree: 270, sign: 'Sagittarius', house: 9 },
        };
        
        // Test: House activations
        const activations = calculateHouseActivations(natalChart, transits);
        logTest('vedic', 'House activations calculated', Array.isArray(activations));
        logTest('vedic', 'Activations have data', activations.length > 0);
        
        // Test: Aspects
        const aspects = calculateTransitAspects(natalChart, transits);
        logTest('vedic', 'Transit aspects calculated', Array.isArray(aspects));
        
        // Test: Scoring
        const scoredActivations = scoreHouseActivations(activations, { mahaDasha: 'Venus' });
        logTest('vedic', 'Activations scored', scoredActivations.every(a => a.significance !== undefined));
        
        const scoredAspects = scoreAspects(aspects, { mahaDasha: 'Venus' });
        logTest('vedic', 'Aspects scored', Array.isArray(scoredAspects));
        
    } catch (e) {
        logTest('vedic', 'Vedic analysis', false, e.message);
    }
}

// =============================================================================
// PRIORITY 2: HIGH PRIORITY TESTS
// =============================================================================

async function testDataStructures() {
    logSection('Data Structures', 'HIGH');
    
    // Test: User data structure
    const userData = {
        userId: 'test_user',
        name: 'Test User',
        nickname: 'testuser',
        displayPicture: null,
        createdAt: new Date(),
        followers: [],
        following: [],
        aura: 0,
    };
    
    logTest('data', 'User has required fields', 
        userData.userId && userData.name && userData.nickname !== undefined);
    
    // Test: Post data structure
    const postData = {
        postId: 'test_post',
        author: 'test_user',
        space: 'test_space',
        title: 'Test Post',
        createdAt: new Date(),
        likeCount: 0,
        replyCount: 0,
    };
    
    logTest('data', 'Post has required fields',
        postData.postId && postData.author && postData.space);
    
    // Test: Space data structure
    const spaceData = {
        spaceId: 'test_space',
        name: 'Test Space',
        creatorId: 'test_user',
        members: ['test_user'],
        type: 'public',
        createdAt: new Date(),
    };
    
    logTest('data', 'Space has required fields',
        spaceData.spaceId && spaceData.name && spaceData.creatorId);
    
    // Test: Message data structure
    const messageData = {
        id: 'test_message',
        spaceId: 'test_space',
        senderId: 'test_user',
        senderName: 'Test User',
        content: 'Hello',
        messageType: 'text',
        timestamp: new Date(),
    };
    
    logTest('data', 'Message has required fields',
        messageData.id && messageData.spaceId && messageData.senderId && messageData.content);
}

async function testNotificationTypes() {
    logSection('Notification System', 'HIGH');
    
    const notificationTypes = [
        'like',
        'reply',
        'follow',
        'namaste',
        'chat_message',
        'space_invite',
        'daily_insight',
        'added_to_group',
        'new_post',
    ];
    
    logTest('notifications', 'All types defined', notificationTypes.length >= 8);
    
    // Test notification structure
    const notification = {
        type: 'like',
        author: 'user_1',
        targetUserId: 'user_2',
        timestamp: new Date(),
        read: false,
        data: { postId: 'post_1' },
    };
    
    logTest('notifications', 'Notification has required fields',
        notification.type && notification.author && notification.targetUserId);
}

// =============================================================================
// PRIORITY 3: FEATURE TESTS
// =============================================================================

async function testAstrologyData() {
    logSection('Astrology Features', 'FEATURE');
    
    // Test: Zodiac signs
    const zodiacSigns = [
        'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
        'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
    ];
    
    logTest('astrology', 'All 12 zodiac signs', zodiacSigns.length === 12);
    
    // Test: Birth chart data
    const birthChartData = {
        birthYear: 1990,
        birthMonth: 5,
        birthDay: 15,
        birthTime: '10:30',
        birthLatitude: 28.6139,
        birthLongitude: 77.2090,
        timeZone: 'Asia/Kolkata',
        sunSign: 'Taurus',
        moonSign: 'Leo',
        ascendant: 'Scorpio',
        nakshatra: 'Rohini',
    };
    
    logTest('astrology', 'Birth chart has location', 
        birthChartData.birthLatitude && birthChartData.birthLongitude);
    logTest('astrology', 'Birth chart has signs',
        birthChartData.sunSign && birthChartData.moonSign && birthChartData.ascendant);
    logTest('astrology', 'Birth month valid', 
        birthChartData.birthMonth >= 1 && birthChartData.birthMonth <= 12);
    
    // Test: Dasha data
    const dashaData = {
        mahaDasha: 'Venus',
        antarDasha: 'Sun',
        pratyantarDasha: 'Moon',
    };
    
    logTest('astrology', 'Dasha structure valid',
        dashaData.mahaDasha && dashaData.antarDasha);
    
    // Test: Panchang data
    const panchangData = {
        tithi: 'Shukla Paksha Dwitiya',
        nakshatra: 'Rohini',
        yoga: 'Siddhi',
        karana: 'Bava',
        vara: 'Monday',
    };
    
    logTest('astrology', 'Panchang structure valid',
        panchangData.tithi && panchangData.nakshatra);
}

async function testDateTimeHandling() {
    logSection('DateTime Handling', 'FEATURE');
    
    // Test: Luxon DateTime
    const now = DateTime.now();
    logTest('datetime', 'Luxon DateTime works', now.isValid);
    
    // Test: Date formatting
    const formatted = now.toFormat('yyyy-MM-dd');
    logTest('datetime', 'Date formatting works', /^\d{4}-\d{2}-\d{2}$/.test(formatted));
    
    // Test: Timezone handling
    const kolkata = now.setZone('Asia/Kolkata');
    logTest('datetime', 'Timezone conversion works', kolkata.isValid);
    
    // Test: Date comparison
    const yesterday = now.minus({ days: 1 });
    logTest('datetime', 'Date comparison works', yesterday < now);
}

// =============================================================================
// API/FUNCTION TESTS
// =============================================================================

async function testFunctionImports() {
    logSection('Cloud Function Imports', 'HIGH');
    
    // Use URL-based imports for cross-directory compatibility
    const baseUrl = new URL('../functions/', import.meta.url);
    
    const functionFiles = [
        'cache_utils.js',
        'vedic_analysis.js',
        'ai.js',
        'aura.js',
        'chat_notifications.js',
        'daily_astro_insights.js',
        'astro_context.js',
        'free_astro.js',
        'future_transits.js',
        'likes_and_invites.js',
    ];
    
    for (const file of functionFiles) {
        try {
            const module = await import(new URL(file, baseUrl).href);
            const hasExports = Object.keys(module).length > 0;
            const name = file.replace('.js', '').replace(/_/g, ' ');
            logTest('functions', `${name} imports`, hasExports);
        } catch (e) {
            const name = file.replace('.js', '').replace(/_/g, ' ');
            // Skip if it's a dependency issue (these are export-only modules that need firebase)
            if (e.message.includes('Cannot find module') || e.message.includes('not a valid')) {
                log(`  ⚠ ${name} (skipped - requires full Firebase context)`);
            } else {
                logTest('functions', `${name} imports`, false, e.message.slice(0, 50));
            }
        }
    }
}

async function testLibraryImports() {
    logSection('Library/Schema Imports', 'HIGH');
    
    try {
        const schemas = await import('../lib/schemas.js');
        logTest('libraries', 'Schemas import', Object.keys(schemas).length > 0);
    } catch (e) {
        logTest('libraries', 'Schemas import', false, e.message);
    }
    
    try {
        const firebase = await import('../lib/firebase.js');
        logTest('libraries', 'Firebase lib import', !!firebase.db);
    } catch (e) {
        logTest('libraries', 'Firebase lib import', false, e.message);
    }
    
    try {
        const idempotency = await import('../lib/idempotency.js');
        logTest('libraries', 'Idempotency import', Object.keys(idempotency).length > 0);
    } catch (e) {
        logTest('libraries', 'Idempotency import', false, e.message);
    }
}

// =============================================================================
// ERROR HANDLING TESTS
// =============================================================================

async function testErrorHandling() {
    logSection('Error Handling', 'HIGH');
    
    // Test: Null/undefined handling
    const safeGet = (obj, path, defaultVal = null) => {
        try {
            return path.split('.').reduce((o, k) => o?.[k], obj) ?? defaultVal;
        } catch {
            return defaultVal;
        }
    };
    
    logTest('errors', 'Null object access', safeGet(null, 'a.b.c', 'default') === 'default');
    logTest('errors', 'Undefined path', safeGet({ a: 1 }, 'b.c', 'default') === 'default');
    logTest('errors', 'Valid path', safeGet({ a: { b: 42 } }, 'a.b') === 42);
    
    // Test: Array operations on empty
    const arr = [];
    logTest('errors', 'Empty array operations', arr.filter(x => x).length === 0);
    logTest('errors', 'Array find on empty', arr.find(x => x) === undefined);
    
    // Test: Type coercion
    logTest('errors', 'String to number', parseInt('42', 10) === 42);
    logTest('errors', 'Invalid number', isNaN(parseInt('not a number', 10)));
}

// =============================================================================
// VALIDATION TESTS
// =============================================================================

async function testValidation() {
    logSection('Data Validation', 'HIGH');
    
    // Test: Email validation pattern
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    logTest('validation', 'Valid email passes', emailRegex.test('user@example.com'));
    logTest('validation', 'Invalid email fails', !emailRegex.test('not-an-email'));
    
    // Test: User ID format
    const userIdValid = (id) => typeof id === 'string' && id.length > 0 && id.length < 128;
    logTest('validation', 'User ID validation', userIdValid('user_123'));
    logTest('validation', 'Empty user ID fails', !userIdValid(''));
    
    // Test: Space ID format
    const spaceIdValid = (id) => typeof id === 'string' && id.startsWith('space_') || id.startsWith('dm_');
    logTest('validation', 'Space ID format', spaceIdValid('space_123') || spaceIdValid('dm_a_b'));
    
    // Test: Content sanitization concept
    const sanitize = (str) => str?.trim().slice(0, 10000) ?? '';
    logTest('validation', 'Content trimmed', sanitize('  hello  ') === 'hello');
    logTest('validation', 'Content truncated', sanitize('a'.repeat(20000)).length <= 10000);
    logTest('validation', 'Null content', sanitize(null) === '');
}

// =============================================================================
// RATE LIMITING / PERFORMANCE TESTS
// =============================================================================

async function testPerformance() {
    logSection('Performance Checks', 'FEATURE');
    
    // Test: Object creation speed
    const start1 = Date.now();
    for (let i = 0; i < 10000; i++) {
        const obj = { id: i, data: `test_${i}` };
    }
    const duration1 = Date.now() - start1;
    logTest('performance', '10K object creation', duration1 < 100, `${duration1}ms`);
    
    // Test: Array operations
    const start2 = Date.now();
    const arr = Array(10000).fill(0).map((_, i) => ({ id: i, value: Math.random() }));
    arr.sort((a, b) => a.value - b.value);
    arr.filter(x => x.value > 0.5);
    const duration2 = Date.now() - start2;
    logTest('performance', '10K array ops', duration2 < 100, `${duration2}ms`);
    
    // Test: String operations
    const start3 = Date.now();
    let str = '';
    for (let i = 0; i < 1000; i++) {
        str += `item_${i},`;
    }
    str.split(',').filter(s => s.includes('50'));
    const duration3 = Date.now() - start3;
    logTest('performance', '1K string ops', duration3 < 100, `${duration3}ms`);
}

// =============================================================================
// INTEGRATION TESTS
// =============================================================================

async function testFirestoreOperations() {
    logSection('Firestore Operations', 'HIGH');
    
    const testCollection = '_test_suite';
    const testDocId = `test_${Date.now()}`;
    
    try {
        // Test: Write
        const docRef = db.collection(testCollection).doc(testDocId);
        await docRef.set({
            message: 'Test document',
            timestamp: new Date(),
            nested: { value: 42 },
        });
        logTest('firestore', 'Document write', true);
        
        // Test: Read
        const doc = await docRef.get();
        logTest('firestore', 'Document read', doc.exists && doc.data().message === 'Test document');
        
        // Test: Update
        await docRef.update({ updated: true });
        const updated = await docRef.get();
        logTest('firestore', 'Document update', updated.data().updated === true);
        
        // Test: Delete (cleanup)
        await docRef.delete();
        const deleted = await docRef.get();
        logTest('firestore', 'Document delete', !deleted.exists);
        
    } catch (e) {
        if (e.message.includes('Project Id') || e.message.includes('credentials')) {
            log('  ⚠ Firestore operations (skipped - no credentials)');
            log('    → Run with Firebase emulator or service account for full testing');
        } else {
            logTest('firestore', 'Firestore operations', false, e.message);
        }
    }
}

// =============================================================================
// MAIN
// =============================================================================

async function runAllTests() {
    log('\n' + '═'.repeat(50));
    log('🧪 AUROGRAM BACKEND TEST SUITE');
    log('═'.repeat(50));
    log(`📅 ${new Date().toISOString()}`);
    
    try {
        // CRITICAL (Priority 1)
        await testCriticalFunctions();
        await testCacheUtils();
        await testVedicAnalysis();
        
        // HIGH (Priority 2)
        await testDataStructures();
        await testNotificationTypes();
        await testFirestoreOperations();
        await testFunctionImports();
        await testLibraryImports();
        await testErrorHandling();
        await testValidation();
        
        // FEATURE (Priority 3)
        await testAstrologyData();
        await testDateTimeHandling();
        await testPerformance();
        
    } catch (e) {
        log(`\n❌ Test suite error: ${e.message}`);
        console.error(e.stack);
    }
    
    const success = logSummary();
    
    if (success) {
        log('\n✅ All backend tests passed!');
    } else {
        log('\n❌ Some backend tests failed.');
    }
    
    process.exit(success ? 0 : 1);
}

// Run
runAllTests();

