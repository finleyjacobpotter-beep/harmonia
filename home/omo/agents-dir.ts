// omo takes a project's instructions from .agents/ only, and nothing from a
// project's .omo/ (home/gamedev.nix installs this as a global extension;
// docs/omo.md).
//
// - Instructions: the AGENTS.md (and any other .md) directly in .agents/,
//   in the working directory and each parent up to the repository root,
//   replace the AGENTS.md / CLAUDE.md files omo would load. The
//   [Directory Context: ...] blocks it appends to file reads (a subfolder's
//   AGENTS.md) are dropped. The rules engine (.omo/rules, .claude/rules,
//   ...) is off through PI_RULES_DISABLED in the omo wrapper.
// - Projects are never trusted, so a project's .omo/settings.json, mcp.json,
//   extensions, skills, prompts and SYSTEM.md never load; .agents/skills are
//   added here instead.
// - A project .omo/omo.jsonc is read before any extension runs, so it can't
//   be blocked; a session warns when one is in effect.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

type ContextFile = { path: string; content: string };

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
function agentsFiles(cwd: string): ContextFile[] {
  const files: ContextFile[] = [];
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

// The same section omo builds from its context files (buildContextFilesSection
// in omo 5.1.29), so its own can be found and replaced.
function contextSection(files: ContextFile[]): string {
  if (files.length === 0) return "";
  const lines = [
    "## Project Context",
    "",
    "Project instruction files (below, and in [Directory Context: ...] blocks injected during reads) bind files under their directory; deeper files win on conflict; explicit user instructions override.",
    "",
  ];
  for (const file of files) lines.push(`### ${file.path}`, "", file.content.trimEnd(), "");
  return lines.join("\n").trimEnd();
}

function withoutBuiltinContext(prompt: string, files: ContextFile[]): string {
  const builtin = contextSection(files);
  if (builtin && prompt.includes(builtin)) return prompt.replace(builtin, "");
  // If omo changes the format: drop the section up to the next heading.
  return prompt.replace(/^## Project Context\n[\s\S]*?(?=^## |(?![\s\S]))/m, "");
}

const DIRECTORY_CONTEXT = "\n\n[Directory Context: ";

function projectOmoConfig(cwd: string): string | undefined {
  for (let dir = resolve(cwd); dir !== homedir(); ) {
    for (const name of ["omo.jsonc", "omo.json"]) {
      const path = join(dir, ".omo", name);
      if (existsSync(path)) return path;
    }
    const parent = dirname(dir);
    if (parent === dir) return undefined;
    dir = parent;
  }
  return undefined;
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
      const options = event.systemPromptOptions ?? {};
      const cwd = options.cwd ?? ctx.cwd;
      const prompt = withoutBuiltinContext(event.systemPrompt, options.contextFiles ?? []);
      const ours = contextSection(agentsFiles(cwd));
      return { systemPrompt: ours ? `${prompt.trimEnd()}\n\n${ours}` : prompt };
    },
    { previewSafe: true },
  );

  pi.on("tool_result", async (event) => {
    let changed = false;
    const content = event.content.map((part) => {
      if (part.type !== "text") return part;
      const at = part.text.indexOf(DIRECTORY_CONTEXT);
      if (at < 0) return part;
      changed = true;
      return { ...part, text: part.text.slice(0, at) };
    });
    return changed ? { content } : {};
  });

  pi.on("session_start", async (_event, ctx) => {
    const config = projectOmoConfig(ctx.cwd);
    if (config) ctx.ui.notify(`${config} overrides omo's settings here (models included); omo can't be told to ignore it`, "warning");
  });
}
