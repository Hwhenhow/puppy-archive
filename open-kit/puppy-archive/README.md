# Puppy Archive · 可二创版本

一份单页应用（无框架、无构建、无依赖）的小狗档案库：记录一只狗的**信息、事件、局记录、技能树**，数据整库存本地浏览器，另有一份可选的云端副本用于跨设备同步。

这个包里**不含任何真实档案数据**，只有代码 + 通用模板 + 后端建表脚本。你可以随意改前端、换后端、换主题、换数据结构。

---

## 一、文件清单

| 文件 | 作用 | 能不能改 |
|---|---|---|
| `index.html` | 全部前端：样式、数据层、界面、交互（约 1500 行，分块注释） | 随便改 |
| `sdk.js` | 第三方云 SDK（WorkBuddy 云 / Genie BaaS），压缩过 | **别改**，用不到可以直接删 |
| `config.sample.js` | 云端配置模板，复制成 `config.js` 后填自己的值 | 填自己的 |
| `init.sql` | 后端建表 + 两个函数 + RLS，一次执行完 | 按需改 |
| `template.json` | 通用模板（技能树、字段分类、状态字典） | 随便改 |
| `icon-*.png` / `icon.svg` | 应用图标 | 换成自己的 |

---

## 二、三分钟跑起来

静态站点，没有任何构建步骤：

```bash
cd puppy-archive
python3 -m http.server 8080
# 浏览器打开 http://localhost:8080
```

> 必须走 http(s)，不能直接双击 `file://` 打开——口令哈希用的是 `crypto.subtle`，只在安全上下文可用（localhost 算安全上下文）。

**三种运行模式，取决于有没有 `config.js`：**

| 模式 | 条件 | 行为 |
|---|---|---|
| 仅本机 | 没有 `config.js`，或里面值为空 | 建档案、编辑、导入导出全部正常；右上角显示「仅本机（云端不可用）」 |
| 云端同步 | `config.js` 指向一个已建好 `init.sql` 的后端 | 整库自动同步，换设备输 4 位口令即可找回 |
| 只读演示 | 用别人的 `config.js` 但不带口令 | 停在启动页，看不到任何数据 |

---

## 三、架构

```
┌─────────────────────────── index.html ───────────────────────────┐
│                                                                  │
│  渲染层   render() → vHome / vSkills / vInfo / vEvents /          │
│                     vSessions / vPending / vSettings              │
│           全部是模板字符串，直接 innerHTML 覆盖 #app              │
│                              ↕                                   │
│  状态     S = { dogs, dog, facts, skills, sessions, events,       │
│                 pending, tab, openSession, ... }                  │
│                              ↕                                   │
│  数据层   T('表名') → class Q（select/insert/update/delete/eq/order）│
│           数据落在 STORE.db.tables[表名]，纯内存 + localStorage   │
│                              ↕                                   │
│  同步     touch() 标记 dirty → scheduleSync() → vaultPut()        │
│           启动/回前台时 vaultGet() 拉一次，用 rev 做乐观锁         │
└──────────────────────────────────────────────────────────────────┘
                    │ 只有两个 RPC
                    ├── vault_get(p_hash) → { data, rev }
                    └── vault_put(p_hash, p_data, p_base_rev) → { ok, rev }
```

**没有路由、没有组件、没有虚拟 DOM。** 改任何东西都是改一个函数里的模板字符串，刷新即可看到效果。

---

## 四、数据模型

### 4.1 逻辑表（都在 `COLS` 里定义，前端本地存放）

| 表 | 说明 | 关键字段 |
|---|---|---|
| `dogs` | 一只狗一行 | `code`(代号), `real_name`, `status`, `note` |
| `facts` | 信息条目 | `dimension`(person/session), `category`, `key`, `value`, `confidence`, `observed_on`, `superseded`, `sort` |
| `dog_skills` | 技能树节点 | `skill_key`, `level`(1–4), `name`, `status`, `first_date`, `effect`, `quote`, `feasible`, `sort` |
| `sessions` | 一局记录 | `seq`, `session_date`, `type`, `format`, `env`, `duration_min`, `summary`, `chat[]`, `report{}`, `skills_used[]`, `sort` |
| `events` | 事件 / 待办 | `kind`(event/todo), `title`, `detail`, `event_date`, `due_date`, `done`, `sort` |
| `pending` | AI 提议待确认队列 | `proposed_by`, `target_table`, `action`, `payload`, `status` |
| `attachments` | 附件元数据（预留） | `kind`, `name`, `storage_key`, `meta` |

