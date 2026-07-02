---
name: research-orchestrator
description: Orchestrate deep, multi-source, fact-checked web research by decomposing a question into research angles, running them in parallel, adversarially verifying load-bearing claims, and synthesizing a cited report. Use only when the user's intent is deep research — multi-source investigation, verification/fact-checking, or an explicit request for depth (e.g. "deep research", "fact-checked report", "〜を深掘り調査して", "多角的に調べて", "徹底的に調べて", or "リサーチして" when the question clearly needs multiple sources compared and verified). Do NOT use for summarizing or clipping a single known URL or page, or for quick lookups answerable from one source — those are other skills' jobs. If the harness ships its own native deep-research skill, prefer that unless the user names this skill explicitly. Works across harnesses (Claude Code, Codex CLI) by detecting whatever parallelization capability is available.
---

# Research Orchestrator

## Overview

Methodology in one line: clarify the question → set up a run directory →
detect harness capabilities → decompose into research angles → run angles in
parallel → adversarially verify load-bearing claims → synthesize a cited
report → save to a file and report back.

This skill is a *method*, not a specific tool binding. It runs identically
whether the harness exposes native subagents, only `codex exec`, or neither.
If the harness ships its own native deep-research skill, prefer that unless
the user explicitly asked for this one.

## Phase 0: Clarify the question

Before spending any research budget, check whether the question is
underspecified in a way that would change the answer (missing budget,
region, time window, audience, or intended use). If so, ask the user 2-3
targeted clarifying questions before starting. If it is already specific
enough, skip this phase — do not add clarification for its own sake.

## Run directory (harness-independent data bus)

All intermediate research artifacts move through files, never through the
orchestrator's own context window — this keeps the method harness-independent
and context usage bounded regardless of how much source material gets read.

- If the harness provides a scratchpad/temp directory, use it.
- Otherwise create `${TMPDIR:-/tmp}/research-orchestrator/<YYYY-MM-DD>-<slug>/`.

Layout:

```
<run-dir>/
  plan.md                     # decomposition, mode, capability tier chosen
  prompts/<angle>.md          # prompt file per angle (codex-exec tier)
  findings/<angle>.md         # one file per research angle
  verification/<claim-id>.md  # one file per verified claim
  report.md                   # final synthesized report
```

Every phase reads/writes through this directory, never pasting raw source
content into the conversation.

## Capability detection

Before choosing an execution tier, confirm two prerequisites for whichever
executor will do the actual research:

- **Web access**: the executor must be able to run web searches AND fetch
  full page content (not just snippets).
- **Shared filesystem**: the executor must be able to write into the run
  directory so the orchestrator can read its output.

Then detect, in this order, what's available for parallelizing research
angles. Do this once per run and record the chosen tier in `plan.md`.

