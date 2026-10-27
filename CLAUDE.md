# Nivlet — Claude instructions

Read and follow [AGENTS.md](AGENTS.md) before working in this repository. It is the canonical project guidance, including the user's preference to be addressed as **papi**.

For a native interface task, also read [the UI guide](docs/native-ui-guide.md), open the actual [Refbox references](references/ui-ux/refbox/README.md), and use the relevant skills listed in [the skill guide](docs/agent-skills.md).

Project skills live in `.agents/skills/`. Claude Code discovers them through relative symlinks in `.claude/skills/`; if a skill is missing from your inventory, read its `SKILL.md` by path. Do not duplicate or move the user's skills just to load them. When adding or removing a skill, update its symlink and [the skill guide](docs/agent-skills.md).

Use [the architecture](docs/architecture.md), [phase overview](docs/phases.md) and `docs/phases/phaseN_deliverables.md` for implementation. Proposed source paths are not evidence that an app exists. Keep this file as an entry point; shared rules belong in `AGENTS.md`.
