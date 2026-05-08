# 🐝 agent-swarm-dev

> 让你的编码小蜜蜂们并行工作，各干各的，互不干扰 ✨

在独立的 git worktree 中启动编码 Agent（Claude Code），每个 Agent 运行在各自的 tmux 会话里。Agent 独立完成编码、提交、推送，后台还有个贴心的小监控，检测完成状态后还会通过企业微信给你发消息通知～ 🎉

## 🚀 快速开始

进入你的项目，一行命令搞定安装：

```bash
cd /你的项目
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

### 🎯 启动 Agent

```bash
# 方式一：直接跟 Claude Code 说
# "启动一个 agent，帮我实现登录功能"

# 方式二：直接运行脚本
.claude/skills/agent-swarm-dev/bin/run-agent.sh feat-login "实现用户登录功能"
```

### 📋 查看状态

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

## 🧠 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                      🐝 agent-swarm-dev 🐝                      │
│                                                                  │
│  你说: "启动一个 agent，实现登录功能"                             │
│       ↓                                                          │
│  Claude Code → bin/run-agent.sh                                  │
│       ↓                                                          │
│  1. 🏗️  git worktree 变出一个独立小窝                            │
│  2. 📺  tmux 建一个后台小房间                                    │
│  3. 🤖  claude 在里面专心编码                                    │
│  4. 👀  后台监控每 5 秒探头看看                                  │
│  5. 🎉 完成后 → 检查提交 → 企微通知 → 收拾小工具                 │
└─────────────────────────────────────────────────────────────────┘
```

每个 Agent 都有自己独立的小天地：独立 worktree + 独立 tmux 会话 + 独立 git 分支，各干各的，互不打扰~

## 📁 目录结构

```
agent-swarm-dev/
├── SKILL.md                    ← Claude Code 的 skill 文档
├── SKILL.md.tmpl               ← 多宿主模板（生成 OpenClaw/Codex 版本）
├── README.md                   ← 英文版说明
├── README_zh.md                ← 中文版说明（就是本文件啦）
├── .agent-swarm.env            ← 配置文件（首次运行自动创建）
├── .swarm-active-tasks.json    ← 活跃任务记录（自动创建）
├── .swarm-monitor.log          ← 监控日志（自动创建）
└── bin/
    ├── install.sh              ← 一键安装到任意项目 🛒
    ├── run-agent.sh            ← 核心脚本：启动单个 agent 🚀
    ├── start-agent.sh          ← 带参数校验的启动包装器 📦
    ├── stop-agent.sh           ← 安全停止 agent 🛑
    ├── check-agents.sh         ← 查看所有 agent 状态 📋
    ├── swarm.sh                ← 批量并行启动多个 agent 🐝🐝🐝
    ├── cleanup-merged.sh       ← 清理已合并的分支和 worktree 🧹
    └── setup-cron.sh           ← 一键配置定时清理任务 ⏰
```

## 🛠️ 安装方式

进入你的项目目录，一行命令搞定：

```bash
cd /你的项目
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

会自动 clone 仓库（如果还没有的话），然后在 `.claude/skills/` 创建符号链接。改一次代码，所有项目跟着一起更新，省心~

## ⚙️ 配置说明

首次运行会自动创建 `.agent-swarm.env`（在 skill 目录下）。你也可以手动编辑：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SWARM_PROJECT_ROOT` | `.` | Agent 创建 worktree 的 git 仓库路径 |
| `YUNXIAO_TOKEN` | (空) | 云效 API token |
| `YUNXIAO_ORG_ID` | (空) | 云效组织 ID |
| `YUNXIAO_SPACE_ID` | (空) | 云效空间 ID |
| `YUNXIAO_REPO_ID` | (空) | 云效仓库 ID |
| `WECOM_WEBHOOK_URL` | (空) | 企业微信机器人 Webhook 地址 |
| `MAX_RETRIES` | `3` | 最大重试次数 |
| `CHECK_INTERVAL_MINUTES` | `2` | 状态检查间隔（分钟） |

> 💡 **最小配置**：只需设置 `SWARM_PROJECT_ROOT` 指向你的 git 仓库即可。云效和企微通知都是可选的，不影响 Agent 正常干活。

## 🎮 使用方法

### 单个 Agent

```bash
.claude/skills/agent-swarm-dev/bin/run-agent.sh <task-id> "<任务描述>"
```

举个例子：

```bash
.claude/skills/agent-swarm-dev/bin/run-agent.sh feat-user-api "实现用户CRUD API"
```

实时盯着看：

```bash
tmux attach -t swarm-feat-user-api
```

停下来：

```bash
tmux kill-session -t swarm-feat-user-api
```

### 🐝🐝🐝 批量并行 Agent

```bash
cat > /tmp/tasks.json << 'EOF'
[
  {"id": "feat-api",    "prompt": "实现用户CRUD API"},
  {"id": "feat-auth",   "prompt": "实现JWT认证中间件"},
  {"id": "feat-db",     "prompt": "实现数据库模型和迁移"}
]
EOF

.claude/skills/agent-swarm-dev/bin/swarm.sh /tmp/tasks.json
```

