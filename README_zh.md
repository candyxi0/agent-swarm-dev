# 🐝 agent-swarm-dev

> 让你的编码小蜜蜂们并行工作，各干各的，互不干扰 ✨

在独立的 git worktree 中启动编码 Agent（Claude Code），每个 Agent 运行在各自的 tmux 会话里。Agent 独立完成编码、提交、推送，后台还有个贴心的小监控，检测完成状态后还会通过企业微信给你发消息通知～ 🎉

调度端支持 Claude Code、OpenClaw、Codex 等任意 AI 助手 — 但下派干活的编码 Agent 固定使用 Claude Code。

## 🚀 快速开始

进入你的项目，一行命令搞定安装：

```
cd /你的项目
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

安装脚本会自动检测 `~/.openclaw` 和 `~/.claude` 目录，创建 skills 软链，并设置 cron 定时清理任务。

> **首次使用：** 如果项目下没有配置文件，skill 会自动进入交互式引导，帮你创建配置。如果当前目录不是 git 仓库，还会先让你输入 git 地址进行克隆。

## 🧠 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                      🐝 agent-swarm-dev 🐝                      │
│                                                                  │
│  你说: "启动小蜜蜂，实现登录功能"                                   │
│       ↓                                                          │
│  0. 📦  (首次运行) 交互式创建配置文件                              │
│  1. 🏗️  git worktree 变出一个独立小窝                            │
│  2. 📺  tmux 建一个后台小房间                                    │
│  3. 🤖  Claude Code 在里面专心编码                               │
│  4. 👀  后台监控每 5 秒探头看看                                  │
│  5. 🎉 完成后 → 检查提交 → 企微通知 → 收拾小工具                 │
└─────────────────────────────────────────────────────────────────┘
```

每个 Agent 都有自己独立的小天地：独立 worktree + 独立 tmux 会话 + 独立 git 分支，各干各的，互不打扰~

## 🎮 你可以做什么

所有交互都通过自然语言完成 — 直接跟你的 AI 助手说：

| 你想做什么 | 怎么说 |
|-----------|--------|
| 启动编码 Agent | "启动小蜜蜂" 或 "launch a coding bee" |
| 查看 Agent 状态 | "查看小蜜蜂状态" 或 "check agents" |
| 查看已注册项目 | "查看项目列表" 或 "list projects" |
| 停止 Agent | "停止 agent feat-login" 或 "stop agent" |
| 批量启动 Agent | "批量启动agent，做这些任务..." 或 "launch multiple agents" |
| 清理已合并分支 | "清理分支" 或 "cleanup merged branches" |

剩下的交给 skill — 自动创建 worktree、启动 tmux 会话、后台监控、发送通知。

## ⚙️ 配置说明

配置文件位于**你的项目目录下**，命名为 `.agent-swarm-<项目名>.env`。如果配置文件不存在，skill 会在首次运行时交互式引导创建，所有字段均可留空。

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SWARM_PROJECT_ROOT` | 当前目录 | Agent 创建 worktree 的 git 仓库路径 |
| `WECOM_WEBHOOK_URL` | (空) | 企业微信机器人 Webhook 地址 |
| `GIT_AUTH_METHOD` | `none` | Git 推送认证方式：`token`、`ssh` 或 `none` |
| `GIT_TOKEN` | (空) | Personal Access Token（token 认证用） |
| `GIT_SSH_KEY` | (空) | SSH 密钥路径（ssh 认证用） |
| `YUNXIAO_TOKEN` | (空) | 云效 API token |
| `YUNXIAO_ORG_ID` | (空) | 云效组织 ID |
| `YUNXIAO_SPACE_ID` | (空) | 云效空间 ID |
| `YUNXIAO_REPO_ID` | (空) | 云效仓库 ID |
| `MAX_RETRIES` | `3` | 最大重试次数 |
| `CHECK_INTERVAL_MINUTES` | `2` | 状态检查间隔（分钟） |

> 💡 **最小配置**：只需设置 `SWARM_PROJECT_ROOT` 指向你的 git 仓库即可。云效和企微通知都是可选的，不影响 Agent 正常干活。

## 📁 目录结构

项目级别文件（自动创建）：

```
你的项目/
├── .agent-swarm-<项目名>.env       ← 配置文件（首次运行时交互式创建）
├── .swarm-active-tasks.json        ← 活跃任务记录
├── .swarm-monitor.log              ← 监控日志
└── .swarm-worktrees/               ← 隔离的 worktree 目录
```

## 🔄 任务生命周期

```
🚀 你说要启动一个 agent
    ↓
📦  (首次运行) 交互式创建配置文件
    ↓
🏗️ 创建 worktree（.swarm-worktrees/<task-id>）
    ↓
📺 创建 tmux 会话（swarm-<task-id>）
    ↓
🤖 Claude Code 在会话内编码
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

拉取仓库即可，所有项目通过符号链接自动获取最新版本~

## 📦 依赖项

- `git` — 用于 worktree 隔离
- `tmux` — 用于会话管理
- `jq` — 用于 JSON 任务追踪
- `claude`（Claude Code CLI）— 编码 Agent

## ❓ 常见问题

| 问题 | 解决方法 |
|------|---------|
| `SWARM_NOT_FOUND` | 确认 `bin/*.sh` 有执行权限：`chmod +x bin/*.sh` |
| `jq not found` | `apt-get install -y jq` |
| `tmux not found` | `apt-get install -y tmux` |
| `claude not found` | 安装 Claude Code CLI |
| Agent 已在运行 | 跟 AI 助手说查看状态或停止该 agent |
| worktree/分支已存在 | 换个 task-id，或者说清理已合并分支 |
| 完成后没有新提交 | 查看监控日志：在项目根目录找 `.swarm-monitor.log` |
| 没有配置文件 | skill 首次运行会交互式引导创建 `.agent-swarm-<项目>.env` |
