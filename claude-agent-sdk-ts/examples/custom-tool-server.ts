/**
 * Give the agent a custom, typed, in-process tool.
 *
 * `tool()` defines a function the model can call; `createSdkMcpServer()` bundles
 * tools into an in-process MCP server (no subprocess). The tool is exposed to
 * the model as `mcp__<serverName>__<toolName>`, here `mcp__math__add`.
 *
 * Run: ANTHROPIC_API_KEY=... npx tsx custom-tool-server.ts
 */
import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const add = tool(
  "add",
  "Add two numbers and return the sum.",
  {
    a: z.number().describe("first addend"),
    b: z.number().describe("second addend"),
  },
  async (args) => {
    // args is typed { a: number; b: number } from the schema above.
    const sum = args.a + args.b;
    // Handlers MUST return the MCP CallToolResult shape, not a bare value.
    return { content: [{ type: "text", text: String(sum) }] };
  },
);

const mathServer = createSdkMcpServer({
  name: "math",
  version: "1.0.0",
  tools: [add],
});

async function main() {
  const q = query({
    prompt: "Use the add tool to compute 1234 + 8766, then state the result.",
    options: {
      // Give the agent ONLY our custom tool: no built-ins.
      tools: [],
      mcpServers: { math: mathServer },
      allowedTools: ["mcp__math__add"], // auto-approve our tool
      maxTurns: 5,
    },
  });

  for await (const msg of q) {
    if (msg.type === "result" && msg.subtype === "success") {
      console.log(msg.result);
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
