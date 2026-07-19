import test, { before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rulesPath = join(__dirname, "..", "firestore.rules");
const rules = readFileSync(rulesPath, "utf8");

const projectId = "tribes-rules-test";
let testEnv;

const getAuthedDb = (uid) => testEnv.authenticatedContext(uid).firestore();
const getAnonDb = () => testEnv.unauthenticatedContext().firestore();

async function setDoc(path, data) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(path).set(data);
    });
}

before(async () => {
    testEnv = await initializeTestEnvironment({
        projectId,
        firestore: { rules },
    });
});

after(async () => {
    await testEnv.cleanup();
});

beforeEach(async () => {
    await testEnv.clearFirestore();
});

test("public profile is readable without auth", async () => {
    await setDoc("users/publicUser", { isPrivateProfile: false });
    await assertSucceeds(getAnonDb().doc("users/publicUser").get());
});

test("private profile blocks unauthenticated read", async () => {
    await setDoc("users/privateUser", { isPrivateProfile: true });
    await assertFails(getAnonDb().doc("users/privateUser").get());
});

test("private profile allows follower read", async () => {
    await setDoc("users/privateUser", { isPrivateProfile: true });
    await setDoc("userFollowers/privateUser/followers/followerUser", {
        createdAt: Date.now(),
    });

    await assertSucceeds(getAuthedDb("followerUser").doc("users/privateUser").get());
});

test("private space post read requires membership", async () => {
    await setDoc("spaces/spacePrivate", { spaceType: 2 });
    await setDoc("posts/postPrivate", {
        author: "authorUser",
        contextType: "space",
        contextId: "spacePrivate",
    });

    await assertFails(getAnonDb().doc("posts/postPrivate").get());
    await assertFails(getAuthedDb("randomUser").doc("posts/postPrivate").get());

    await setDoc("spaceRoles/spacePrivate/roles/memberUser", {
        role: "member",
    });

    await assertSucceeds(getAuthedDb("memberUser").doc("posts/postPrivate").get());
});

// ── Conversation confidentiality (dmConversations / spaceChats / spaces) ──────
// All human messages live in the flat `spaceChats` collection keyed by a
// `spaceId` field (a DM id "dm_a_b" / "ai_chat_..." or a space id). DM ids embed
// their members; space membership comes from spaceRoles.

test("DM conversation metadata: only participants can read", async () => {
    await setDoc("dmConversations/dm_alice_bob", {
        participants: ["alice", "bob"],
        lastMessage: { content: "secret preview" },
    });
    await assertSucceeds(getAuthedDb("alice").doc("dmConversations/dm_alice_bob").get());
    await assertSucceeds(getAuthedDb("bob").doc("dmConversations/dm_alice_bob").get());
    await assertFails(getAuthedDb("carol").doc("dmConversations/dm_alice_bob").get());
    await assertFails(getAnonDb().doc("dmConversations/dm_alice_bob").get());
});

test("DM conversation: existence-check read of a non-existent doc is allowed", async () => {
    // createDirectMessage() does a get() BEFORE writing to see if the DM exists.
    // Reading a not-yet-created doc must NOT be permission-denied, otherwise every
    // brand-new chat breaks. Nothing to leak from a doc that doesn't exist.
    await assertSucceeds(getAuthedDb("alice").doc("dmConversations/dm_alice_zoe").get());
});

test("spaceChats DM message: participants read, outsiders denied", async () => {
    await setDoc("spaceChats/m1", { spaceId: "dm_alice_bob", senderId: "alice", content: "hi" });
    await assertSucceeds(getAuthedDb("alice").doc("spaceChats/m1").get());
    await assertSucceeds(getAuthedDb("bob").doc("spaceChats/m1").get());
    await assertFails(getAuthedDb("carol").doc("spaceChats/m1").get());
});

test("spaceChats DM message: 'bob' is not confused with 'bobby'", async () => {
    // dm_alice_bobby must NOT be readable by 'bob' (suffix/prefix regex safety).
    await setDoc("spaceChats/m2", { spaceId: "dm_alice_bobby", senderId: "alice", content: "hi" });
    await assertFails(getAuthedDb("bob").doc("spaceChats/m2").get());
    await assertSucceeds(getAuthedDb("bobby").doc("spaceChats/m2").get());
});

