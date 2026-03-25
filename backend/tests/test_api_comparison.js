#!/usr/bin/env node

/**
 * Compare API results with different birth data to find the issue
 */

const API_KEY = '6BdMjydKb81OU3mKbuPPB23ueB7XAhg02jbxDAXQ';

const testCases = [
    {
        name: 'Current (July 31, 1998 19:30 IST)',
        payload: {
            year: 1998,
            month: 7,
            date: 31,
            hours: 19,
            minutes: 30,
            seconds: 0,
            latitude: 28.65195,
            longitude: 77.23149,
            timezone: 5.5
        }
    },
    {
        name: 'Try with 00:00 time (midnight)',
        payload: {
            year: 1998,
            month: 7,
            date: 31,
            hours: 0,
            minutes: 0,
            seconds: 0,
            latitude: 28.65195,
            longitude: 77.23149,
            timezone: 5.5
        }
    }
];

(async () => {
    for (const testCase of testCases) {
        console.log(`\n${'='.repeat(80)}`);
        console.log(`Testing: ${testCase.name}`);
        console.log(`${'='.repeat(80)}\n`);

        const response = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': API_KEY
            },
            body: JSON.stringify(testCase.payload)
        });

        if (!response.ok) {
            console.log('API Error:', response.status);
            continue;
        }

        const data = await response.json();
        const parsedData = typeof data.output === 'string' ? JSON.parse(data.output) : data.output;

        const saturn = parsedData.Saturn;
        if (saturn && saturn.Mercury) {
            console.log('Mercury Antar Dasha:');
            console.log('  Start:', saturn.Mercury.start_time);
            console.log('  End:', saturn.Mercury.end_time);

            // Calculate display date
            const endDate = new Date(saturn.Mercury.end_time.replace(' ', 'T') + 'Z');
            const endUTC = new Date(endDate.getTime() - (5.5 * 60 * 60 * 1000));
            console.log('  End (display):', endUTC.toLocaleDateString('en-GB'));

            // Compare with external
            const externalDate = new Date('2026-10-06');
            const diffDays = Math.abs(endUTC - externalDate) / (1000 * 60 * 60 * 24);
            console.log('  Difference from external (Oct 6):', diffDays.toFixed(1), 'days');
        }
    }

    console.log(`\n${'='.repeat(80)}`);
    console.log('CONCLUSION:');
    console.log('If both tests show Nov 3, the API consistently returns that date.');
    console.log('This suggests FreeAstrologyAPI uses different calculation methods');
    console.log('than the external apps (different Ayanamsa, ephemeris, or algorithm).');
    console.log(`${'='.repeat(80)}\n`);
})();