每张表的完整字段列表就是 `COLS[表名]`；新建行时 `Q.build()` 会按 `COLS` 把所有字段补齐（缺的填 `null`），再套一层 `DEFAULTS` 里的默认值。**所以加字段 = 往 `COLS` 数组里加一个名字，不用写迁移脚本**（老数据读出来时该字段是 `undefined`，模板里用 `?.` 或兜底即可）。

### 4.2 本地存储（localStorage）

| key | 内容 |
|---|---|
| `pa_store_v1` | 整库：`{ code, hash, rev, dirty, ver, syncedAt, db:{ tables:{...}, seq:{...} } }` |
| `dogId` | 当前选中的狗 |
| `pa_hint_off` | 是否已关闭手势提示条 |
| `pa_backup` | 最近一次冲突前的备份（`{ at, side, db }`） |

### 4.3 云端存储（只有一个字段是重要的）

```sql
vault(code_hash text primary key, data jsonb, rev int, created_at, updated_at)
```

- `code_hash` = 口令的 PBKDF2 哈希，64 位 hex。
- `data` = **整个 `db` 对象的快照**（不是增量）。不做行级同步，简单但有效。
- `rev` = 版本号，每次写入 +1，用来做乐观锁。

所以「一个口令 = 一个库」，一个库里可以有多个 `dogs`。想做成多用户隔离，就是给 `vault` 加一列 `owner_id` 并在函数里校验——这是最适合入手的第一处后端改造。

---

## 五、口令与同步协议

1. 用户输入 4 位数字 → `hashCode()`：
   `PBKDF2-SHA256(口令, salt='puppy-archive/v2', 210000 次, 32 字节)` → 64 位 hex。
2. 用这个 hash 作为 `vault` 的主键，`vault_get / vault_put` 都只认它。
3. 写：`vault_put(hash, db, base_rev)`。如果 `base_rev` 落后于云端 rev，返回 `ok=false`，前端弹「用云端 / 用本机」，选本机时会先 `backup()` 再覆盖。
4. 网关偶发 502：`rpcRetry()` 只对 5xx 和网络错误重试 3 次，退避 700ms×n；业务错误立即抛。
5. 同步是后台的：界面永远不等云端。`touch()` 后 1.5 秒推送，回前台/联网时拉一次。

> 4 位口令只有 1 万种组合，PBKDF2 只是拖慢穷举，挡不住有耐心的攻击者。**这是刻意的取舍：为了让你自己能记住。** 要更强的安全性，改 `CODE_LEN`（让它支持 6–8 位）并重新设计输入框即可，`vault` 那侧不用动。

---

## 六、接自己的后端

前端只依赖一个极窄的接口：`cloud.database.rpc(fn, args)` 返回 `{ data, error, status }`。
整个应用里只有 `rpcRetry()` 一处调用它。所以换后端有两种做法：

### 6.1 直接用你的云应用（最省事）

1. 在你的 WorkBuddy 云 / Supabase 项目里执行 `init.sql`。
2. 把 `config.sample.js` 复制成 `config.js`，填 `endpoint` 和 `publishableKey`。
3. 完事。

### 6.2 换成任意后端（自建 API / Cloudflare / 自己的 Postgres）

把 `boot()` 里创建 cloud 的那一行替换成自己的适配对象即可：

```js
// 原来：cloud = WorkBuddyCloud.createWorkBuddyCloud(publicConfig);
cloud = {
  database: {
    async rpc(fn, args){
      const r = await fetch('/api/' + fn, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(args)              // { p_hash } 或 { p_hash, p_data, p_base_rev }
      });
      if (!r.ok) return { data: null, error: { message: 'HTTP ' + r.status }, status: r.status };
      const data = await r.json();              // 数组，元素形如 { data, rev } / { ok, rev }
      return { data, error: null, status: 200 };
    }
  }
};
```

后端只要实现两个路由，语义和 `init.sql` 里两个函数一一对应：`vault_get` 查一行、`vault_put` 按乐观锁写一行。**返回的必须是数组**（前端取 `rows[0]`）。

---

## 七、常见二创改动点