test("spaceChats DM create: only as self, only into own conversation", async () => {
    // participant posting as themselves → ok
    await assertSucceeds(getAuthedDb("alice").collection("spaceChats").add(
        { spaceId: "dm_alice_bob", senderId: "alice", content: "hi" }));
    // spoofed senderId → denied
    await assertFails(getAuthedDb("alice").collection("spaceChats").add(
        { spaceId: "dm_alice_bob", senderId: "bob", content: "spoof" }));
    // outsider injecting into someone else's DM → denied
    await assertFails(getAuthedDb("carol").collection("spaceChats").add(
        { spaceId: "dm_alice_bob", senderId: "carol", content: "inject" }));
});

test("spaceChats space message: read honours public + membership", async () => {
    await setDoc("spaces/privSpace", { spaceType: 2 });
    await setDoc("spaces/pubSpace", { spaceType: 1 });
    await setDoc("spaceRoles/privSpace/roles/member1", { role: "member" });
    await setDoc("spaceChats/mp", { spaceId: "privSpace", senderId: "member1", content: "yo" });
    await setDoc("spaceChats/mpub", { spaceId: "pubSpace", senderId: "member1", content: "yo" });

    await assertSucceeds(getAuthedDb("member1").doc("spaceChats/mp").get());
    await assertFails(getAuthedDb("outsider").doc("spaceChats/mp").get());
    // public space chat readable by any signed-in user
    await assertSucceeds(getAuthedDb("outsider").doc("spaceChats/mpub").get());
});

test("spaceChats space create: requires membership", async () => {
    await setDoc("spaces/privSpace", { spaceType: 2 });
    await setDoc("spaceRoles/privSpace/roles/member1", { role: "member" });
    await assertSucceeds(getAuthedDb("member1").collection("spaceChats").add(
        { spaceId: "privSpace", senderId: "member1", content: "hi" }));
    await assertFails(getAuthedDb("outsider").collection("spaceChats").add(
        { spaceId: "privSpace", senderId: "outsider", content: "hi" }));
});

test("AI/Baba chat messages: only the owning user can read", async () => {
    await setDoc("dmConversations/ai_chat_alice_1700000000000/messages/msg1", {
        content: "your private reading", senderId: "holycow_system_user",
    });
    await assertSucceeds(
        getAuthedDb("alice").doc("dmConversations/ai_chat_alice_1700000000000/messages/msg1").get());
    await assertFails(
        getAuthedDb("bob").doc("dmConversations/ai_chat_alice_1700000000000/messages/msg1").get());
});

test("DM subcollection messages: participant reads, outsider denied", async () => {
    await setDoc("dmConversations/dm_alice_bob/messages/n1", { content: "namaste" });
    await assertSucceeds(getAuthedDb("alice").doc("dmConversations/dm_alice_bob/messages/n1").get());
    await assertFails(getAuthedDb("carol").doc("dmConversations/dm_alice_bob/messages/n1").get());
});

test("space subcollection messages: read public/member, write member-only", async () => {
    await setDoc("spaces/privSpace", { spaceType: 2 });
    await setDoc("spaceRoles/privSpace/roles/member1", { role: "member" });
    await setDoc("spaces/privSpace/messages/gc1", { messageType: "group_call", senderId: "member1" });

    await assertSucceeds(getAuthedDb("member1").doc("spaces/privSpace/messages/gc1").get());
    await assertFails(getAuthedDb("outsider").doc("spaces/privSpace/messages/gc1").get());
    await assertSucceeds(getAuthedDb("member1").collection("spaces/privSpace/messages").add(
        { messageType: "group_call", senderId: "member1" }));
    await assertFails(getAuthedDb("outsider").collection("spaces/privSpace/messages").add(
        { messageType: "group_call", senderId: "outsider" }));
});

test("Baba durable memory: owner-only", async () => {
    await setDoc("users/alice/memory/profile", { rollingSummary: "likes tea" });
    await assertSucceeds(getAuthedDb("alice").doc("users/alice/memory/profile").get());
    await assertFails(getAuthedDb("bob").doc("users/alice/memory/profile").get());
    await assertSucceeds(getAuthedDb("alice").doc("users/alice/memory/profile").set({ x: 1 }));
    await assertFails(getAuthedDb("bob").doc("users/alice/memory/profile").set({ x: 1 }));
});

test("Unified forecast: owner reads, client cannot write (backend-only)", async () => {
    await setDoc("users/alice/forecast/2026-07", { period: "2026-07", days: [] });
    await assertSucceeds(getAuthedDb("alice").doc("users/alice/forecast/2026-07").get());
    await assertFails(getAuthedDb("bob").doc("users/alice/forecast/2026-07").get());
    // Only the backend (Admin SDK) may write — even the owner is denied.
    await assertFails(getAuthedDb("alice").doc("users/alice/forecast/2026-07").set({ x: 1 }));
});
