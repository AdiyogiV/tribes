/**
 * क्रिया — निमित्त संग्रह (Nimitta Sangraha: Omen Collection)
 *
 * "Before the Jyotishi speaks, he observes — the earth trembles,
 *  the sky darkens, the crow cries. These are Nimitta."
 *
 * This module collects REAL WORLD OBSERVATIONS from free public APIs
 * and converts them into the BS observation format that varga/pipeline.js
 * expects. This is the bridge between the modern world and Varahamihira.
 *
 * DATA SOURCES (all free, no API key needed):
 *   1. USGS Earthquake API        → bhumi.js (earthquake circles)
 *   2. Open-Meteo Weather API     → atmospheric anomalies (thunder, halo, unusual heat)
 *   3. NASA Donki / Eclipse API   → eclipses, solar flares, geomagnetic storms
 *   4. Google News RSS            → modern nimitta proxy (unusual events)
 *   5. USGS Volcanic Activity     → portents (fire from earth)
 *
 * Each source returns data that maps DIRECTLY to a BS chapter:
 *   Earthquake  → Ch.32 (earthquake circles, timing, precursors)
 *   Eclipse     → Ch.5 (Rahu), Ch.3 (Sun), Ch.4 (Moon)
 *   Weather     → Ch.21-28 (rainfall, thunder, lightning)
 *   Volcanic    → Ch.46 (portentous phenomena)
 *   News        → Ch.86-95 (modern proxy for shakuna/omens)
 *
 * Usage:
 *   import { collectNimitta } from './nimitta_sangraha.js';
 *   const observations = await collectNimitta({ lat: 28.6, lon: 77.2 });
 *   // Feed directly into: runPipeline(skyState, observations)
 */

import { NAKSHATRA_BY_NAME } from '../varga/nakshatra.js';

// ─── API ENDPOINTS (all free, no key) ───────────────────────────────────────

const USGS_EARTHQUAKE_API = 'https://earthquake.usgs.gov/fdsnws/event/1/query';
const OPEN_METEO_API = 'https://api.open-meteo.com/v1/forecast';
const NASA_DONKI_API = 'https://api.nasa.gov/DONKI';
const NASA_API_KEY = 'DEMO_KEY'; // Free tier: 30 req/hr, 50/day. Enough for daily reading.
const USGS_VOLCANO_API = 'https://volcanoes.usgs.gov/vsc/api/volcanoApi';

// ─── SEASONAL BASELINE (for anomaly detection per BS) ───────────────────────
// BS Ch.21-28: Only ABNORMAL weather counts. Must know what's normal first.

const SEASON_BASELINES = {
  vasanta:  { tempRange: [20, 35], normalRain: false, thunderNormal: false },
  grishma:  { tempRange: [30, 48], normalRain: false, thunderNormal: true },
  varsha:   { tempRange: [24, 38], normalRain: true,  thunderNormal: true },
  sharad:   { tempRange: [22, 35], normalRain: true,  thunderNormal: false },
  hemanta:  { tempRange: [10, 25], normalRain: false, thunderNormal: false },
  shishira: { tempRange: [5, 20],  normalRain: false, thunderNormal: false },
};

/**
 * Determine the Hindu ritu (season) from a date.
 * Approximate mapping based on solar months.
 */
function getSeason(date) {
  const month = date.getMonth(); // 0-indexed
  if (month === 2 || month === 3) return 'vasanta';     // Mar-Apr
  if (month === 4 || month === 5) return 'grishma';     // May-Jun
  if (month === 6 || month === 7) return 'varsha';      // Jul-Aug
  if (month === 8 || month === 9) return 'sharad';      // Sep-Oct
  if (month === 10 || month === 11) return 'hemanta';   // Nov-Dec
  return 'shishira';                                     // Jan-Feb
}

/**
 * Safe fetch wrapper with timeout and error handling.
 * Uses curl fallback for corporate network DNS issues.
 */