1. **Native subagent tool.** If the harness has a native subagent/task
   dispatch tool (e.g. Claude Code's Agent tool) *and* those subagents have
   web access and can write to the run directory, use it. Launch angle
   agents concurrently according to the harness's parallelism semantics
   (in Claude Code, that means issuing all Agent calls in a single
   message). Every subagent prompt must state explicitly: do not
   re-delegate further, write findings to the specified file in the run
   directory, and the final chat message back can be brief since the file
   is the real deliverable. If native subagents exist but lack web access,
   fall through to tier 2.
2. **`codex exec` subprocesses.** If tier 1 is unavailable, check that
   `command -v codex` succeeds *and* that `codex exec --help` runs without
   error (an installed but broken binary should not be trusted). If both
   pass, launch multiple `codex exec` processes as background subprocesses,
   one per angle. Write each angle's prompt to
   `<run-dir>/prompts/<angle>.md`, then feed it via stdin (`-` as the
   prompt argument reads from stdin) to avoid argv length limits:

   ```bash
   codex --search exec -s workspace-write -c model_reasoning_effort=medium - \
     < <run-dir>/prompts/<angle>.md \
     > <run-dir>/findings/<angle>.log 2>&1 &
   ```

   Flag notes (if any of these look stale, verify with `codex --help` and
   `codex exec --help` before running):
   - `--search` enables live web search. It is a top-level flag and must
     come **before** the `exec` subcommand (`codex --search exec ...`);
     placing it after `exec` errors out.
   - Stdin handling: when the prompt file is redirected into stdin as
     above, stdin reaches EOF naturally and no extra redirect is needed.
     Only if you instead pass the prompt as a command-line argument must
     you append `< /dev/null` — otherwise `codex exec` waits on stdin for
     additional input and hangs under background execution.
   - Web search needs network access; if the sandbox blocks network by
     default, add `-c sandbox_workspace_write.network_access=true`.

   Failure handling: record each background PID, `wait` for all of them,
   then check that every `findings/<angle>.md` was actually created. For
   any missing one, read its `.log` to diagnose, retry that angle once,
   and if it still fails, record the gap in `plan.md` and call it out
   explicitly during synthesis.

   If `codex` is missing or `codex exec --help` fails, fall through to
   tier 3.
3. **Sequential fallback.** If neither tier is available, the orchestrator
   itself works through each angle one at a time — but only if the
   orchestrator itself has web access. If it does not, stop before starting
   any research and tell the user that no available executor can reach the
   web, rather than producing a report from memory. When running
   sequentially, still write each angle's findings to
   `findings/<angle>.md` in the same layout — the method stays identical,
   only the execution shape changes.

Cap concurrency at roughly 4-6 simultaneous subagents/subprocesses;
batch claim verification runs under the same cap rather than launching
one process per claim all at once.

## Decompose into research angles

Break the question into 3-6 angles that are mutually low-overlap and
jointly cover the question (a "multi-modal sweep"). Typical angle types:

- Primary/official sources (docs, filings, standards, vendor statements)
- Recent developments/news (with dates)
- Critiques, counterarguments, and documented failure cases
- Quantitative data/benchmarks
- Community/practitioner first-hand experience (forums, reviews, postmortems)

Pick the angles that actually matter for this question — not all five types
apply every time. Record the chosen angles and a one-line rationale for each
in `plan.md`.

## Researcher agent prompt template

Use this shape for every angle's research prompt (native subagent, `codex
exec`, or the orchestrator's own sequential pass):

```
You are researching ONE angle of a larger question. Do not re-delegate this
task further.

Overall question: <question>
Your angle: <angle name and one-line scope>

Instructions:
1. Search for sources relevant to your angle.
2. Open and actually read the top sources' full content — do not judge
   relevance or extract claims from search-result snippets alone.
3. Do not cite a source you could not actually read (paywall, 403, fetch
   failure). Find an alternative source instead, or if none exists, lower
   the claim's confidence and note it as unreadable.
4. For each load-bearing claim you find, record:
   - claim (one sentence)
   - evidence (what the source actually says, paraphrased)
   - source: [title](URL)
   - publish/update date (convert relative dates like "last year" to an
     absolute date)
   - confidence: high / medium / low
   - note if this is a fact vs. your own inference
5. Write your findings as structured Markdown to: <findings-file-path>
6. Your final message can be brief — the file is the deliverable.
```

## Adversarial verification

1. From all `findings/*.md`, extract the claims that the final answer's
   conclusion actually hinges on (load-bearing claims) — not every minor
   detail.
2. For each load-bearing claim, launch a verification pass (same capability
   tier chosen in Capability detection, respecting the concurrency cap)
   with a refute-bias prompt:

   ```
   Claim: <claim, with its original source>
   First, actively try to find credible evidence that contradicts or
   complicates this claim. Then look for at least one INDEPENDENT source
   (different publisher/author from the original) that confirms it.
   Verdict:
   - "disputed" if you found credible contradicting evidence (record both
     sides);
   - "verified" ONLY if you found independent confirmation and no credible
     contradiction;
   - "unverified" if you found no credible contradiction but also no solid
     independent confirmation.
   Write your verdict and evidence to: <verification-file-path>
   ```

3. Each claim's outcome lands in `verification/<claim-id>.md` as `verified`
   / `disputed` / `unverified` per the definitions above.
4. Skip this phase entirely in `quick` mode.

## Synthesize and save

Report structure:

1. TL;DR (a few sentences)
2. Key findings, with inline citations `[title](URL)` — every claim carries
   the citation(s) that support it inline; a source list alone is not
   enough. Weigh sources by kind: primary/official > reputable secondary >
   community anecdote, and say so when a conclusion rests mainly on the
   weaker kinds.
3. Uncertainties and disagreements (surface `disputed`/`unverified` claims
   here, don't bury them)
4. Source list
5. Methodology note: angles used, what was searched, what was verified and
   how, access date

Save to `<run-dir>/report.md` first, always. If the calling project defines
a place for research artifacts (e.g. a research-note location in its own
project instructions), save a copy there too, following that project's own
conventions. Then return to the chat only the save path(s) and a concise
summary — not the full report inline, unless the user asks for it.

## Scaling / modes

Infer the mode from the user's phrasing (e.g. "ざっくり" → quick,
"徹底的に" / "thorough" → thorough); default to standard.

| Mode | Angles | Verification | Output |
|------|--------|---------------|--------|
| quick | 2-3 | skipped | short summary |
| standard (default) | 3-5 | load-bearing claims only | full report |
| thorough | 5-6 | broad, plus a second-round completeness check | full report |

Quick-mode output MUST carry an explicit label that verification was skipped
(e.g. "Quick research — claims not independently verified"), since this
skill otherwise promises fact-checked results.

Thorough mode's completeness check: after the first synthesis pass, launch
one additional agent (same capability tier) with `plan.md` plus all of
`findings/` as input and the prompt "List the perspectives missing from this
research, important claims left unverified, and primary sources never read."
It writes to `findings/completeness-gaps.md`; run the gaps it finds as
additional angles for exactly one more round.

## Pitfalls

- Never paste full source text into the orchestrator's own context — pass
  it through files.
- Never treat a search-result snippet as sufficient evidence for a claim;
  the source page must actually be read.
- Convert relative dates ("last year", "recently") to absolute dates before
  recording a claim.
- If parallel execution is available (Capability detection tiers 1-2), do
  not fall back to running angles sequentially out of convenience.
- Watch for the same source being cited by multiple angles; dedupe during
  synthesis instead of double-counting it as independent confirmation.
