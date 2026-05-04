import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const TEXT_RESPONSE_POLICY = `
## Neovim Response Style

You are running inside Neovim via pi.nvim.
Keep responses primarily as regular text in <show> when user-visible output is useful.
Do NOT add or prefer <voice> tags unless the user explicitly asks for spoken/voice output.
When including <show> content, keep it short and actionable. No long code dumps or huge logs.
`;

const VOICE_RESPONSE_POLICY = `
## Neovim Response Style

You are running inside Neovim via pi.nvim.
The user requested voice behavior for this turn.
Include concise spoken summaries in <voice> tags, while keeping the rest normal text.
Keep <voice> output short, natural, and conversational.
Do not use only <voice> for full responses. If code/files are involved, summarize instead of reading code verbatim.
`;

const VOICE_TRIGGER_RE = /\b(voice|speech|tts|speak|spoken|talk|audio)\b/i;

function isVimContext(systemPrompt: string): boolean {
  return systemPrompt.includes("pi.nvim") || systemPrompt.includes("pi-background.nvim");
}

function setResponseMode(basePrompt: string, turnPrompt: string): string {
  const wantsVoice = VOICE_TRIGGER_RE.test(turnPrompt);
  const baseSectioned = basePrompt.includes("## Neovim Response Style")
    ? basePrompt.replace(/(?:^|\n)## Neovim Response Style[\s\S]*?(?=\n##|$)/, "")
    : basePrompt;

  return `${baseSectioned}\n${wantsVoice ? VOICE_RESPONSE_POLICY : TEXT_RESPONSE_POLICY}`.trim();
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    if (!isVimContext(event.systemPrompt)) {
      return;
    }

    return {
      systemPrompt: setResponseMode(event.systemPrompt, event.prompt ?? ""),
    };
  });
}
