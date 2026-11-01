# 30 秒科普拟人分镜生成器

把任意科普文案压成 **30 秒 / 6 个镜头**的 AI 视频分镜提示词，固定形态为「外国真人主讲 + 拟人化生物配合解说」，每条画面描述可直接粘贴进 Sora / 可灵 / 即梦 / Midjourney。

**一个技能，通吃所有 agent**：Claude Code、DSH、Cursor、Windsurf、Cline、GitHub Copilot、Continue、Codex / Jules / Amp / opencode、Gemini CLI，以及任何能读提示词的聊天窗口。规则全部内联，没有运行时依赖。

---

## 安装

### 方式一：一键脚本

```powershell
# Windows
git clone https://github.com/canyexiren/sci-30s-storyboard.git
cd sci-30s-storyboard
.\install.ps1 -Target all -Project "D:\work\my-video-project"
```

```bash
# macOS / Linux
git clone https://github.com/canyexiren/sci-30s-storyboard.git
cd sci-30s-storyboard
./install.sh all --project ~/work/my-video-project
```

`-Target` 可选：`dsh` `claude` `codex` `gemini` `cursor` `windsurf` `cline` `copilot` `continue` `all`。默认只装 `dsh` + `claude`。

### 方式二：按 agent 手动放

| Agent | 形态 | 放哪里 | 文件 |
|---|---|---|---|
| **DSH** | skill 目录 | `~/.dsh/skills/sci-30s-storyboard/` | `SKILL.md` + `references/` + `scripts/` |
| **Claude Code** | skill 目录 | `~/.claude/skills/sci-30s-storyboard/` | 同上 |
| **Cursor** | 项目规则 | `.cursor/rules/sci-30s-storyboard.mdc` | `dist/cursor.mdc` |
| **Windsurf** | 项目规则 | `.windsurf/rules/sci-30s-storyboard.md` | `dist/windsurf.md` |
| **Cline** | 项目规则 | `.clinerules/sci-30s-storyboard.md` | `dist/cline.md` |
| **GitHub Copilot** | 指令文件 | `.github/instructions/sci-30s-storyboard.instructions.md` | `dist/copilot.instructions.md` |
| **Continue** | 规则 | `.continue/rules/sci-30s-storyboard.md` | `dist/continue.md` |
| **Codex / Jules / Amp / opencode** | 全局指令 | `~/.codex/AGENTS.md`（追加标记块） | `dist/AGENTS.md` |
| **Gemini CLI** | 上下文文件 | `~/.gemini/GEMINI.md`（追加标记块） | `dist/gemini.md` |
| **任意聊天窗口** | 复制粘贴 | 直接打开复制全文 | `dist/PROMPT.md` |

最省事的一条：DSH / Claude Code 用户直接把仓库 clone 成技能目录。

```bash
git clone https://github.com/canyexiren/sci-30s-storyboard.git ~/.claude/skills/sci-30s-storyboard
```

装完重启会话，agent 才会读到新指令。`AGENTS.md` / `GEMINI.md` 走的是 `<!-- sci-30s-storyboard:begin -->` 标记块，重复安装只替换块内内容，不会污染你自己的规则。

## 用法

不需要命令，把文案丢进来：

> 帮我把这段做成 30 秒分镜：章鱼有三颗心脏，两颗鳃心把血送进鳃里换氧，一颗主心把血送到全身。但主心在章鱼游泳时会停止跳动……

技能按 description 命中后自动执行：取叙事节点 → 切 6 镜锁 30 秒 → 定角色 → 逐镜填四要素 → 台词配字数 → 自检。

聊天窗口用户：打开 `dist/PROMPT.md`，整段复制，后面附上文案。

### 输出规格

| 项 | 值 |
|---|---|
| 总时长 | 30 秒（硬约束） |
| 镜头数 | 6（硬约束） |
| 单镜时长 | 4–6 秒，首尾相接合计 30 |
| 主讲人 | 外国真人，身份随主题匹配，全片不换人 |
| 拟人角色 | 只拟人化文案里真实出现的事物，中度拟人、写实不低幼 |
| 每镜四要素 | 编号+时长 / 对应文案 / 画面提示词 / 解说台词 |

### 效果示例

```markdown
**镜头3（10-16s）**
- 对应文案：法老之所以要在通往冥界的旅途上带一把瓜子
- 画面提示词：主体——拟人化西瓜籽（棕黑硬壳、细小四肢、认真表情）悬浮半空，
  抱着一只迷你皮水囊，对镜头点头、抬手比划｜场景——背景虚化的墓室壁画，
  冥界审判图隐约可见，浮尘缓慢飘动｜镜头语言——近景，固定镜头，轻微呼吸感｜
  画质风格——半写实拟人，材质保留硬壳质感，柔光轮廓，电影级写实质感，8K 超清，
  9:16 竖屏，画面无任何文字
- 解说台词：法老通往冥界的路上，为什么非要带上它
```

完整 6 镜见 [`references/example-watermelon.md`](references/example-watermelon.md)。

## 自检脚本

```bash
python3 scripts/check_storyboard.py your-storyboard.md     # macOS / Linux
python  scripts\check_storyboard.py your-storyboard.md     # Windows
```

```
shots        : 6
total        : 30s
durations    : 0-5s, 5-10s, 10-16s, 16-21s, 21-26s, 26-30s
RESULT: PASS (0 warning)
```

核对：镜头数与编号、时长合计、时长连续性、单镜区间、四要素齐全、台词字数与时长匹配（中文口播 4–5 字/秒）、负面词存在。有 FAIL 返回退出码 1。

## 仓库结构

```
.
├── SKILL.md                    # 唯一事实源（DSH / Claude Code 直接用）
├── templates/headers.json      # 各 agent 的头部模板
├── build.ps1                   # SKILL.md → dist/ 的构建脚本
├── install.ps1 / install.sh    # 多 agent 安装器
├── dist/                       # 生成物，别手改
│   ├── AGENTS.md
│   ├── cursor.mdc
│   ├── windsurf.md
│   ├── cline.md
│   ├── copilot.instructions.md
│   ├── continue.md
│   ├── gemini.md
│   └── PROMPT.md
├── references/                 # 成品示例 + 词库（可选深水区）
└── scripts/check_storyboard.py # 分镜合规自检
```

**改规则只改 `SKILL.md`**，然后跑 `.\build.ps1` 重新生成 `dist/`。头部模板在 `templates/headers.json`，构建脚本本身保持纯 ASCII——Windows PowerShell 5.1 会把无 BOM 的 .ps1 按 ANSI 解码，中文写在脚本里会变成乱码。

## 可调项

默认 6 镜 30 秒竖屏。要 8 镜、45 秒、横屏 16:9、换主讲人性别年龄，直接说，技能会覆盖默认值并在交付首行标注偏离。

## License

MIT
