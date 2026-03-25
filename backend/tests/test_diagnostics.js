/**
 * Comprehensive Diagnostics Test
 * Tests code structure, imports, and identifies issues
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const issues = [];
const warnings = [];
const passed = [];

function checkIssue(condition, message, isWarning = false) {
    if (!condition) {
        if (isWarning) {
            warnings.push(message);
            console.log(`⚠️  ${message}`);
        } else {
            issues.push(message);
            console.log(`❌ ${message}`);
        }
    } else {
        passed.push(message);
        console.log(`✅ ${message}`);
    }
}

async function testCodeStructure() {
    console.log("\n🔍 Testing Code Structure...\n");
    
    try {
        const filePath = join(__dirname, 'functions', 'daily_astro_insights.js');
        const code = readFileSync(filePath, 'utf-8');
        
        // Check for syntax errors
        checkIssue(
            code.includes('calculateHouseActivations('),
            'calculateHouseActivations is called correctly',
            false
        );
        
        // Check for missing function calls
        checkIssue(
            !code.includes('calculateHouseActivations;') || code.includes('calculateHouseActivations('),
            'calculateHouseActivations is invoked (not just referenced)',
            false
        );
        
        // Check for proper exports
        checkIssue(
            code.includes('export const generateInsightForCurrentUser'),
            'generateInsightForCurrentUser is exported',
            false
        );
        
        checkIssue(
            code.includes('export const generateDailyAstroInsights'),
            'generateDailyAstroInsights is exported',
            false
        );
        
        // Check for required imports
        checkIssue(
            code.includes('from "./cache_utils.js"'),
            'cache_utils.js is imported',
            false
        );
        
        checkIssue(
            code.includes('from "./vedic_analysis.js"'),
            'vedic_analysis.js is imported',
            false
        );
        
        // Check for error handling
        checkIssue(
            code.includes('try {') && code.includes('catch'),
            'Error handling present',
            false
        );
        
        // Check for date field
        checkIssue(
            code.includes('date: today') || code.includes('date:'),
            'Date field is set in insight data',
            false
        );
        
        // Check for notification creation
        checkIssue(
            code.includes('collection("notifications")'),
            'Notification creation logic present',
            false
        );
        
        // Check for house activations in notification
        checkIssue(
            code.includes('houseActivations:') || code.includes('scoredHouseActivations'),
            'House activations included in notification',
            true // Warning, not critical
        );
        
    } catch (error) {
        issues.push(`Code structure check failed: ${error.message}`);
        console.log(`❌ Code structure check failed: ${error.message}`);
    }
}

async function testImports() {
    console.log("\n🔍 Testing Imports...\n");
    
    try {
        // Test cache_utils imports
        const cacheUtils = await import('./functions/cache_utils.js');
        checkIssue(
            typeof cacheUtils.generateChartSignature === 'function',
            'generateChartSignature imported',
            false
        );
        checkIssue(
            typeof cacheUtils.getCachedTransitData === 'function',
            'getCachedTransitData imported',
            false
        );
        checkIssue(
            typeof cacheUtils.cacheAIInsight === 'function',
            'cacheAIInsight imported',
            false
        );
        
        // Test vedic_analysis imports
        const vedicAnalysis = await import('./functions/vedic_analysis.js');
        checkIssue(
            typeof vedicAnalysis.calculateHouseActivations === 'function',
            'calculateHouseActivations imported',
            false
        );
        checkIssue(
            typeof vedicAnalysis.calculateTransitAspects === 'function',
            'calculateTransitAspects imported',
            false
        );
        checkIssue(
            typeof vedicAnalysis.scoreHouseActivations === 'function',
            'scoreHouseActivations imported',
            false
        );
        
    } catch (error) {
        issues.push(`Import test failed: ${error.message}`);
        console.log(`❌ Import test failed: ${error.message}`);
    }
}

async function testFunctionLogic() {
    console.log("\n🔍 Testing Function Logic...\n");
    
    try {
        const filePath = join(__dirname, 'functions', 'daily_astro_insights.js');
        const code = readFileSync(filePath, 'utf-8');
        
        // Check if generateInsightForUser function exists
        checkIssue(
            code.includes('async function generateInsightForUser'),
            'generateInsightForUser function defined',
            false
        );
        
        // Check if it's called correctly
        checkIssue(
            code.includes('await generateInsightForUser('),
            'generateInsightForUser is called with await',
            false
        );
        
        // Check for proper data structure
        checkIssue(
            code.includes('astrologicalData: {'),
            'astrologicalData object structure present',
            false
        );
        
        // Check for house activations in stored data
        checkIssue(
            code.includes('houseActivations:') && code.includes('scoredHouseActivations'),
            'House activations stored in insight data',
            false
        );
        
        // Check for aspects in stored data
        checkIssue(
            code.includes('significantAspects:') && code.includes('scoredAspects'),
            'Aspects stored in insight data',
            false
        );
        
    } catch (error) {
        issues.push(`Function logic test failed: ${error.message}`);
        console.log(`❌ Function logic test failed: ${error.message}`);
    }
}

async function testDataFlow() {
    console.log("\n🔍 Testing Data Flow...\n");
    
    try {
        const filePath = join(__dirname, 'functions', 'daily_astro_insights.js');
        const code = readFileSync(filePath, 'utf-8');
        
        // Check flow: getTodayAstroData -> calculateHouseActivations -> scoreHouseActivations
        const hasTransitFlow = code.includes('getTodayAstroData') && 
                               code.includes('calculateHouseActivations') &&
                               code.includes('scoreHouseActivations');
        checkIssue(hasTransitFlow, 'Transit data flow complete', false);
        
        // Check flow: calculateTransitAspects -> scoreAspects
        const hasAspectFlow = code.includes('calculateTransitAspects') &&
                             code.includes('scoreAspects');
        checkIssue(hasAspectFlow, 'Aspect calculation flow complete', false);
        
        // Check AI generation flow
        const hasAIFlow = code.includes('generateInsightWithAI') &&
                         code.includes('cacheAIInsight');
        checkIssue(hasAIFlow, 'AI generation and caching flow complete', false);
        
        // Check storage flow
        const hasStorageFlow = code.includes('insightRef.set') &&
                              code.includes('notificationRef.set');
        checkIssue(hasStorageFlow, 'Storage flow complete', false);
        
    } catch (error) {
        issues.push(`Data flow test failed: ${error.message}`);
        console.log(`❌ Data flow test failed: ${error.message}`);
    }
}

async function generateReport() {
    console.log("\n" + "=".repeat(60));
    console.log("📊 Diagnostics Report");
    console.log("=".repeat(60));
    console.log(`✅ Passed: ${passed.length}`);
    console.log(`❌ Issues: ${issues.length}`);
    console.log(`⚠️  Warnings: ${warnings.length}`);
    console.log("=".repeat(60));
    
    if (issues.length > 0) {
        console.log("\n❌ CRITICAL ISSUES:");
        issues.forEach((issue, i) => {
            console.log(`   ${i + 1}. ${issue}`);
        });
    }
    
    if (warnings.length > 0) {
        console.log("\n⚠️  WARNINGS:");
        warnings.forEach((warning, i) => {
            console.log(`   ${i + 1}. ${warning}`);
        });
    }
    
    if (issues.length === 0 && warnings.length === 0) {
        console.log("\n✅ No issues found! Code structure looks good.");
    }
    
    // Save report
    const fs = await import('fs');
    const report = {
        timestamp: new Date().toISOString(),
        summary: {
            passed: passed.length,
            issues: issues.length,
            warnings: warnings.length,
        },
        passed,
        issues,
        warnings,
    };
    
    fs.writeFileSync('diagnostics_report.json', JSON.stringify(report, null, 2));
    console.log("\n📄 Report saved to diagnostics_report.json");
    
    return issues.length === 0;
}

async function runDiagnostics() {
    console.log("🚀 Running Comprehensive Diagnostics...\n");
    console.log("=".repeat(60));
    
    await testCodeStructure();
    await testImports();
    await testFunctionLogic();
    await testDataFlow();
    
    const success = await generateReport();
    
    if (success) {
        console.log("\n✅ Diagnostics complete. No critical issues found!");
        process.exit(0);
    } else {
        console.log(`\n❌ Diagnostics complete. Found ${issues.length} critical issue(s).`);
        process.exit(1);
    }
}

runDiagnostics();



