import test from "node:test";
import assert from "node:assert/strict";
import {
    isWorkflowMutation,
    workflowMutationRejection,
} from "../src/workflow_turn_guard.js";

test("allows one workflow mutation from a fresh user audio turn", () => {
    assert.equal(
        workflowMutationRejection("advanceOnboarding", "audio", true, 0),
        null,
    );
});

test("rejects workflow recursion from a tool-result continuation", () => {
    assert.equal(
        workflowMutationRejection("advanceOnboarding", "toolResult", false, 0),
        "recursive_action_chain",
    );
});

test("rejects a second workflow mutation in the same user turn", () => {
    assert.equal(
        workflowMutationRejection("advanceOnboarding", "audio", true, 1),
        "recursive_action_chain",
    );
});

test("does not constrain unrelated non-workflow tools", () => {
    assert.equal(workflowMutationRejection("whereAmI", "toolResult", false, 99), null);
    assert.equal(isWorkflowMutation("whereAmI"), false);
});
