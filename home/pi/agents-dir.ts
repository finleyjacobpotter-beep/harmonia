// pi takes a project's instructions from .agents/ only (home/gamedev.nix
// installs this as a global extension; docs/pi.md).
//
// - Instructions: the AGENTS.md (and any other .md) directly in .agents/,
//   in the working directory and each parent up to the repository root,
//   replace the AGENTS.md / CLAUDE.md files pi would load.
// - Projects are never trusted, so a project's .pi/ (settings.json,
//   mcp.json, extensions, skills, prompts, SYSTEM.md) never loads;
//   .agents/skills are added here instead.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

// The working directory and its parents up to the repository root (the
// directory holding .git), or just the working directory outside a repo.
function projectDirs(cwd: string): string[] {
  const dirs: string[] = [];
  let dir = resolve(cwd);
  for (;;) {
    dirs.push(dir);
    if (existsSync(join(dir, ".git"))) return dirs;
    const parent = dirname(dir);
    if (parent === dir || parent === homedir()) return [resolve(cwd)];
    dir = parent;
  }
}

function isDir(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

// .agents/AGENTS.md first, then the other .md files there by name, the
// repository root's first and the working directory's last (deeper wins).
function agentsFiles(cwd: string): { path: string; content: string }[] {
  const files: { path: string; content: string }[] = [];
  for (const dir of projectDirs(cwd).reverse()) {
    const agents = join(dir, ".agents");
    if (!isDir(agents)) continue;
    const names = readdirSync(agents)
      .filter((name) => name.endsWith(".md"))
      .sort((a, b) => (a === "AGENTS.md" ? -1 : b === "AGENTS.md" ? 1 : a.localeCompare(b)));
    for (const name of names) {
      const path = join(agents, name);
      try {
        if (statSync(path).isFile()) files.push({ path, content: readFileSync(path, "utf8") });
      } catch {}
    }
  }
  return files;
}

export default function (pi: ExtensionAPI) {
  pi.on("project_trust", async () => ({ trusted: "no" }));

  pi.on("resources_discover", async (event) => ({
    skillPaths: projectDirs(event.cwd)
      .map((dir) => join(dir, ".agents", "skills"))
      .filter(isDir),
  }));

  pi.on(
    "before_agent_start",
    async (event, ctx) => {
      const options = event.systemPromptOptions;
      options.contextFiles = agentsFiles(options.cwd ?? ctx.cwd);
    },
    { previewSafe: true },
  );
}
