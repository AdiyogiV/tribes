/**
 * Canonical CX Function-tool specs for Baba.
 *
 * WHY THIS EXISTS (and why it looks duplicated): the Flutter client declares
 * these same tools in Dart (lib/features/baba/domain/baba_tool_catalog.dart +
 * lib/features/onboarding/domain/baba_onboarding_tools.dart). The Live engine
 * takes those declarations streamed per-session. CX is different: its tools
 * live ON THE AGENT, provisioned ahead of time. So the server side needs its
 * own copy of the schemas to provision them. Two runtimes => two declarations.
 *
 * KEEP IN SYNC with the Dart declarations. The `name` MUST match the client's
 * tool name exactly — that's the whole trick that lets the client's
 * BabaToolRegistry dispatch a CX tool call with no client changes: we set each
 * CX tool's displayName to `name`, and CX's ToolCall.action comes back as that
 * same name.
 */

export const BABA_TOOL_SPECS = [
  {
    name: "navigateTo",
    description:
      "Take the user to one of the app's main screens. Use when they ask to " +
      "go somewhere, or when guiding them there yourself.",
    inputSchema: {
      type: "object",
      properties: {
        destination: {
          type: "string",
          enum: ["home", "dailyInsight", "chat"],
          description: "Which screen to open.",
        },
      },
      required: ["destination"],
    },
  },
  {
    name: "setBirthDate",
    description:
      "Record the user's birth DATE once they tell you. Always read the date " +
      "back to confirm.",
    inputSchema: {
      type: "object",
      properties: {
        year: { type: "number", description: "e.g. 1995" },
        month: { type: "number", description: "1-12" },
        day: { type: "number", description: "1-31" },
      },
      required: ["year", "month", "day"],
    },
  },
  {
    name: "setBirthTime",
    description:
      "Record the user's birth TIME in 24-hour form. Birth time changes the " +
      "rising sign, so read it back and confirm.",
    inputSchema: {
      type: "object",
      properties: {
        hour24: { type: "number", description: "0-23" },
        minute: { type: "number", description: "0-59" },
      },
      required: ["hour24", "minute"],
    },
  },
  {
    name: "setBirthPlace",
    description:
      "Record the user's birth PLACE (city). It is geocoded to coordinates + " +
      "timezone; confirm the resolved city with them.",
    inputSchema: {
      type: "object",
      properties: {
        city: {
          type: "string",
          description: "City name, optionally with region/country.",
        },
      },
      required: ["city"],
    },
  },
  {
    name: "setGender",
    description:
      "Record the user's gender (helps traditional chart reading). Only if " +
      "they offer it.",
    inputSchema: {
      type: "object",
      properties: {
        gender: { type: "string", enum: ["MALE", "FEMALE", "OTHER"] },
      },
      required: ["gender"],
    },
  },
  {
    name: "submitBirthDetails",
    description:
      "Save the birth details and reveal the chart. Only call once date, time " +
      "and place are all set and confirmed.",
    inputSchema: { type: "object", properties: {} },
  },
];

/** The tool-usage guideline appended to the Aryabhatt playbook instructions. */
export const BABA_TOOL_GUIDELINES = [
  "",
  "## Acting on the app (tools)",
  "You can operate the app for the user through your tools. When a tool fits,",
  "call it instead of only talking:",
  "- navigateTo: move the user to home, dailyInsight, or chat.",
  "- setBirthDate / setBirthTime / setBirthPlace / setGender: fill the",
  "  birth-details form as the user tells you; always read values back to",
  "  confirm before moving on.",
  "- submitBirthDetails: only after date, time and place are set and confirmed.",
  "If a birth-details tool reports it is unavailable, use navigateTo to open the",
  "birth-details screen first, then set the value. Keep speaking naturally; the",
  "tool call happens under the hood.",
].join("\n");
