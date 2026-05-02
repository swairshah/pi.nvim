import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setStatus("nvim", " nvim");
  });

  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt:
        event.systemPrompt +
        "\n\nNeovim integration context:\n" +
        "- You are being used from pi.nvim inside Neovim.\n" +
        "- User prompts may include current buffer or visual selection context.\n" +
        "- Prefer making concrete file edits with tools instead of asking the user to paste code.\n" +
        "- Keep replies concise and action-oriented because the user is in an editor workflow.\n" +
        "- If files are changed on disk, pi.nvim will refresh unmodified loaded buffers automatically.",
    };
  });

  pi.registerCommand("nvim", {
    description: "Show pi.nvim integration status",
    handler: async (_args, ctx) => {
      ctx.ui.notify("pi.nvim extension is loaded", "info");
    },
  });
}
