import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// Neovim-only Pi extension.
//
// This file is loaded by pi.nvim via `pi --extension <this-file>` whenever
// the background Pi process is started from Neovim. It is intentionally a
// no-op placeholder for now. Normal/global/project Pi extensions still load
// through Pi's standard extension discovery.
export default function (_pi: ExtensionAPI) {
  // Intentionally empty.
}
