import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { HOLYCOW_AI_USER_ID } from "../lib/constants.js";

/**
 * Daily News Digest - AI Agent Posts
 * 
 * Generates and posts a daily news digest as the AI profile.
 * Posts appear in globalFeed for discovery.
 * 
 * Schedule: Daily at 8 AM IST
 * Format: One post with 7-10 top news stories with source citations
 */
export const generateDailyNewsDigest = onSchedule({
    schedule: "0 8 * * *", // 8 AM IST daily
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    memory: "512MiB",
    timeoutSeconds: 300,
    secrets: [geminiApiKey],
}, async (event) => {
    logger.info("📰 Starting daily news digest generation", {
        structuredData: true,
        timestamp: new Date().toISOString(),
    });

    try {
        // Ensure AI user exists
        await ensureAiUserExists();

        // Generate news digest
        const digest = await generateNewsDigest();

        if (!digest || !digest.content) {
            logger.warn("No digest content generated, skipping post");
            return;
        }

        // Create post
        const postId = await createDigestPost(digest);

        logger.info("✅ Daily news digest posted successfully", {
            structuredData: true,
            postId,
            contentLength: digest.content.length,
            sourceCount: digest.sources?.length || 0,
        });

        return { success: true, postId };
    } catch (error) {
        logger.error("❌ Failed to generate daily news digest", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

/**
 * Ensure AI user profile exists
 */
async function ensureAiUserExists() {
    const userRef = db.collection("users").doc(HOLYCOW_AI_USER_ID);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        logger.info("Creating AI user profile", {
            structuredData: true,
            userId: HOLYCOW_AI_USER_ID,
        });

        await userRef.set({
            name: "HolyCow AI",
            displayPicture: "https://aurogram.in/assets/images/cow1.png",
            bio: "Your friendly AI community member. Here to help and share what's happening!",
            isAi: true,
            isPrivateProfile: false, // Public so posts appear in globalFeed
            followerCount: 0,
            followingCount: 0,
            auraScore: 0,
            timestamp: FieldValue.serverTimestamp(),
        }, { merge: false });

        logger.info("AI user profile created", {
            structuredData: true,
            userId: HOLYCOW_AI_USER_ID,
        });
    } else {
        // Ensure profile is public and has display picture
        await userRef.update({
            isPrivateProfile: false,
            isAi: true,
            displayPicture: "https://aurogram.in/assets/images/cow1.png",
        });
    }
}

/**
 * Generate news digest using Gemini + Google Search with source citations
 */
async function generateNewsDigest() {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        tools: [{ googleSearch: {} }],
        generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 3000, // Increased for more stories
        },
    });

    const today = new Date().toLocaleDateString("en-US", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric",
    });

    const prompt = `You are a helpful AI assistant creating a daily news digest for a social media app with primarily Indian users.

Today is ${today}.

Generate a concise daily news digest with ONLY the 4-5 MOST IMPORTANT stories of the day. Focus on quality over quantity - only truly significant news.

LOCATION FOCUS:
- Prioritize news from India and South Asia (3-4 stories)
- Include 1-2 highly relevant global stories (major world events, significant tech/business news)
- Focus on stories that truly matter to Indian audiences

REQUIREMENTS:
- Start with a friendly greeting (e.g., "Good morning! Here's what's happening today...")
- Include ONLY 4-5 top stories (prioritize importance and impact)
- Each story: Brief headline + 1-2 sentence summary
- Use numbered list format (1., 2., 3., etc.)
- For EACH story, include a markdown link to the source article: [Headline](source_url)
- Keep it conversational and engaging
- End with a question or call to action
- Total length: 250-350 words (concise and focused)
- Use Google Search to get current, real-time news
- Select stories based on importance, not just recency

FORMAT EXAMPLE:
"Good morning! 📰 Here's what's happening today:

1. [Headline](source_url) - [Brief summary]

2. [Headline](source_url) - [Brief summary]

3. [Headline](source_url) - [Brief summary]

4. [Headline](source_url) - [Brief summary]

What caught your attention today?"

IMPORTANT: Include actual source URLs as markdown links for each story. Use Google Search to find the real article URLs.

Generate the digest now:`;

    try {
        const result = await model.generateContent(prompt);
        const response = result.response;
        const content = response.text();

        if (!content || content.trim().length === 0) {
            throw new Error("Empty response from Gemini");
        }

        // Extract source URLs from grounding metadata for reference
        const sources = [];
        try {
            const candidates = response.candidates;
            if (candidates && candidates.length > 0) {
                const candidate = candidates[0];
                const groundingMetadata = candidate.groundingMetadata;
                
                if (groundingMetadata) {
                    // Extract search queries used
                    const searchQueries = groundingMetadata.webSearchQueries || [];
                    
                    // Extract source URLs - keep all unique sources
                    const groundingChunks = groundingMetadata.groundingChunks || [];
                    
                    for (const chunk of groundingChunks) {
                        if (chunk.web && chunk.web.uri) {
                            try {
                                const url = new URL(chunk.web.uri);
                                sources.push({
                                    title: chunk.web.title || url.hostname,
                                    url: chunk.web.uri,
                                    domain: url.hostname.replace('www.', ''),
                                });
                            } catch (urlError) {
                                // Skip invalid URLs
                                logger.warn("Invalid source URL", {
                                    structuredData: true,
                                    url: chunk.web.uri,
                                });
                            }
                        }
                    }
                    
                    logger.info("Extracted source URLs from grounding", {
                        structuredData: true,
                        sourceCount: sources.length,
                        searchQueries: searchQueries.length,
                    });
                }
            }
        } catch (metadataError) {
            logger.warn("Could not extract grounding metadata", {
                structuredData: true,
                error: String(metadataError),
            });
        }

        // Content should already have markdown links from Gemini
        // If not, we'll enhance it with available sources
        let finalContent = content.trim();
        
        // Check if content already has markdown links (Gemini should have added them)
        const hasMarkdownLinks = /\[.*?\]\(https?:\/\/.+?\)/.test(finalContent);
        
        if (!hasMarkdownLinks && sources.length > 0) {
            // If Gemini didn't add links, try to add them manually
            // Extract numbered list items and try to match with sources
            const storyPattern = /(\d+\.\s+\*\*[^*]+\*\*)/g;
            const stories = finalContent.match(storyPattern) || [];
            
            if (stories.length > 0 && stories.length <= sources.length) {
                // Try to match stories with sources
                for (let i = 0; i < Math.min(stories.length, sources.length); i++) {
                    const storyText = stories[i];
                    const source = sources[i];
                    // Replace headline with linked version
                    const headlineMatch = storyText.match(/\*\*([^*]+)\*\*/);
                    if (headlineMatch && source.url) {
                        const headline = headlineMatch[1];
                        const linkedHeadline = `[${headline}](${source.url})`;
                        finalContent = finalContent.replace(
                            new RegExp(`\\*\\*${headline.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\*\\*`),
                            linkedHeadline
                        );
                    }
                }
                
                logger.info("Added markdown links to stories", {
                    structuredData: true,
                    storiesLinked: Math.min(stories.length, sources.length),
                });
            }
        }
        
        // Store sources in metadata for reference
        logger.info("Final digest content", {
            structuredData: true,
            contentLength: finalContent.length,
            hasMarkdownLinks: /\[.*?\]\(https?:\/\/.+?\)/.test(finalContent),
            sourceCount: sources.length,
        });

        return {
            content: finalContent,
            sources: sources,
            generatedAt: new Date().toISOString(),
        };
    } catch (error) {
        logger.error("Failed to generate news digest", {
            structuredData: true,
            error: String(error),
        });
        throw error;
    }
}

