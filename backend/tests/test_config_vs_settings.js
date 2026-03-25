#!/usr/bin/env node

/**
 * Test if API accepts "config" vs "settings" for different endpoints
 */

const API_KEY = '6BdMjydKb81OU3mKbuPPB23ueB7XAhg02jbxDAXQ';

const basePayload = {
    year: 1998,
    month: 7,
    date: 31,
    hours: 19,
    minutes: 30,
    seconds: 0,
    latitude: 28.65195,
    longitude: 77.23149,
    timezone: 5.5
};

(async () => {
    console.log('\n=== Testing "config" vs "settings" parameter ===\n');

    // Test 1: Planets Extended with "config"
    console.log('TEST 1: Planets Extended with "config"');
    try {
        const response1 = await fetch('https://json.freeastrologyapi.com/planets/extended', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': API_KEY
            },
            body: JSON.stringify({
                ...basePayload,
                config: {
                    observation_point: "geocentric",
                    ayanamsha: "lahiri"
                }
            })
        });
        console.log('Status:', response1.status);
        if (response1.ok) {
            const data1 = await response1.json();
            console.log('✅ Works with "config"');
        }
    } catch (e) {
        console.log('❌ Error:', e.message);
    }

    // Test 2: Planets Extended with "settings"
    console.log('\nTEST 2: Planets Extended with "settings"');
    try {
        const response2 = await fetch('https://json.freeastrologyapi.com/planets/extended', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': API_KEY
            },
            body: JSON.stringify({
                ...basePayload,
                settings: {
                    observation_point: "geocentric",
                    ayanamsha: "lahiri",
                    language: "en"
                }
            })
        });
        console.log('Status:', response2.status);
        if (response2.ok) {
            const data2 = await response2.json();
            console.log('✅ Works with "settings"');
        }
    } catch (e) {
        console.log('❌ Error:', e.message);
    }

    // Test 3: Dasha with "config"
    console.log('\nTEST 3: Dasha with "config"');
    try {
        const response3 = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': API_KEY
            },
            body: JSON.stringify({
                ...basePayload,
                config: {
                    observation_point: "geocentric",
                    ayanamsha: "lahiri"
                }
            })
        });
        console.log('Status:', response3.status);
        if (response3.ok) {
            console.log('✅ Works with "config"');
        }
    } catch (e) {
        console.log('❌ Error:', e.message);
    }

    console.log('\n=== Recommendation ===');
    console.log('Based on docs, it seems:');
    console.log('- Planets Extended: Use "settings"');
    console.log('- Planets (basic): Use "config"');
    console.log('- Dasha: Use "config"');
    console.log('- Panchang: Use "config"');
    console.log('\nBut the API might accept both! Check the results above.\n');
})();
