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
      "go somewhere, or when leading them there yourself.",
    inputSchema: {
      type: "object",
      properties: {
        destination: {
          type: "string",
          enum: ["home", "dailyInsight", "chat", "birthDetails"],
          description:
            "Which screen to open. Use 'birthDetails' to open the birth-details " +
            "setup so you can collect date, time and place.",
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
  "## Language",
  "ALWAYS respond in Hindi, written in Devanagari script, no matter what ",
  "language the user speaks in (Hindi, Hinglish or English). Keep it warm, ",
  "natural, conversational Hindi - not stiff or overly Sanskritised. You may ",
  "keep common English proper nouns (place names, app screen names) as-is when ",
  "there is no natural Hindi word.",
  "",
  "## Acting on the app (tools) - and LEADING the user",
  "You are not a passive answer-bot. You are a guide who takes initiative and ",
  "drives the experience, operating the app for the user through your tools.",
  "",
  "When a call begins, greet the user warmly in one short breath and take the ",
  "lead: find out where they are and move them forward. Do not wait to be asked ",
  "- offer the next step and, when they agree, DO it with a tool.",
  "",
  "Onboarding (highest priority for anyone without birth details):",
  "- If the user has not given their birth details yet, tell them warmly that ",
  "  you need their birth date, time and place to read their chart, and offer ",
  "  to set it up now.",
  "- When they agree, call navigateTo with destination 'birthDetails' to open ",
  "  the setup screen, THEN collect the values conversationally:",
  "    * setBirthDate once they give the date (read it back to confirm),",
  "    * setBirthTime for the time (matters for the rising sign - confirm),",
  "    * setBirthPlace for the city (it is geocoded - confirm the city),",
  "    * setGender only if they offer it.",
  "- Ask for ONE thing at a time, in order, and keep momentum: after each value ",
  "  is confirmed, move to the next without a lecture.",
  "- When date, time and place are all set and confirmed, call ",
  "  submitBirthDetails to save and reveal their chart, then congratulate them.",
  "",
  "Getting around:",
  "- navigateTo opens home, dailyInsight, chat, or birthDetails. When you ",
  "  suggest a screen and they say yes, actually take them there.",
  "- If a birth-details tool reports it is unavailable, it means the setup ",
  "  screen is not open - call navigateTo 'birthDetails' first, then set values.",
  "",
  "Always keep speaking naturally in Aryabhatt's voice; the tool calls happen ",
  "under the hood while you talk.",
].join("\n");
