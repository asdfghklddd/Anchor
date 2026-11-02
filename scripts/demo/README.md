# 演示还原工具

在单独的 macOS 演示账户里，把 3 个演示项目、Codex 和 Claude Code 的对话、Anchor 的 Mac 数据一起存成一个起点，演示完一键回到那里。只在名为 `anchordemo` 的账户里运行，在别的账户里会直接拒绝。

## 第一次准备

1. 在系统设置 › 用户与群组里新建账户，短名称填 `anchordemo`。
2. 在你自己的账户里，把这个文件夹复制到两个账户都能读到的位置：

   ```bash
   cp -R scripts/demo /Users/Shared/AnchorDemoKit
   ```

3. 登录 `anchordemo` 账户，完成这几件事：
   - 登录 Codex 和 Claude。
   - 打开 Anchor，连接文件夹，并和 iPhone 配对。
   - 在 `~/AnchorDemo/` 里放好 3 个演示项目的 git 仓库，然后真跑几轮对话，攒出历史。
4. 准备好以后，在 `anchordemo` 账户里存下起点：

   ```bash
   /Users/Shared/AnchorDemoKit/anchor-demo.sh save
   ```

   如果哪个仓库还有没提交的改动，会拒绝保存。存的时候 Codex、Claude 和 Anchor 会先退出，存完再重新打开。

## 每次刷新

1. 在 iPhone 上打开设置 › 本地数据，点“从 Mac 重新同步”。**一定要先点手机。**
2. 在 Mac 上双击 `/Users/Shared/AnchorDemoKit/还原演示.command`，或者运行：

   ```bash
   /Users/Shared/AnchorDemoKit/anchor-demo.sh restore
   ```

Anchor 重新打开、手机连上之后，两边都会回到起点。

查看起点里存了什么：

```bash
/Users/Shared/AnchorDemoKit/anchor-demo.sh status
```

## 起点里有什么

- `~/AnchorDemo` 里的每个 git 仓库：存下当时的分支，并在那次提交上打标签 `anchor-demo-start`。还原时，演示中的改动、新文件和 agent 新开的分支都会被清掉。
- `~/.codex`，但不包括登录文件 `auth*.json`，所以登录状态不受影响。
- Claude Code 的对话：`~/.claude/projects` 等目录，以及 Claude App 里 Code 页面的会话列表。
- Anchor 的 Mac 数据（`~/Library/Application Support/Anchor`）和它的设置。设置里包括对话归档到哪个任务。

## 演示结束后移除

1. 删掉存下的起点和仓库里的标签。在 `anchordemo` 账户里运行：

   ```bash
   /Users/Shared/AnchorDemoKit/anchor-demo.sh remove
   ```

2. 在系统设置 › 用户与群组里删除 `anchordemo` 账户。这个账户里的所有东西会一起删掉，包括演示项目、对话和那份 Anchor 数据。
3. 在你自己的账户里删除这个工具：

   ```bash
   rm -rf /Users/Shared/AnchorDemoKit
   ```

4. 用你自己账户里的 Anchor 和 iPhone 重新配对。

你自己账户里的 Codex、Claude 和 Anchor 数据从头到尾不会被碰到。
