# Puppy Archive

一个单页 PWA 形态的「小狗档案」应用：按人建档，记录信息、事件、局记录与技能树，可选云端同步，无需注册账号。

前端是纯手写 HTML/CSS/JS，没有构建步骤、没有依赖、没有 `node_modules`；后端只有一张表加两个 Postgres 函数。

## 三个目录分别是什么

| 目录 | 用途 | 该不该改 |
|---|---|---|
| `puppy-archive/` | **线上运行的版本**。线上站点就是从这里发布的 | 改这个 |
| `open-kit/puppy-archive/` | **对外分发的二创包**。配置为空值，拷出去直接是「仅本机」模式，不会连到任何人的云端 | 改完 `puppy-archive/` 后同步过来 |
| `archive-kit/` | 档案数据与协作说明（`AGENT_GUIDE.md`、通用模板） | 一般不改 |

`puppy-archive/` 与 `open-kit/puppy-archive/` 的 `index.html` 是同一份代码，差别只在 `config.js`：前者填了真实的云端地址与密钥（已被 `.gitignore` 排除，不入库），后者是空值。

## 三分钟跑起来

```bash
cd puppy-archive
python3 -m http.server 8080
# 浏览器打开 http://localhost:8080
```

没有 `config.js` 或值为空时，应用自动进入「仅本机」模式：建档、编辑、导入导出全部可用，只是不同步。想开启跨设备同步，见下面的后端部分。

## 文档

- **二创 / 二次开发**：从 [`open-kit/puppy-archive/README.md`](open-kit/puppy-archive/README.md) 开始。讲清了文件清单、架构、数据模型、口令与同步协议、怎么换成别的后端、常见改动点、容易踩的坑。
- **与 AI agent 协作维护档案**：见 [`archive-kit/AGENT_GUIDE.md`](archive-kit/AGENT_GUIDE.md)。

## 后端（可选）

整个后端只有：

- 一张 `vault(code_hash, data, rev)` 表，开启 RLS 且**不给任何策略**，所以匿名角色无法直接读写；
- 两个 `SECURITY DEFINER` 函数 `vault_get(p_hash)` / `vault_put(p_hash, p_data, p_base_rev)`，`p_base_rev` 是乐观锁。

建表脚本见 [`open-kit/puppy-archive/init.sql`](open-kit/puppy-archive/init.sql)，在任意 Postgres / Supabase / 云开发平台的 SQL 编辑器里整体执行即可。

## 关于口令

应用不设账号，靠一个口令派生出的 hash 定位数据：`PBKDF2-SHA256(口令, salt='puppy-archive/v2', 210000 次迭代, 32 字节)`，取 64 位 hex 作为 `code_hash`。

这意味着**安全强度等于口令本身**——设计上是为了防误操作、便于换设备找回，不是用来防人的。请不要把站点链接和口令一起发给别人。

## 许可

未声明许可证。默认保留所有权利；如需商用或再分发，请先联系作者。
