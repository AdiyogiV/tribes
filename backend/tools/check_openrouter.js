// Test OpenRouter API directly
import fetch from "node-fetch";
import { execSync } from "child_process";

async function test() {
    try {
        const apiKey = execSync("gcloud secrets versions access latest --secret=OPENROUTER_API_KEY --project=ty-dev-516d7", {
            encoding: "utf8",
        }).trim();

        console.log("📤 Testing OpenRouter API...");
        const startTime = Date.now();

        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${apiKey}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://tribes.app",
                "X-Title": "Tribes AI Chat",
            },
            body: JSON.stringify({
                model: "deepseek/deepseek-chat",
                messages: [{ role: "user", content: "Hi" }],
                temperature: 0.7,
                max_tokens: 100,
            }),
            signal: AbortSignal.timeout(10000),
        });

        const duration = Date.now() - startTime;
        console.log(`📡 Response: ${response.status} (${duration}ms)`);

        if (response.ok) {
            const data = await response.json();
            console.log("✅ Success!");
        } else {
            console.log("❌ Error:", await response.text());
        }
    } catch (error) {
        console.log("❌ Failed:", error.message);
    }
}

test();