所有 Agent 同时开工，各自有自己的 worktree 和 tmux 会话，互不干扰~

### 🛑 停止 Agent

```bash
.claude/skills/agent-swarm-dev/bin/stop-agent.sh <task-id>
```

终止 tmux 会话，任务状态更新为 `stopped`（记录保留，方便追溯）。

### 📋 查看所有 Agent 状态

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

显示所有活跃任务、tmux 会话列表、最新监控日志。

### 🧹 清理已合并的分支

Agent 推完代码后分支会保留（方便你创建 MR）。MR 合并后可以用这个脚本自动打扫：

```bash
# 先预览一下要清理什么
.claude/skills/agent-swarm-dev/bin/cleanup-merged.sh --dry-run

# 实际执行
.claude/skills/agent-swarm-dev/bin/cleanup-merged.sh
```

自动扫描所有 `swarm/*` 分支，把已经合并到 main 的分支、worktree 和任务记录一并清理掉~

### ⏰ 定时清理（可选）

不想手动跑？一键配置系统 cron，每天凌晨自动打扫：

```bash
# 安装定时任务（默认每天 2:30）
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --install

# 卸载
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --uninstall

# 查看当前状态
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --status
```

清理日志在 `.swarm-cleanup.log`，随时可以翻看~

### 🤖 通过 Skill 触发

安装好后，在 Claude Code 中说以下任意一句话即可召唤 agent-swarm-dev：

- "启动一个 agent"
- "启动一个编码 agent"
- "run an agent"
- "start a coding agent"
- "launch swarm agent"

## 📦 依赖项

- `git` — 用于 worktree 隔离
- `tmux` — 用于会话管理
- `jq` — 用于 JSON 任务追踪
- `claude`（Claude Code CLI）— 编码 Agent

```bash
apt-get install -y jq tmux
# Claude Code 安装参考: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview
```

## 🔄 任务生命周期

```
🚀 启动 agent
    ↓
🏗️ 创建 worktree（.swarm-worktrees/<task-id>）
    ↓
📺 创建 tmux 会话（swarm-<task-id>）
    ↓
🤖 claude --print 在会话内编码
    ↓
📝 git commit + git push
    ↓
🔚 tmux 会话结束
    ↓
👀 后台监控检测到完成
    ↓
✅ 检查：有新提交 + 已推送到远端
    ↓
📢 发送企业微信通知（如果配置了 webhook）
    ↓
🧹 从 .swarm-active-tasks.json 中清理任务记录
    ↓
📦 worktree 保留在磁盘上（分支留作创建 MR 使用）
```

## 🏷️ 命名约定

| 项目 | 格式 | 示例 |
|------|------|------|
| Git 分支 | `swarm/<task-id>` | `swarm/feat-login` |
| Worktree 目录 | `.swarm-worktrees/<task-id>` | `.swarm-worktrees/feat-login` |
| Tmux 会话 | `swarm-<task-id>` | `swarm-feat-login` |

用 `swarm/` 前缀是为了避免跟你项目已有的分支名撞车~

## 📜 Agent 收到的约束

每个 Agent 开工前会收到以下硬性约束：

1. 🏠 只在当前 worktree 目录下编写代码
2. 📐 遵循项目编码规范
3. 📝 完成后通过 `git commit` 提交更改
4. 📤 推送到远程分支
5. 🚫 **禁止**修改 skill 目录下的任何文件
6. 🤐 只负责编码和提交，状态更新由后台监控脚本处理

## 🔄 更新

```bash
cd ~/agent-swarm-dev
git pull
```

就这样。所有项目通过符号链接自动获取最新版本~

## ❓ 常见问题

| 问题 | 解决方法 |
|------|---------|
| `SWARM_NOT_FOUND` | 确认 `bin/*.sh` 有执行权限：`chmod +x bin/*.sh` |
| `jq not found` | `apt-get install -y jq` |
| `tmux not found` | `apt-get install -y tmux` |
| `claude not found` | 安装 Claude Code CLI |
| Agent 已在运行 | `tmux attach -t swarm-<id>` 看进度，或 `stop-agent.sh <id>` 停止 |
| worktree/分支已存在 | 换个 task-id，或手动 `git worktree remove` 清理 |
| 完成后没有新提交 | 查看监控日志：在 skill 目录下找 `.swarm-monitor.log` |
| 有提交但未推送 | 任务记录会保留，手动 push 或检查 agent 为何推送失败 |
| 找不到 .git | 在 `.agent-swarm.env` 中设置正确的 `SWARM_PROJECT_ROOT` |

## 📝 监控日志

所有事件记录在 `.swarm-monitor.log`（位于 skill 目录下）：

```bash
# 实时盯着看
tail -f ~/agent-swarm-dev/.swarm-monitor.log

# 翻翻最近的记录
tail -20 ~/agent-swarm-dev/.swarm-monitor.log
```

日志内容包括：
- 监控脚本启动/结束时间 ⏱️
- Agent 会话结束检测 🔍
- Git 提交和推送检查结果 📊
- 企业微信通知发送状态 📢
- 任务清理状态 🧹
