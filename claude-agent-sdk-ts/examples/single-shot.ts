/**
 * Single-shot agent: one task, run to completion, print the result.
 *
 * Run: ANTHROPIC_API_KEY=... npx tsx single-shot.ts
 *
 * Notes:
 * - The agent only runs because we iterate the generator to completion.
 * - We set systemPrompt and settingSources explicitly (don't rely on defaults).
 * - maxTurns + abortController are the safety rails.
 */
import { query } from "@anthropic-ai/claude-agent-sdk";

async function main() {
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 120_000); // hard 2-min cap

  const q = query({
    prompt: "Read package.json in the current directory and summarize its scripts.",
    options: {
      systemPrompt: { type: "preset", preset: "claude_code" },
      settingSources: ["project"], // load CLAUDE.md / project settings; use [] for full isolation
      tools: { type: "preset", preset: "claude_code" },
      allowedTools: ["Read", "Glob", "Grep"], // auto-approve read-only tools, no prompts
      maxTurns: 6,
      abortController: abort,
    },
  });

  for await (const msg of q) {
    if (msg.type === "assistant") {
      // Stream intermediate assistant text if you want progress output.
    } else if (msg.type === "result") {
      if (msg.subtype === "success") {
        console.log("\n=== RESULT ===\n" + msg.result);
      } else {
        console.error("Agent did not succeed:", msg.subtype);
      }
      console.log(
        `\n(turns: ${msg.num_turns}, cost: $${msg.total_cost_usd?.toFixed(4)})`,
      );
    }
  }

  clearTimeout(timeout);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
