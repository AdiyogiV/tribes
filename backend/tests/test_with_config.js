#!/usr/bin/env node

/**
 * Test API with and without config to see if it affects Dasha dates
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
    console.log('\n' + '='.repeat(80));
    console.log('TEST 1: WITHOUT config object (current behavior)');
    console.log('='.repeat(80) + '\n');

    const response1 = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': API_KEY
        },
        body: JSON.stringify(basePayload)
    });

    const data1 = await response1.json();
    const parsed1 = typeof data1.output === 'string' ? JSON.parse(data1.output) : data1.output;

    if (parsed1.Saturn && parsed1.Saturn.Mercury) {
        console.log('Mercury Antar Dasha:');
        console.log('  End:', parsed1.Saturn.Mercury.end_time);
        const endDate1 = new Date(parsed1.Saturn.Mercury.end_time.replace(' ', 'T') + 'Z');
        const endUTC1 = new Date(endDate1.getTime() - (5.5 * 60 * 60 * 1000));
        console.log('  Display:', endUTC1.toLocaleDateString('en-GB'));
    }

    console.log('\n' + '='.repeat(80));
    console.log('TEST 2: WITH config object (topocentric + lahiri)');
    console.log('='.repeat(80) + '\n');

    const payloadWithConfig = {
        ...basePayload,
        config: {
            observation_point: "topocentric",
            ayanamsha: "lahiri"
        }
    };

    const response2 = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': API_KEY
        },
        body: JSON.stringify(payloadWithConfig)
    });

    const data2 = await response2.json();
    const parsed2 = typeof data2.output === 'string' ? JSON.parse(data2.output) : data2.output;

    if (parsed2.Saturn && parsed2.Saturn.Mercury) {
        console.log('Mercury Antar Dasha:');
        console.log('  End:', parsed2.Saturn.Mercury.end_time);
        const endDate2 = new Date(parsed2.Saturn.Mercury.end_time.replace(' ', 'T') + 'Z');
        const endUTC2 = new Date(endDate2.getTime() - (5.5 * 60 * 60 * 1000));
        console.log('  Display:', endUTC2.toLocaleDateString('en-GB'));
    }

    console.log('\n' + '='.repeat(80));
    console.log('TEST 3: WITH config object (geocentric + lahiri)');
    console.log('='.repeat(80) + '\n');

    const payloadWithGeo = {
        ...basePayload,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri"
        }
    };

    const response3 = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': API_KEY
        },
        body: JSON.stringify(payloadWithGeo)
    });

    const data3 = await response3.json();
    const parsed3 = typeof data3.output === 'string' ? JSON.parse(data3.output) : data3.output;

    if (parsed3.Saturn && parsed3.Saturn.Mercury) {
        console.log('Mercury Antar Dasha:');
        console.log('  End:', parsed3.Saturn.Mercury.end_time);
        const endDate3 = new Date(parsed3.Saturn.Mercury.end_time.replace(' ', 'T') + 'Z');
        const endUTC3 = new Date(endDate3.getTime() - (5.5 * 60 * 60 * 1000));
        console.log('  Display:', endUTC3.toLocaleDateString('en-GB'));
    }

    console.log('\n' + '='.repeat(80));
    console.log('COMPARISON');
    console.log('='.repeat(80));
    console.log('External apps show: 06/10/2026');
    console.log('Compare the three results above to see which matches best!');
    console.log('='.repeat(80) + '\n');
})();
