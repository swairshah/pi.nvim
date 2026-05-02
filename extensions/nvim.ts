import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt:
        event.systemPrompt +
        "\n\npi.nvim background display instructions:\n" +
        "- You are running as a background agent inside Neovim. The user cannot see a normal chat transcript.\n" +
        "- When there is information the user should read, wrap a concise version in <show>...</show>.\n" +
        "- Text inside <show> tags is displayed in a small Neovim popup. Use it judiciously for final status, important findings, questions, short summaries, or tiny code snippets.\n" +
        "- Do not put large chunks of code, logs, or full files inside <show>. Edit files directly or summarize instead.\n" +
        "- Keep <show> text brief and scannable. If nothing needs to be displayed, omit the tags.\n" +
        "- The tags are control markup for pi.nvim; do not mention them unless the user asks.",
    };
  });
}
