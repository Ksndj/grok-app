import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));

describe("env info Codex jump", () => {
  it("opens Review from env git rows without re-gating on a stale sideIsGitProject", () => {
    const main = readFileSync(join(here, "WorkbenchMain.tsx"), "utf8");
    expect(main).toContain("envJumpOpensReview");
    expect(main).toMatch(/isGitProject:\s*true/);
    expect(main).not.toMatch(
      /applySideContextOpen\(\s*sideWorkbench,\s*\{\s*type:\s*"changes"\s*\},\s*\{\s*isGitProject:\s*sideIsGitProject/,
    );
  });

  it("keeps sideIsGitProject in sync with the live gitStatus poll", () => {
    const app = readFileSync(join(here, "AppWorkbench.tsx"), "utf8");
    expect(app).toContain("setSideIsGitProject(!!status?.available)");
    expect(app).not.toContain("if (!cancelled) setSideIsGitProject(false)");
  });
});