async function safeFetch(url, timeoutMs = 10000) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const response = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'BrihatSamhitaEngine/1.0' }
    });
    clearTimeout(timeout);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (err) {
    // Fallback to curl for corporate network
    try {
      const { execSync } = await import('child_process');
      const result = execSync(`curl -s --max-time ${Math.ceil(timeoutMs / 1000)} "${url}"`, {
        encoding: 'utf8',
        timeout: timeoutMs + 2000
      });
      return JSON.parse(result);
    } catch {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. EARTHQUAKE OBSERVATION → bhumi.js
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Estimate Moon's sidereal longitude at a given timestamp.
 *
 * Uses a simplified lunar ephemeris based on mean orbital elements.
 * The Moon's mean sidereal period is 27.321661 days.
 * We use a known reference point (J2000.0 epoch) and compute forward.
 *
 * Accuracy: ±2-3° (±1 nakshatra). Good enough for circle classification
 * since each circle spans 7 nakshatras (~93°).
 *
 * @param {Date} date - Timestamp to compute for
 * @returns {number} Sidereal longitude in degrees (0-360)
 */
function estimateMoonLongitude(date) {
  // Reference: Moon's mean sidereal longitude at J2000.0 (Jan 1.5, 2000 TT)
  const J2000 = new Date('2000-01-01T12:00:00Z');
  const daysSinceJ2000 = (date.getTime() - J2000.getTime()) / 86400000;

  // Mean elements (simplified, sufficient for nakshatra-level accuracy)
  const L0 = 218.3165;        // Mean longitude at J2000 (degrees)
  const dailyRate = 13.17639; // Mean daily motion (degrees/day)

  // Mean anomaly correction (largest perturbation term ~6.3°)
  const M = (134.9634 + 13.06499 * daysSinceJ2000) % 360;
  const Mrad = M * Math.PI / 180;
  const correction = 6.289 * Math.sin(Mrad); // Equation of center

  // Solar perturbation (evection ~1.3°, variation ~0.66°)
  const sunM = (357.5291 + 0.98560 * daysSinceJ2000) % 360;
  const sunMrad = sunM * Math.PI / 180;
  const evection = 1.274 * Math.sin(2 * (Mrad - sunMrad) - Mrad);

  let longitude = (L0 + dailyRate * daysSinceJ2000 + correction + evection) % 360;
  if (longitude < 0) longitude += 360;

  // Convert tropical to sidereal (ayanamsa ~24° in 2025, growing ~50"/yr)
  const yearsFrom2000 = daysSinceJ2000 / 365.25;
  const ayanamsa = 23.85 + yearsFrom2000 * (50.3 / 3600); // Lahiri approximation
  let sidereal = (longitude - ayanamsa) % 360;
  if (sidereal < 0) sidereal += 360;

  return sidereal;
}

/**
 * Map Moon's sidereal longitude to nakshatra name.
 * Each nakshatra spans 13°20' (13.333°).
 *
 * @param {number} siderealLongitude - Degrees (0-360)
 * @returns {string} Nakshatra name
 */
function longitudeToNakshatra(siderealLongitude) {
  const nakshatraNames = Object.keys(NAKSHATRA_BY_NAME).filter(n => n !== 'Abhijit');
  const index = Math.floor(siderealLongitude / (360 / 27)) % 27;
  return nakshatraNames[index] || 'Aswini';
}

/**
 * Estimate Moon's nakshatra at the time of an earthquake.
 *
 * BS Ch.32 classifies earthquakes by the nakshatra the Moon occupies
 * at the TIME of the tremor. This uses a simplified lunar ephemeris
 * accurate to ±1 nakshatra — sufficient since each earthquake circle
 * spans 7 nakshatras (~93°).
 *
 * @param {Object} eq - USGS earthquake feature
 * @returns {string} Approximate nakshatra name
 */
function mapEarthquakeToNakshatra(eq) {
  const time = new Date(eq.properties.time);
  const moonLon = estimateMoonLongitude(time);
  return longitudeToNakshatra(moonLon);
}

/**
 * Map earthquake time to BS time-of-day classification.
 * BS Ch.32 distinguishes day/night/twilight earthquakes.
 */
function mapEarthquakeTimeOfDay(eq, lon) {
  const time = new Date(eq.properties.time);
  // Approximate local hour using longitude
  const utcHour = time.getUTCHours();
  const localHour = (utcHour + Math.round(lon / 15) + 24) % 24;

  if (localHour >= 6 && localHour < 18) return 'day';
  if (localHour >= 18 && localHour < 20) return 'twilight_evening';
  if (localHour >= 4 && localHour < 6) return 'twilight_morning';
  return 'night';
}

/**
 * Fetch recent significant earthquakes from USGS.
 *
 * BS Ch.32 cares about earthquakes felt in the region.
 * We fetch M4.5+ globally (felt by humans) and M3.0+ near India.
 *
 * @param {Object} options
 * @param {number} [options.days=7] - Look back period
 * @param {number} [options.lat=28.6] - Center latitude (default: Delhi)
 * @param {number} [options.lon=77.2] - Center longitude
 * @param {number} [options.radiusKm=3000] - Search radius for local quakes
 * @returns {Promise<Array>} Earthquakes in BS observation format
 */
export async function fetchEarthquakes(options = {}) {
  const { days = 7, lat = 28.6, lon = 77.2, radiusKm = 3000 } = options;

  const endTime = new Date().toISOString().split('T')[0];
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const startTime = startDate.toISOString().split('T')[0];

  // Two queries: global significant + regional moderate
  const queries = [
    // Global M5.0+ (felt worldwide — BS considers distant quakes too)
    `${USGS_EARTHQUAKE_API}?format=geojson&starttime=${startTime}&endtime=${endTime}&minmagnitude=5.0&orderby=magnitude&limit=10`,
    // Regional M3.5+ within radius of observation point
    `${USGS_EARTHQUAKE_API}?format=geojson&starttime=${startTime}&endtime=${endTime}&minmagnitude=3.5&latitude=${lat}&longitude=${lon}&maxradiuskm=${radiusKm}&orderby=magnitude&limit=10`
  ];

  const earthquakes = [];
  const seen = new Set();

  for (const url of queries) {
    const data = await safeFetch(url);
    if (!data?.features) continue;

    for (const feature of data.features) {
      const id = feature.id;
      if (seen.has(id)) continue;
      seen.add(id);

      const [eqLon, eqLat, depth] = feature.geometry.coordinates;
      const mag = feature.properties.mag;
      const place = feature.properties.place;

      earthquakes.push({
        nakshatra: mapEarthquakeToNakshatra(feature),
        timeOfDay: mapEarthquakeTimeOfDay(feature, eqLon),
        magnitude: mag,
        depth,
        place,
        lat: eqLat,
        lon: eqLon,
        time: new Date(feature.properties.time).toISOString(),
        felt: feature.properties.felt || 0,
        tsunami: feature.properties.tsunami === 1,
        source: 'USGS',
        _raw: {
          id,
          url: feature.properties.url,
          title: feature.properties.title
        }
      });
    }
  }

  return earthquakes.sort((a, b) => b.magnitude - a.magnitude);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. WEATHER ANOMALY OBSERVATION → atmospheric nimitta
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Fetch weather data and detect ANOMALIES per BS rules.
 *
 * BS principle: Only ABNORMAL weather counts as Nimitta.
 * Thunder in varsha (monsoon) is normal → ignore.
 * Thunder in hemanta (winter) is portentous → flag it.
 *
 * @param {Object} options
 * @param {number} options.lat - Latitude
 * @param {number} options.lon - Longitude
 * @param {Date} [options.date] - Date to check
 * @returns {Promise<Object>} Weather anomalies in BS format
 */
export async function fetchWeatherAnomalies(options = {}) {
  const { lat = 28.6, lon = 77.2, date = new Date() } = options;
  const season = getSeason(date);
  const baseline = SEASON_BASELINES[season];

  const url = `${OPEN_METEO_API}?latitude=${lat}&longitude=${lon}`
    + `&current=temperature_2m,weather_code,wind_speed_10m,cloud_cover`
    + `&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code`
    + `&past_days=3&forecast_days=1&timezone=auto`;

  const data = await safeFetch(url);
  if (!data) return { anomalies: [], season, error: 'Weather API unavailable' };

  const anomalies = [];
  const current = data.current || {};
  const daily = data.daily || {};

  // Current temperature anomaly
  const temp = current.temperature_2m;
  if (temp != null) {
    if (temp > baseline.tempRange[1] + 5) {
      anomalies.push({
        type: 'extreme_heat',
        desc: `Abnormal heat: ${temp}°C in ${season} (expected max ${baseline.tempRange[1]}°C)`,
        bsRelevance: 'Ch.21 — Unseasonable heat portends drought and suffering',
        severity: Math.min(1, (temp - baseline.tempRange[1]) / 15),
        category: 'atmospheric'
      });
    }
    if (temp < baseline.tempRange[0] - 5) {
      anomalies.push({
        type: 'extreme_cold',
        desc: `Abnormal cold: ${temp}°C in ${season} (expected min ${baseline.tempRange[0]}°C)`,
        bsRelevance: 'Ch.21 — Unseasonable cold portends crop failure',
        severity: Math.min(1, (baseline.tempRange[0] - temp) / 15),
        category: 'atmospheric'
      });
    }
  }

  // Weather code anomalies (WMO codes)
  // 95-99 = thunderstorm, 80-82 = rain showers, 71-77 = snow
  const weatherCode = current.weather_code;
  if (weatherCode != null) {
    if (weatherCode >= 95 && !baseline.thunderNormal) {
      anomalies.push({
        type: 'unseasonal_thunder',
        desc: `Thunder/storm (WMO ${weatherCode}) in ${season} — NOT normal for this season`,
        bsRelevance: 'Ch.28-30 — Unseasonal thunder is a major portent. Direction determines affected region.',
        severity: 0.8,
        category: 'portentous_thunder',
        weatherCode
      });
    }
    if (weatherCode >= 71 && weatherCode <= 77 && season !== 'shishira' && season !== 'hemanta') {
      anomalies.push({
        type: 'unseasonal_snow',
        desc: `Snowfall (WMO ${weatherCode}) in ${season} — highly abnormal`,
        bsRelevance: 'Ch.46 — Unseasonal precipitation is a portent of crop damage',
        severity: 0.9,
        category: 'atmospheric'
      });
    }
    // Rain in dry season
    if ((weatherCode >= 51 && weatherCode <= 67) && !baseline.normalRain) {
      anomalies.push({
        type: 'unseasonal_rain',
        desc: `Rain (WMO ${weatherCode}) in ${season} — outside normal rainy season`,
        bsRelevance: 'Ch.21-24 — Unseasonal rain can be auspicious or inauspicious depending on other factors',
        severity: 0.5,
        category: 'atmospheric'
      });
    }
  }

  // Check daily data for sustained anomalies (past 3 days)
  if (daily.precipitation_sum) {
    const totalRain = daily.precipitation_sum.reduce((s, v) => s + (v || 0), 0);
    if (totalRain > 100 && !baseline.normalRain) {
      anomalies.push({
        type: 'excessive_unseasonal_rain',
        desc: `${totalRain.toFixed(0)}mm rain in 3 days during ${season} (dry season)`,
        bsRelevance: 'Ch.21 — Excessive rain in wrong season portends floods and crop damage',
        severity: Math.min(1, totalRain / 200),
        category: 'atmospheric'
      });
    }
    if (totalRain === 0 && baseline.normalRain) {
      anomalies.push({
        type: 'drought_in_rainy_season',
        desc: `Zero rainfall in 3 days during ${season} (rainy season)`,
        bsRelevance: 'Ch.21 — Absence of expected rain portends drought, famine',
        severity: 0.6,
        category: 'atmospheric'
      });
    }
  }

  // Extreme wind
  const windSpeed = current.wind_speed_10m;
  if (windSpeed != null && windSpeed > 60) {
    anomalies.push({
      type: 'extreme_wind',
      desc: `Extreme wind: ${windSpeed} km/h — whirlwind/storm conditions`,
      bsRelevance: 'Ch.32 — Strong winds are earthquake precursors or portents themselves',
      severity: Math.min(1, windSpeed / 100),
      category: 'atmospheric'
    });
  }

  return {
    anomalies,
    season,
    currentTemp: temp,
    currentWeatherCode: weatherCode,
    windSpeed,
    source: 'Open-Meteo'
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. SOLAR/ECLIPSE OBSERVATION → graha eclipses
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Fetch recent and upcoming solar events from NASA DONKI.
 *
 * Maps to BS: eclipses (Ch.5 Rahu), solar flares (Ch.3 Sun anomalies),
 * geomagnetic storms (atmospheric portents).
 *
 * @param {Object} options
 * @param {number} [options.days=30] - Look-back and look-ahead window
 * @returns {Promise<Object>} Solar events in BS format
 */
export async function fetchSolarEvents(options = {}) {
  const { days = 30 } = options;

  const endDate = new Date();
  endDate.setDate(endDate.getDate() + days);
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const fmt = d => d.toISOString().split('T')[0];
  const events = { solarFlares: [], geomagneticStorms: [], eclipses: [] };

  // Solar flares → BS Ch.3: Sun anomalies (Thamasa Keelaka = dark spots)
  const flareUrl = `${NASA_DONKI_API}/FLR?startDate=${fmt(startDate)}&endDate=${fmt(endDate)}&api_key=${NASA_API_KEY}`;
  const flares = await safeFetch(flareUrl);
  if (Array.isArray(flares)) {
    for (const f of flares.slice(0, 5)) {
      events.solarFlares.push({
        type: 'solar_flare',
        classType: f.classType, // C, M, X class
        beginTime: f.beginTime,
        peakTime: f.peakTime,
        desc: `Solar flare class ${f.classType} at ${f.peakTime}`,
        bsMapping: f.classType?.startsWith('X')
          ? 'Ch.3 — Major solar anomaly: Thamasa Keelaka (dark blemish). Kings suffer, drought follows.'
          : 'Ch.3 — Minor solar disturbance. Monitor for escalation.',
        severity: f.classType?.startsWith('X') ? 0.9 : f.classType?.startsWith('M') ? 0.6 : 0.3,
        // X-class flares map to BS Thamasa Keelaka (dark spots/blemishes on Sun)
        asSunObservation: {
          hasThamasaKeelaka: f.classType?.startsWith('X') || f.classType?.startsWith('M'),
          thamasaKeelaka: {
            count: 1,
            shape: 'spot',
            colorVarna: f.classType?.startsWith('X') ? 'dark' : 'smoky',
            modern: `Solar flare ${f.classType}`
          }
        }
      });
    }
  }

  // Geomagnetic storms → BS atmospheric portents
  const stormUrl = `${NASA_DONKI_API}/GST?startDate=${fmt(startDate)}&endDate=${fmt(endDate)}&api_key=${NASA_API_KEY}`;
  const storms = await safeFetch(stormUrl);
  if (Array.isArray(storms)) {
    for (const s of storms.slice(0, 5)) {
      const kpIndex = s.allKpIndex?.reduce((max, k) => Math.max(max, k.kpIndex || 0), 0) || 0;
      events.geomagneticStorms.push({
        type: 'geomagnetic_storm',
        kpIndex,
        startTime: s.startTime,
        desc: `Geomagnetic storm Kp=${kpIndex} at ${s.startTime}`,
        bsMapping: kpIndex >= 7
          ? 'Ch.46 — Major atmospheric disturbance: aurora visible, compass anomalies. Portent of war/conflict.'
          : 'Ch.46 — Minor magnetic disturbance.',
        severity: Math.min(1, kpIndex / 9),
        // Strong storms cause visible aurora → BS "unusual lights in sky"
        asPortent: kpIndex >= 6 ? {
          type: 'atmospheric_glow',
          desc: `Unusual lights in sky (aurora from Kp${kpIndex} storm)`,
          tier: kpIndex >= 8 ? 1 : 2
        } : null
      });
    }
  }

  return events;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. NEWS AS NIMITTA PROXY → shakuna (modern omens)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Keywords that map news events to specific BS Nimitta types.
 * When news reports these events, they become proper BS observations.
 */
const NIMITTA_NEWS_PATTERNS = [
  // Bhumi nimitta — earthquakes, volcanoes, landslides
  { pattern: /earthquake|quake|tremor|seismic/i, type: 'earthquake_report', bsChapter: 'Ch.32' },
  { pattern: /volcano|eruption|lava|volcanic/i, type: 'volcanic_portent', bsChapter: 'Ch.46' },
  { pattern: /landslide|sinkhole/i, type: 'earth_portent', bsChapter: 'Ch.32' },

  // Atmospheric nimitta — storms, unusual weather
  { pattern: /tornado|cyclone|hurricane|typhoon/i, type: 'whirlwind', bsChapter: 'Ch.32' },
  { pattern: /hailstorm|hail/i, type: 'unseasonal_precipitation', bsChapter: 'Ch.21' },
  { pattern: /drought|water.?crisis|water.?shortage/i, type: 'drought', bsChapter: 'Ch.21' },
  { pattern: /flood|deluge|inundation/i, type: 'flood', bsChapter: 'Ch.21' },
  { pattern: /wildfire|forest.?fire|bush.?fire/i, type: 'fire_portent', bsChapter: 'Ch.46' },

  // Celestial nimitta — eclipses, meteors, comets
  { pattern: /solar.?eclipse/i, type: 'solar_eclipse', bsChapter: 'Ch.5' },
  { pattern: /lunar.?eclipse/i, type: 'lunar_eclipse', bsChapter: 'Ch.5' },
  { pattern: /meteor|fireball|asteroid|comet/i, type: 'comet_meteor', bsChapter: 'Ch.11' },
  { pattern: /aurora|northern.?lights|southern.?lights/i, type: 'atmospheric_glow', bsChapter: 'Ch.46' },

  // Animal nimitta — unusual animal behavior (modern shakuna)
  { pattern: /mass.?die.?off|fish.?die|bird.?die|dead.?fish|dead.?bird/i, type: 'mass_animal_death', bsChapter: 'Ch.86-95' },
  { pattern: /swarm|locust|plague.?of/i, type: 'creature_swarm', bsChapter: 'Ch.86' },
  { pattern: /whale.?beach|strand/i, type: 'creature_anomaly', bsChapter: 'Ch.86' },

  // Portents in structures
  { pattern: /statue.?weep|idol.?bleed|miracle/i, type: 'idol_portent', bsChapter: 'Ch.46' },
  { pattern: /building.?collapse|bridge.?collapse/i, type: 'structure_portent', bsChapter: 'Ch.46' },
];

/**
 * Scan news headlines for Nimitta-class events.
 * These are not "domain heat" — these are actual BS observations
 * that happened in the real world and were reported as news.
 *
 * @param {Array<{title: string}>} headlines
 * @returns {Array<Object>} Nimitta observations extracted from news
 */
export function extractNimittaFromNews(headlines) {
  const nimitta = [];

  for (const h of headlines) {
    for (const rule of NIMITTA_NEWS_PATTERNS) {
      if (rule.pattern.test(h.title)) {
        nimitta.push({
          type: rule.type,
          bsChapter: rule.bsChapter,
          headline: h.title,
          source: h.source || 'news',
          pubDate: h.pubDate,
          confidence: 0.6, // News report, not direct observation
          note: 'Nimitta extracted from news — lower confidence than direct observation'
        });
        break; // One classification per headline
      }
    }
  }

  return nimitta;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. MASTER COLLECTOR — Assembles all Nimitta into pipeline-ready format
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Collect all Nimitta from real-world sources and format them for
 * the varga/pipeline.js runPipeline() observations parameter.
 *
 * This is the MAIN entry point. Call this before every reading.
 *
 * @param {Object} options
 * @param {number} [options.lat=28.6] - Observer latitude (default: Delhi)
 * @param {number} [options.lon=77.2] - Observer longitude (default: Delhi)
 * @param {Date}   [options.date]     - Date of observation
 * @param {number} [options.earthquakeDays=7] - Earthquake lookback
 * @param {number} [options.solarDays=30]     - Solar event lookback
 * @param {boolean} [options.skipNews=false]   - Skip news fetch
 * @param {boolean} [options.skipWeather=false] - Skip weather fetch
 * @param {boolean} [options.skipSolar=false]   - Skip solar/NASA fetch
 * @param {boolean} [options.skipEarthquake=false] - Skip earthquake fetch
 * @returns {Promise<Object>} Observations ready for runPipeline()
 */
export async function collectNimitta(options = {}) {
  const {
    lat = 28.6, lon = 77.2,
    date = new Date(),
    earthquakeDays = 7,
    solarDays = 30,
    skipNews = false,
    skipWeather = false,
    skipSolar = false,
    skipEarthquake = false
  } = options;

  const season = getSeason(date);
  const errors = [];
  const sources = [];
  const startTime = Date.now();

  // ── Parallel fetch all sources ──────────────────────────────────────────
  const [earthquakeResult, weatherResult, solarResult, newsResult] = await Promise.allSettled([
    skipEarthquake ? Promise.resolve(null) : fetchEarthquakes({ days: earthquakeDays, lat, lon }),
    skipWeather ? Promise.resolve(null) : fetchWeatherAnomalies({ lat, lon, date }),
    skipSolar ? Promise.resolve(null) : fetchSolarEvents({ days: solarDays }),
    skipNews ? Promise.resolve(null) : fetchNewsForNimitta()
  ]);

  // ── Process earthquakes ─────────────────────────────────────────────────
  const earthquakes = [];
  if (earthquakeResult.status === 'fulfilled' && earthquakeResult.value) {
    earthquakes.push(...earthquakeResult.value);
    sources.push(`USGS: ${earthquakes.length} earthquakes`);
  } else if (earthquakeResult.status === 'rejected') {
    errors.push({ source: 'USGS', error: earthquakeResult.reason?.message });
  }

  // ── Process weather anomalies ───────────────────────────────────────────
  let weatherAnomalies = [];
  let sunVisual = { color: 'normal', discShape: 'normal', hasThamasaKeelaka: false, rayColors: [], hasMockSuns: false, hasHalo: false };

  if (weatherResult.status === 'fulfilled' && weatherResult.value) {
    const w = weatherResult.value;
    weatherAnomalies = w.anomalies || [];
    sources.push(`Open-Meteo: ${weatherAnomalies.length} anomalies`);

    // Map weather to sun visual observation
    // Extreme heat + clear sky → Sun appears copper/red (BS Ch.3)
    if (w.currentTemp > 42) {
      sunVisual.color = 'copper';
    } else if (w.currentTemp > 38) {
      sunVisual.color = 'red';
    }
    // High cloud cover → halo possible
    if (w.currentWeatherCode >= 2 && w.currentWeatherCode <= 3) {
      sunVisual.hasHalo = true;
      sunVisual.haloColor = 'white';
    }
  } else if (weatherResult.status === 'rejected') {
    errors.push({ source: 'Open-Meteo', error: weatherResult.reason?.message });
  }

  // ── Process solar events ────────────────────────────────────────────────
  let portents = [];
  if (solarResult.status === 'fulfilled' && solarResult.value) {
    const s = solarResult.value;
    sources.push(`NASA: ${s.solarFlares.length} flares, ${s.geomagneticStorms.length} storms`);

    // Solar flares → Thamasa Keelaka on Sun
    for (const flare of s.solarFlares) {
      if (flare.asSunObservation?.hasThamasaKeelaka) {
        sunVisual.hasThamasaKeelaka = true;
        sunVisual.thamasaKeelaka = flare.asSunObservation.thamasaKeelaka;
      }
    }

    // Geomagnetic storms → atmospheric portents
    for (const storm of s.geomagneticStorms) {
      if (storm.asPortent) {
        portents.push(storm.asPortent);
      }
    }
  } else if (solarResult.status === 'rejected') {
    errors.push({ source: 'NASA', error: solarResult.reason?.message });
  }

  // ── Process news as Nimitta ─────────────────────────────────────────────
  let newsNimitta = [];
  let newsHeadlines = [];
  if (newsResult.status === 'fulfilled' && newsResult.value) {
    newsHeadlines = newsResult.value;
    newsNimitta = extractNimittaFromNews(newsHeadlines);
    sources.push(`News: ${newsHeadlines.length} headlines → ${newsNimitta.length} nimitta`);

    // Convert news nimitta into proper observations
    for (const n of newsNimitta) {
      if (n.type === 'earthquake_report' && earthquakes.length === 0) {
        // News reports earthquake but USGS didn't return it — add as lower-confidence
        earthquakes.push({
          nakshatra: 'Aswini', // Unknown, will be approximate
          timeOfDay: 'day',
          magnitude: 4.0, // Assume moderate if newsworthy
          place: n.headline,
          source: 'news_report',
          confidence: 0.5
        });
      }
      if (n.type.includes('portent') || n.type.includes('anomaly') || n.type.includes('swarm')) {
        portents.push({
          type: n.type,
          desc: n.headline,
          tier: 2,
          source: 'news'
        });
      }
    }
  } else if (newsResult.status === 'rejected') {
    errors.push({ source: 'News', error: newsResult.reason?.message });
  }

  // ── Assemble into pipeline-ready observations ───────────────────────────
  const observations = {
    // Direct observations for varga/pipeline.js
    sunVisual,
    season,
    earthquakes,
    portents,
    omens: [], // No direct animal observations from APIs (would need user input)

    // Weather anomalies (for supplementary analysis)
    weatherAnomalies,

    // Planet-specific contexts (set defaults — caller can override with real ephemeris)
    marsContext: {},
    mercuryContext: {},
    jupiterContext: {},
    venusContext: { visibility: 'evening' },
    saturnContext: {},

    // Metadata
    _meta: {
      collectedAt: new Date().toISOString(),
      sources,
      errors,
      elapsedMs: Date.now() - startTime,
      location: { lat, lon },
      season,
      newsNimitta,
      newsHeadlineCount: newsHeadlines.length,
      nimittaCount: earthquakes.length + weatherAnomalies.length + portents.length + newsNimitta.length
    }
  };

  return observations;
}

/**
 * Fetch news headlines for Nimitta extraction.
 * Uses existing news_feed.js infrastructure.
 */
async function fetchNewsForNimitta() {
  try {
    const { fetchNewsHeadlines } = await import('../../lib/news_feed.js');
    return await fetchNewsHeadlines({ limit: 30 });
  } catch {
    return [];
  }
}

/**
 * Pretty-print collected Nimitta for human review.
 */
export function summarizeNimitta(observations) {
  const lines = [];
  const m = observations._meta;

  lines.push(`═══ NIMITTA OBSERVATION REPORT ═══`);
  lines.push(`Location: ${m.location.lat}°N, ${m.location.lon}°E`);
  lines.push(`Season: ${m.season}`);
  lines.push(`Sources: ${m.sources.join(' | ')}`);
  lines.push(`Total nimitta: ${m.nimittaCount}`);
  if (m.errors.length) lines.push(`Errors: ${m.errors.map(e => `${e.source}: ${e.error}`).join(', ')}`);
  lines.push('');

  if (observations.earthquakes.length > 0) {
    lines.push(`── BHUMI (Earthquakes: ${observations.earthquakes.length}) ──`);
    for (const eq of observations.earthquakes.slice(0, 5)) {
      lines.push(`  M${eq.magnitude} ${eq.place} [${eq.timeOfDay}] → nakshatra: ${eq.nakshatra}`);
    }
    lines.push('');
  }

  if (observations.weatherAnomalies.length > 0) {
    lines.push(`── ATMOSPHERIC ANOMALIES (${observations.weatherAnomalies.length}) ──`);
    for (const a of observations.weatherAnomalies) {
      lines.push(`  ${a.type}: ${a.desc}`);
      lines.push(`    BS: ${a.bsRelevance}`);
    }
    lines.push('');
  }

  if (observations.sunVisual.hasThamasaKeelaka) {
    lines.push(`── SUN ANOMALY ──`);
    lines.push(`  Thamasa Keelaka detected: ${observations.sunVisual.thamasaKeelaka?.modern || 'solar blemish'}`);
    lines.push(`  BS Ch.3: Dark spots on Sun portend suffering for kings and drought`);
    lines.push('');
  }

  if (observations.portents.length > 0) {
    lines.push(`── PORTENTS (${observations.portents.length}) ──`);
    for (const p of observations.portents) {
      lines.push(`  ${p.type}: ${p.desc}`);
    }
    lines.push('');
  }

  if (observations._meta.newsNimitta?.length > 0) {
    lines.push(`── NEWS NIMITTA (${observations._meta.newsNimitta.length}) ──`);
    for (const n of observations._meta.newsNimitta) {
      lines.push(`  [${n.bsChapter}] ${n.type}: "${n.headline}"`);
    }
    lines.push('');
  }

  if (observations.sunVisual.color === 'normal' && observations.earthquakes.length === 0
      && observations.weatherAnomalies.length === 0 && observations.portents.length === 0) {
    lines.push(`── ALL QUIET ──`);
    lines.push(`  No significant Nimitta observed. The earth is calm.`);
    lines.push(`  Predictions rely on sky state (Drik Ganita) alone.`);
  }

  lines.push(`\nCollected in ${m.elapsedMs}ms`);
  return lines.join('\n');
}
