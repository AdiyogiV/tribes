#!/usr/bin/env node

/**
 * Test to check what format the FreeAstrologyAPI returns dates in
 */

const payload = {
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

const apiKey = process.env.FREE_ASTROLOGY_API_KEY || '';
if (!apiKey) {
    console.log('❌ No API key found in environment');
    process.exit(1);
}

(async () => {
    console.log('\n=== TESTING API RESPONSE FORMAT ===\n');
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const response = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
        },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        console.log('❌ API Error:', response.status);
        const text = await response.text();
        console.log(text.substring(0, 500));
        process.exit(1);
    }

    const data = await response.json();

    // Find Saturn period
    const saturn = data.Saturn || data.output?.Saturn;
    if (saturn && saturn.sub_lords) {
        const mercury = saturn.sub_lords.Mercury;
        if (mercury) {
            console.log('\n✅ Mercury Antar Dasha from API:\n');
            console.log('Start:', mercury.start_time);
            console.log('End:', mercury.end_time);
            console.log('\nType:', typeof mercury.start_time);

            // Parse as if it's UTC
            const startAsUTC = new Date(mercury.start_time.replace(' ', 'T') + 'Z');
            console.log('\nIf treated as UTC:', startAsUTC.toISOString());
            console.log('  IST:', startAsUTC.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }));

            // Parse as if it's IST (subtract 5.5 hours)
            const startAsIST = new Date(startAsUTC.getTime() - (5.5 * 60 * 60 * 1000));
            console.log('\nIf treated as IST (subtract 5.5h):', startAsIST.toISOString());
            console.log('  IST:', startAsIST.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }));

            // End date
            console.log('\n--- End Date ---');
            const endAsUTC = new Date(mercury.end_time.replace(' ', 'T') + 'Z');
            console.log('If treated as UTC:', endAsUTC.toISOString());
            console.log('  Display:', endAsUTC.toLocaleDateString('en-GB')); // DD/MM/YYYY

            const endAsIST = new Date(endAsUTC.getTime() - (5.5 * 60 * 60 * 1000));
            console.log('\nIf treated as IST (subtract 5.5h):', endAsIST.toISOString());
            console.log('  Display:', endAsIST.toLocaleDateString('en-GB')); // DD/MM/YYYY
        }
    }

    process.exit(0);
})();