| 想做什么 | 改哪里 |
|---|---|
| 换主题色 / 字体 / 圆角 | `index.html` 顶部 `:root` 与 `@media (prefers-color-scheme:dark)` |
| 换应用名、图标 | `<title>`、`application-name`、`icon-*` 文件 |
| 改技能树 / 层级 / 分类字典 | `TEMPLATE`（`levels` / `skills` / `factCategories` / `skillStatus` / `confidence`），以及 `template.json` |
| 加一个字段 | `COLS` 加名字 → 表单字段数组（`FACT_FIELDS` / `EVENT_FIELDS` / `SKILL_FIELDS` / `sessionForm`）→ 渲染函数里显示 |
| 加一张表 | `COLS`、`DEFAULTS` 各加一项；`emptyDB()` 会自动带上（它遍历 `COLS`） |
| 加一个页面/标签 | `TABS` 加一项 → `render()` 里的 `body` 映射表加 `vYourTab` → 写 `function vYourTab(){}` |
| 改列表交互 | `bindGestures()`（指针逻辑）、`rowFact` / `rowEvent` / `vSkills` / `vSessions`（行结构，注意 `data-g`、`data-grp`、`data-gid`） |
| 改同步策略 | `scheduleSync` / `syncNow` / `pushLocal` / `adoptRemote` / `resolveConflict` |
| 加导出格式 / 对接 AI | `exportDog()`、`importJSON()`、`actions.approvePending()` |

---

## 八、两处值得先读懂的实现

### 8.1 手势：左滑操作 + 长按拖动排序

- 行结构固定为：`<div class="gest" data-g data-grp data-gid><div class="g-act">按钮…</div><div class="g-in">内容</div></div>`
  - `.g-act` 是滑开后露出的按钮层（绝对定位在右侧），`.g-in` 是内容层。
- `pointerdown` 后：横向位移 > 9px → 左滑；纵向 > 12px → 让给页面滚动；**按住 420ms 不动 → 卡片抬起（`startDrag`），进入拖动排序**。
- 拖动时用一个 `position:fixed` 的克隆做“悬浮卡片”，原行变成半透明虚线占位（`.drag-src`），随指针移动在 DOM 里换位置。
- 落手后 `commitOrder()` 把屏幕上的新顺序写回每行的 `sort` 字段；`applySort()` 在渲染时按 `sort` 稳定排序。
- 分组由 `data-grp` 决定（如 `fact:person:基础`、`skill:2`），**跨组不能互换**，避免把不同分类/不同层级的行混在一起。

### 8.2 返回栈：手机返回键先关界面，再退出

- `pushLayer(closeFn, kind)`：每次弹出表单/对话框/局详情，压一层 `history`。
- `popLayer(value)`：界面自己关掉时先 `history.back()`，保持栈同步。
- `popstate`：系统返回键 → 关最上面一层。`kind` 目前有三类：`'form'`（表单）、`'dlg'`（确认框/菜单）、`'session'`（局详情）。
- 加新的全屏页时，照着 `openSession` / `closeSessionView` 写一对即可。

---

## 九、别动 / 容易踩的坑

1. **`hashCode()` 的 salt 和迭代次数不要改**，一改所有已存在的库都打不开（hash 变了，`vault` 里查不到）。
2. **`sdk.js` 不要改**；不用云端就删掉引用。
3. `must(promise, '标签')` 是统一的错误出口：失败会自动 toast 并抛出，别再包一层 try/catch 吞掉。
4. 所有写操作之后要 `await loadAll()`（重新从本地库读取并渲染），否则界面还是旧数据。
5. `render()` 是整页重建，**不要在里面保存 DOM 引用**（每次都是新节点）；事件全部委托在 `document` 上。
6. 手势的误触抑制：`GEST.suppress` 记录手势结束时间，350ms 内的点击会被吞掉，改交互时留意这个窗口。
7. `template.json` 和 `index.html` 里的 `TEMPLATE` 是两份，改模板要同步改（前者只用于导出给 AI 参考）。

---

## 十、调试

浏览器控制台里 `S`、`STORE`、`LAYERS`、`SYNC` 都是全局可访问的，可以直接查看/临时改动：

```js
S.tab = 'info'; render();                  // 直接切页
STORE.db.tables.facts                      // 看本地数据
cloud = null;                              // 断网模拟：进入仅本机模式
JSON.stringify(S.facts.map(f=>f.key+'#'+f.sort))   // 检查排序结果
```

自动化测试可以用无头 Chrome + CDP（`Input.dispatchMouseEvent` 发 mousedown → 等 600ms → mousemove → mouseup 就能模拟“长按拖动”）。

---

## 十一、已知限制（都是有意取舍）

- 单用户、单口令模型，没有账号体系，也没有多端实时协同（靠 rev 冲突人工选择）。
- 每次保存都推整库快照，库大了（> 几千条）会变慢；函数里限制 8MB。
- 没有 service worker，离线打不开（数据在 localStorage，不会丢）。
- 云端网关偶发 502，靠重试兜底，最坏情况会显示「未同步，稍后自动重试」。
- 4 位口令是弱口令，只防手滑，不防人。
