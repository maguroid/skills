/**
 * Streaming-input agent: multi-turn and steerable.
 *
 * Passing an AsyncIterable<SDKUserMessage> as `prompt` (instead of a string)
 * unlocks the Query control methods: interrupt(), setPermissionMode(),
 * setModel(), etc. This is the shape to use for interactive / long-running
 * agents where you decide the next turn based on what you observed.
 *
 * Run: ANTHROPIC_API_KEY=... npx tsx streaming-input.ts
 */
import { query, type SDKUserMessage } from "@anthropic-ai/claude-agent-sdk";

// A queue you can push user turns into over time.
function makeTurnStream() {
  const pending: SDKUserMessage[] = [];
  let resolve: (() => void) | null = null;
  let done = false;

  function push(text: string) {
    pending.push({
      type: "user",
      message: { role: "user", content: text },
      parent_tool_use_id: null,
    });
    resolve?.();
  }
  function end() {
    done = true;
    resolve?.();
  }

  async function* stream(): AsyncIterable<SDKUserMessage> {
    while (!done || pending.length > 0) {
      if (pending.length === 0) {
        await new Promise<void>((r) => (resolve = r));
        resolve = null;
        continue;
      }
      yield pending.shift()!;
    }
  }

  return { push, end, stream };
}

async function main() {
  const turns = makeTurnStream();
  turns.push("Find every TODO comment in src/ and list them.");

  const q = query({
    prompt: turns.stream(),
    options: {
      systemPrompt: { type: "preset", preset: "claude_code" },
      settingSources: [],
      tools: { type: "preset", preset: "claude_code" },
      allowedTools: ["Read", "Glob", "Grep"],
      maxTurns: 20,
    },
  });

  // Control the session mid-run (only possible with streaming input):
  await q.setPermissionMode("acceptEdits");

  for await (const msg of q) {
    if (msg.type === "result") {
      console.log("turn result:", msg.subtype === "success" ? msg.result : msg.subtype);
      // Decide the next turn based on the result, then either push or end:
      turns.end(); // here we stop after one turn for the demo
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
