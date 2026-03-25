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