/**
 * Create post document with digest content
 */
async function createDigestPost(digest) {
    const postId = db.collection("posts").doc().id;

    // Extract primary link (first story's link or first available source)
    let primaryLink = null;
    if (digest.sources && digest.sources.length > 0) {
        // Try to extract first markdown link from content
        const markdownLinkMatch = digest.content.match(/\[.*?\]\((https?:\/\/[^\)]+)\)/);
        if (markdownLinkMatch) {
            primaryLink = markdownLinkMatch[1];
        } else {
            // Fallback to first source URL
            primaryLink = digest.sources[0].url;
        }
    }

    const postData = {
        author: HOLYCOW_AI_USER_ID,
        contextType: "profile",
        space: HOLYCOW_AI_USER_ID, // Profile posts use author ID as space
        title: "Today's News Digest",
        content: digest.content,
        postType: "text",
        link: primaryLink, // Primary link for the post (first story or first source)
        timestamp: FieldValue.serverTimestamp(),
        uploading: false,
        replyCount: 0,
        likeCount: 0,
        repostCount: 0,
        // Metadata
        _aiGenerated: true,
        _digestDate: new Date().toISOString().split("T")[0],
        _sources: digest.sources || [], // Store all source URLs for reference
    };

    // Create post in main posts collection (source of truth)
    await db.collection("posts").doc(postId).set(postData);

    // Also add to userPosts collection (for profile queries - matches client pattern)
    await db.collection("userPosts")
        .doc(HOLYCOW_AI_USER_ID)
        .collection("posts")
        .doc(postId)
        .set({
            author: HOLYCOW_AI_USER_ID,
            title: postData.title,
            content: postData.content,
            postType: "text",
            contextType: "profile",
            timestamp: FieldValue.serverTimestamp(),
        });

    // Update user's post count
    await db.collection("userPosts").doc(HOLYCOW_AI_USER_ID).set({
        updated: FieldValue.serverTimestamp(),
        postCount: FieldValue.increment(1),
    }, { merge: true });

    logger.info("Digest post created", {
        structuredData: true,
        postId,
        contentLength: digest.content.length,
    });

    return postId;
}

/**
 * Manual trigger for testing daily digest generation
 * Call this function to test without waiting for schedule
 */
export const testDailyNewsDigest = onCall({
    region: "asia-southeast2",
    secrets: [geminiApiKey],
}, async (request) => {
    // Only allow in development or with admin check
    const isDevelopment = process.env.FUNCTIONS_EMULATOR === "true";
    
    if (!isDevelopment) {
        // In production, you might want to add admin check here
        // For now, allow manual testing
    }

    logger.info("🧪 Manual test trigger for daily news digest", {
        structuredData: true,
        caller: request.auth?.uid || "anonymous",
    });

    try {
        // Reuse the same logic as scheduled function
        await ensureAiUserExists();
        const digest = await generateNewsDigest();

        if (!digest || !digest.content) {
            return { success: false, error: "No digest content generated" };
        }

        const postId = await createDigestPost(digest);

        return {
            success: true,
            postId,
            contentLength: digest.content.length,
            message: "Daily digest posted successfully",
        };
    } catch (error) {
        logger.error("❌ Manual test failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        return {
            success: false,
            error: error.message,
        };
    }
});
