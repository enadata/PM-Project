# Planning Context — add zread skill

## 上下文摘要
- Skill 实际存放目录为 `.github/skills/<skill-name>/`，`.agents/skills/` 是指向它的符号链接。
- 仓库已有 Skill 通常至少包含 `SKILL.md`，可按需包含 `README.md`、`references/`、`scripts/`。
- 与 Skill 列表直接相关的索引文档包括 `AGENTS.md`、`README.md` 和 `custom-agents-skills-matrix.md`。
- 外部仓库 `ZreadAI/zread-skill` 可获取到 `README.md`、`SKILL.md` 与 `references/stdio-protocol.md`。

## 识别意图
- 用户希望把外部 `zread` Skill 安装到当前分支，使仓库内可直接使用该 Skill。

## 推荐路由
1. 直接实现：将外部 Skill 文件导入 `.github/skills/zread/`。
2. 同步更新本仓库内与 Skill 列表相关的索引文档，保证可发现性。

## 开放问题
- 外部仓库 API 目录枚举受限，但 raw 文件可访问；按当前可见文件完成最小集成。
- 当前任务未要求创建 PR，因此只在当前分支完成改动。
