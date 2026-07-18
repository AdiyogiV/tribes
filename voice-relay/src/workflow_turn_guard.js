const WORKFLOW_MUTATION_TOOLS = new Set(["advanceOnboarding"]);

export function isWorkflowMutation(name) {
    return WORKFLOW_MUTATION_TOOLS.has(name);
}

/// Only a fresh user audio turn may perform one workflow mutation. A tool
/// result is a continuation of the same action chain, never a new opportunity.
export function workflowMutationRejection(name, turnKind, userSpoke, count) {
    if (!isWorkflowMutation(name)) return null;
    if (turnKind !== "audio" || !userSpoke || count > 0) {
        return "recursive_action_chain";
    }
    return null;
}
