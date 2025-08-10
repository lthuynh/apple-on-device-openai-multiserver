# OpenAPI Parameter Compatibility & General Tips  _[Complements of the New gpt-5-thinking Model]_

This server implements the OpenAI Chat Completions API with the following supported parameters, and expanding from original project.

<br></br>
## - `model` -
**The exact inference backend you’re calling (capabilities, tokenizer, context window, cost/latency profile). Examples: gpt-4o, gpt-4o-mini, self-hosted apple-fm-base, etc.:**

<br></br>
Why it matters
 - Determines context window (max tokens for prompt ＋ output).
 - Controls modalities (text only vs. vision/audio/tools).
 - Affects tokenization (IDs differ by model ⎯▶ important for logit_bias).
 - Governs available features (tool calling, JSON mode, seeds, reasoning tokens).
 
<br></br>
>*Tips*
> - *Treat model name as a contract: pin exact variants when reproducibility matters.*
> - *Keep a lightweight “model registry” in code so you can swap models without touching business logic.*

<br></br>
## - `messages` -
**The conversation state you pass in—an ordered list of objects like:**
 ```json
 [
   {"role": "system", "content": "You are a helpful..."},
   {"role": "user", "content": "Question..."},
   {"role": "assistant", "content": "Earlier reply..."},
   {"role": "tool", "tool_call_id": "abc", "content": "{result...}"}
 ]
 ```

<br></br>
Common roles: system, user, assistant, and (when using tool/function calling) tool. Some APIs allow content to be multi-part (e.g., text ＋ images).

<br></br>
Why it matters
 - The system message is your highest-priority steering mechanism.
 - Every token in messages consumes context window—be concise.
 - Tool results should usually be fed back as tool role content, not spliced into the user string.

<br></br>
>*Tips*
> - *Keep one short, authoritative system message; avoid piling on multiple competing system messages.*
> - *Summarize earlier turns to keep prompts within window while preserving intent.*

<br></br>
## - `temperature` -
**Controls sampling randomness. Logits are scaled by 1/temperature before sampling.**
 - if temperature **=** 0 ⎯▶ near-greedy (deterministic if the provider also supports a seed and you fix it).
 - if temperature ~0.2–0.7 ⎯▶ balanced creativity.
 - if temperature ＞ 0.8 ⎯▶ very diverse but riskier/less stable outputs.

<br></br>
Interplay
 - With top_p (if available): both gate diversity; use one as a primary dial (commonly top_p fixed at 1.0 and vary temperature).

<br></br>
>*Tips*
> - *For structured output (JSON, SQL, code), keep temperature low.*
> - *For ideation/brainstorming, increase it gradually (e.g., 0.2 ⎯▶ 0.6 ⎯▶ 0.9).*

<br></br>
## - `max_tokens` -
**The upper bound on new tokens the model may generate for the completion. (Different vendors call this max_tokens, max_output_tokens, or max_new_tokens.)**

<br></br>
Context window rule:
```quote
tokens(prompt/messages) ＋ tokens(output) ≦ model_context_window 
```

<br></br>
If the sum would exceed the window, you’ll get truncation or an error.

<br></br>
Finish reasons
 - stop: hit a stop sequence or the model chose to stop.
 - length: hit max_tokens limit.
 - Others (provider-specific): safety, tool_calls, etc.

<br></br>
>*Tips*
> - *Set max_tokens high enough to avoid length stops, then use explicit stop sequences or structured prompting to end responses cleanly.*
> - *When streaming long outputs to users, still keep a sane ceiling to avoid runaway responses.*

<br></br>
## - `stream` -
**Return tokens incrementally (usually via server-sent events). You receive small delta chunks you concatenate client-side until a final message with finish_reason.**

<br></br>
Why it matters
 - Latency: first token appears fast, improving UX.
 - Enables progressive rendering and early cancellation.

<br></br>
>Implementation gotchas
> - Chunks may carry partial words; always buffer and join.
> - Tool calls can also stream; expect partial tool_calls objects before they finalize.
> - If you need the whole assistant message (e.g., to validate JSON), assemble it before acting.

<br></br>
## - `presence_penalty` -
**A penalty applied to any token that has appeared at least once in the generated text so far. Intuition: "encourage new topics/lexicon."**

<br></br>
Typical range: [-2.0, 2.0] (positive values discourage reuse).

<br></br>
Canonical (conceptual) adjustment
```quote
logit'[t] = logit[t] - presence_penalty 🞫 1{count(t) ＞ 0}
```

<br></br>
Use when
 - You want the model to explore (brainstorming, list of ideas).
 - You see the model circling around the same concepts.

<br></br>
>Caveats
> - Can degrade coherence if set too high, especially in code or strict formats.

<br></br>
## - `frequency_penalty` -
**Penalizes tokens proportionally to how often they’ve already been generated. Intuition: "reduce repetition intensity."**

<br></br>
Typical range: [-2.0, 2.0] (positive values discourage repetition).

<br></br>
Conceptual adjustment
```quote
logit'[t] = logit[t] - frequency_penalty 🞫 count(t)
```

<br></br>
Use when
 - The model repeats phrases/sentences (e.g., looped poetry, verbose boilerplate).
 - You want terse, non-repetitive prose.

<br></br>
Presence vs. frequency
 - Presence: binary “have we used it at all?”
 - Frequency: “how many times have we used it?”
You can combine them: small presence (e.g., 0.2–0.5) ＋ small frequency (e.g., 0.2–0.7) is a common, gentle mix.

<br></br>
## - `logit_bias` -
**A per-token logit offset you provide as { token_id: bias }. Positive values make a token more likely; negative values make it less likely; very negative values can effectively ban a token.**

<br></br>
Behavior (conceptual)
```quote
logit'[t] = logit[t] ＋ bias[t]  
```
(then softmax and sample as usual)

<br></br>
Practical uses
 - Strongly discourage specific words/phrases (profanity, PII markers).
 - Nudge toward required scaffolding tokens (e.g., starting with [ or {).

<br></br>
>Gotchas
> - Token IDs are model-specific. You must use the model’s tokenizer to find the right IDs (watch for leading spaces—English BPEs often encode 'foo' as a different token than 'foo').
> - Multi-token phrases need multiple entries.
> - Overuse is brittle; prefer tool calling / JSON mode / schemas when available.

<br></br>
