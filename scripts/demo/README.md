# 演示项目工具

用你现在的账户演示，不需要另建 macOS 账户。这个工具只做一件事：把 3 个演示项目复制到 `~/AnchorDemo`，演示后把这些副本还原到起点。

它不会碰 Agent 的对话、Anchor 的数据和你原来的项目。

## 第一次准备

```bash
~/Desktop/Anchor/Anchor/scripts/demo/anchor-demo.sh setup
```

大约需要 1–2 分钟，会占用约 900 MB。做出来的副本是：

| 文件夹 | 内容 | 分支 |
| --- | --- | --- |
| `anchor-old` | Anchor 的 4990ba5（10 月 29 日） | `demo` |
| `phase-ios` | `phase-ios-app` 当前的提交 | `ios/miniapp-parity` |
| `personal-site` | 个人网站，不带 `private_materials`、`output` 和 `dist` | `main` |

- 三个副本都没有 `origin`，Agent 推送不到 GitHub。
- `anchor-old` 只保留 `demo` 一个分支，Agent 看不到后来的真实修法。
- 已经存在的副本会跳过。想重做一个，先删掉那个文件夹，再运行一次 `setup`。

## 还原项目

先停掉正在这些副本里工作的 Agent，再双击 [还原演示.command](还原演示.command)，或者运行：

```bash
~/Desktop/Anchor/Anchor/scripts/demo/anchor-demo.sh reset
```

Agent 的改动、提交、新文件、新分支和 worktree 都会清掉。`node_modules`、`dist` 这类被 git 忽略的文件会留下，下次不用重新安装和构建。

查看每个副本现在改了多少：

```bash
~/Desktop/Anchor/Anchor/scripts/demo/anchor-demo.sh status
```

## 这个工具还原不了什么

对话和 Anchor 都不回滚。

- Agent 里的演示对话会留在历史记录里，归档到锚点的对话也还在。
- 勾掉的步骤、累计工作时长不会退回去。

只是再讲一遍的话，还原项目、开新对话重发任务就够了。想要全新的锚点，就结束旧的三个，在 iPhone 上新建，再跑一遍攒历史的任务。

## 演示结束后移除

1. 删掉演示副本：

   ```bash
   rm -rf ~/AnchorDemo
   ```

2. 在 iPhone 上结束三个演示锚点。Agent 里的演示对话想删的话，在各自的 App 里删。
3. 在 Anchor 设置里把“代理完成或等你时，在刘海上提示”改回你平时的状态。
4. 不再需要 `andy` 账户的话，在系统设置 › 用户与群组里删除它。如果 iPhone 上次是和 `andy` 配对的，要和你自己账户里的 Anchor 重新配对。
