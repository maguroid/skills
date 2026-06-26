/**
 * Lock down what an unattended agent may do.
 *
 * Two complementary controls:
 *  - canUseTool: per-call allow/deny + input rewrite (the precise gate).
 *  - PreToolUse hook: broader inspection/audit; can block.
 *
 * This agent may read anywhere and write/edit only under /workspace, and may
 * never run a shell. There is no human in the loop, so we never leave a tool to
 * "prompt" — every decision is explicit.
 *
 * Run: ANTHROPIC_API_KEY=... npx tsx permissions-and-hooks.ts
 */
import { query, type CanUseTool } from "@anthropic-ai/claude-agent-sdk";

const WORKSPACE = "/workspace/";

const canUseTool: CanUseTool = async (toolName, input) => {
  switch (toolName) {
    case "Read":
    case "Glob":
    case "Grep":
      return { behavior: "allow" };

    case "Write":
    case "Edit": {
      const path = String((input as Record<string, unknown>).file_path ?? "");
      if (!path.startsWith(WORKSPACE)) {
        return { behavior: "deny", message: `writes restricted to ${WORKSPACE}` };
      }
      return { behavior: "allow", updatedInput: input };
    }

    case "Bash":
      return { behavior: "deny", message: "shell access is disabled for this agent" };

    default:
      // Default-deny anything we didn't explicitly consider.
      return { behavior: "deny", message: `tool ${toolName} not permitted` };
  }
};

async function main() {
  const q = query({
    prompt: "Create /workspace/hello.txt containing 'hi', then read it back.",
    options: {
      systemPrompt: "You are a careful file-editing agent.",
      settingSources: [],
      tools: { type: "preset", preset: "claude_code" },
      canUseTool,
      maxTurns: 10,
      hooks: {
        PreToolUse: [
          {
            hooks: [
              async (hookInput) => {
                // Audit every tool call before it runs.
                console.error(`[audit] ${hookInput.tool_name}`);
                return { continue: true };
              },
            ],
          },
        ],
      },
    },
  });

  for await (const msg of q) {
    if (msg.type === "result") {
      console.log(msg.subtype === "success" ? msg.result : `failed: ${msg.subtype}`);
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
