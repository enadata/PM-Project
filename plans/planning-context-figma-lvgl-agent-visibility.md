# Planning Context

## 上下文摘要
- `README.md` 区分了 `.codex/agents/`（Codex/App 运行时）与 `.github/agents/`（GitHub Copilot 配置载体）。
- `figma_lvgl_designer` 同时存在于 `.github/agents/figma_lvgl_designer.agent.md` 和 `.codex/agents/figma_lvgl_designer.toml`。
- `bootstrap-pm-project.sh` 使用 `project/codex-cli-adaptation` 分支通过 submodule + 软链接方式暴露 `.github/agents` 与 `.github/skills`。
- `.codex/config.toml` 中有 Figma MCP 配置，表明部分能力偏向 Codex 运行时。

## 识别意图
用户想知道：为什么 GitHub 里的 Copilot 没有显示 `project/codex-cli-adaptation` 分支里的 `figma_lvgl_designer` agent。

## 推荐路由
无需继续路由到其他 Skill/Agent，可直接答复（解释/分析任务）。

## 开放问题
- 用户说的“GitHub 里 Copilot”具体指网页端、IDE 插件还是下游接入仓库？
- 当前查看的是本仓库，还是通过 submodule 接入后的业务仓库？
- 远端分支上该 agent 文件是否已实际推送？
- GitHub Copilot 是否仅索引默认分支内容？
