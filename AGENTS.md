# 协作规则

## 改动隔离（重要）

本仓库可能有多个 agent 会话并行工作。**每次改动都必须在自己的分支 + 独立的 git worktree 里进行**，禁止直接在主工作目录或 `master` 上改。

主工作目录 `/Users/ershi/Workspace/好好吃饭app` 视为共享区：只用于读代码、跑测试、安装到设备。不要在里面切换分支。

### 开工前

```sh
# 每个任务一个 worktree，放在主目录之外
git -C /Users/ershi/Workspace/好好吃饭app fetch origin
git -C /Users/ershi/Workspace/好好吃饭app worktree add \
  /Users/ershi/Workspace/好好吃饭app-wt/<短任务名> \
  -b <type>/<短任务名> origin/master

cd /Users/ershi/Workspace/好好吃饭app-wt/<短任务名>
```

分支名沿用仓库习惯的 `<type>/<slug>`：`feat/`、`fix/`、`refactor/`、`docs/`、`style/`、`chore/`。

### 提交前

- 只 `git add` 自己这次改的文件，逐条显式列出；**不要** `git add -A` / `git add .`
- `git status` 里出现自己没写过的文件，说明该 worktree 不干净，停下来查清楚再继续
- 改了 `README.md` / `README.en.md` 这类共享文档时，只提交自己那几条，别把别人的段落一起带上
- 提交前跑 `dart format .`、`flutter analyze`，以及受影响的 `flutter test` 子集

### 开 PR / 合并前（血的教训）

**push 之后、merge 之前，必须重新确认 PR 的 head 是哪个提交**：

```sh
gh pr view <n> --json headRefOid,headRefName,commits
git fetch origin && git log --oneline origin/<branch> -3
```

如果 head 不是你最后推送的提交，说明有人往你的分支上追加了内容——先停下来，问清楚，不要 merge。

合并用 squash，并确认 `gh pr view <n> --json files` 的文件列表只含自己的改动：

```sh
gh pr merge <n> --squash --delete-branch
gh pr view <n> --json files   # 事后核对
```

### 收尾

```sh
git -C /Users/ershi/Workspace/好好吃饭app worktree remove \
  /Users/ershi/Workspace/好好吃饭app-wt/<短任务名>
```
