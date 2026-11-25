# Puppy Archive · Agent 维护手册

本文件给 AI agent 读。你的任务是和用户一起维护小狗档案：把对话里出现的事实整理进档案，保持简洁、客观、准确、具体。

## 1. 记录原则

1. 一条一事，只写事实，不写评价。原话用引号，不改写。
2. 不模糊化。真名、学校、城市、时间都照实写；用户说明隐私不重要。
3. 每条信息带来源、日期、可信度：
   - `stated` 亲口说的
   - `observed` 观察到的
   - `inferred` 推测的
   - `unverified` 待确认
4. 新旧值并存，不覆盖。信息变了就新增一条，旧条标 `superseded = true`。
5. 只有对方一侧的聊天截图时，凡是靠单字回答（“嗯”“是”“对”）推断的内容，一律标 `unverified`，并问用户。
6. 区分“她本人”和“局内角色”。她说过“我没那么喜欢被调，我只是热爱极品青年音”这类话，要如实记在个人维度，不要和局内表现混写。
7. 前置条件（破冰、信任、延续、角色）由用户自己判断，不做校验，不写进技能树。跨平台、见面等信息写进 `dogs.note`。
8. 平台生成的报告不一定准确，只作为一项输入，存在 `sessions.report` 里，不据此下结论。

## 2. 两个维度

- 个人维度 `facts.dimension = 'person'`：基础、学业与生活、作息与环境、声音与表达、偏好、雷区与禁忌、健康与安全、平台与联系。
- 局内维度 `facts.dimension = 'session'`：姿势动作、道具、节奏、局内反应。
- 姿势动作类记在局内维度。有明确个人偏好的（例如“趴着”“揉小腹”）同时再记一条个人维度。

## 3. 技能树

`dog_skills` 每只小狗一套，由通用模板初始化，共 24 个节点，分 L1 基础、L2 进阶、L3 高控制、L4 深度。

状态：`untried` 未尝试、`tried` 已尝试、`mastered` 已掌握、`dropped` 淘汰。

每个节点记：首次日期 `first_date`、效果 `effect`、她的原话 `quote`、对她是否可行 `feasible`（yes / no）和原因 `feasible_note`（如打字模式、宿舍不能出声）。

某局用到了哪些玩法，写进 `sessions.skills_used`（技能 key 数组），同时更新对应节点状态。

## 4. 数据结构

整库是一个 JSON 文档（网页导出的“完整备份”，格式 `puppy-archive-db/1`）：

```
{ "schema": "puppy-archive-db/1",
  "db": { "tables": { dogs, facts, dog_skills, sessions, events, pending, attachments }, "seq": { 表名: 当前最大 id } } }
```

每张表是行数组，每行有数值 `id`。新增行时 `id = seq[表] + 1`，并把 `seq[表]` 同步加一；行内的 `dog_id`、`session_id` 引用对应行的 `id`。

| 表 | 用途 | 关键字段 |
|---|---|---|
| dogs | 小狗 | code 称呼、real_name、status、note |
| facts | 个人信息 | dog_id、dimension、category、key、value、confidence、observed_on、source、superseded、note |
| dog_skills | 技能节点 | dog_id、skill_key、level、name、status、first_date、effect、quote、feasible、feasible_note |
| sessions | 局记录 | dog_id、seq、session_date、type（play/chat/other）、format、env、duration_min、summary、chat(数组 `{who:'dog'|'me', text}`)、report、skills_used(数组) |
| events | 事件与待办 | dog_id、session_id、kind（event/todo）、title、detail、event_date、due_date、done |
| pending | 待确认队列 | dog_id、proposed_by、target_table、action（insert/update）、target_id、payload、reason、status（open/approved/rejected） |
| attachments | 附件索引 | dog_id、session_id、kind、name、storage_key、meta |

`facts`、`events`、`sessions`、`dog_skills` 都多一个可选字段 `sort`（整数）。这是用户在网页里长按「上移 / 下移」手动排出来的顺序，网页展示时优先按它排，没填的排在后面并保持默认次序。新增记录时**不用**填 `sort`；也**不要**批量重排它，除非用户明确要求改顺序。

## 5. 存储与写入方式

网站没有账号。数据在用户浏览器本机，同时按“口令”在云端存一份。

- 口令：**4 位数字**，由用户自己定（这个口令不在文档里记录，需要时向用户本人确认）。这是弱口令，等于用 1 万种可能保护一份数据，只能防手滑、不能防人；因此**不要把本页链接连同口令一起发给别人**，也不要写进公开的地方。
- 云端只存哈希：`code_hash = PBKDF2-SHA256(口令, salt='puppy-archive/v2', iterations=210000, 32 bytes)` 的 64 位十六进制。代码见网页 `hashCode()`，改算法会导致旧数据取不回来，不要动。
- 云端表 `vault(code_hash, data JSONB, rev INT)`，应用 ID `wbapp_LJnw4qnrUtFug4M4UWBFGM`。表本身不可直接读写，只能通过两个函数：
  - `vault_get(p_hash)` 返回 `data, rev, updated_at`。
  - `vault_put(p_hash, p_data, p_base_rev)` 返回 `ok, rev`。`p_base_rev` 必须等于当前云端 `rev`，否则返回 `ok=false`，说明有人已改过，需重新读取后合并再写。
- 平台网关有约 15% 的间歇性 502，读写失败要重试，最多 3 次，间隔递增。

### 推荐协作方式（改完网页自动拉取）

1. 用户在网页“设置 → 导出全部备份”，把文件交给你；或者你把要改的内容整理好，让用户在网页上直接改。
2. 你读取整库，按第 6 节处理新材料，产出修改后的完整库。
3. 通过 `vault_put` 写回（`p_base_rev` 取刚读到的 `rev`）。网页下次打开或回到前台时会拉取；若用户本机有未同步改动，会弹出冲突选择并先留备份。
4. 若不能访问云端，就把修改后的 JSON 交给用户，在网页“设置 → 导入 JSON”导入。

调用示例（云数据库工具，`mode=read` 即可调用 RPC 之外的查询；写入用 `write`）：

```sql
SELECT * FROM public.vault_get($1)
SELECT * FROM public.vault_put($1, $2::jsonb, $3)
```

`$1` 是 `code_hash`，不是口令。手边没有现成哈希时，可以先列出来：

```sql
SELECT left(code_hash,16), rev, updated_at FROM public.vault
```

这个库里只有用户一份档案，所以通常只有一行，取那一行的完整 `code_hash` 即可。要由口令现算哈希，用 Node（与网页算法一致）：

```js
const { pbkdf2Sync } = require('node:crypto');
pbkdf2Sync('<口令>', 'puppy-archive/v2', 210000, 32, 'sha256').toString('hex');
```

### 谁可以直接写，谁要进队列

- 用户明确说了“记一下”的内容：可直接写入。
- 你从聊天里推断、归属不确定、会覆盖旧值的内容：**写入 `pending` 表**，由用户在网页“待确认”页点确认。

队列行示例：

```json
{ "dog_id": 1, "proposed_by": "agent", "target_table": "facts", "action": "insert",
  "payload": {"dimension":"person","category":"基础","key":"籍贯","value":"太原","confidence":"unverified","source":"11/25 聊天局"},
  "reason": "截图只有她一侧，无法确定“太原”是她说的还是回答你的问题", "status": "open" }
```

`payload` 的键必须是目标表的真实列名，不要放 `id`、`dog_id`，网页确认时会补上。

## 6. 处理一局新记录的流程

1. 读用户给的材料（截图 OCR、聊天文本、平台报告）。
2. 新建 `sessions` 一行，填日期、类型、形式、环境、摘要；聊天原文存进 `chat`；平台报告存进 `report`。
3. 从中抽取事实，按第 5 节决定直接写还是进队列。
4. 更新技能树：这一局用到的玩法，改状态、填首次日期、效果、原话、可行性。
5. 抽取待办和承诺（谁答应了什么、约了什么时候），写进 `events`，`kind = 'todo'`。
6. 追加本地镜像（见第 7 节）。
7. 向用户汇报：新增了什么、哪些进了待确认、有哪些需要他确认的歧义。

## 7. 本地镜像

目录：`archive-kit/mirror/<code>/`

```
<code>.json        完整档案
sync.json          { "lastSyncedAt": "ISO 时间", "rev": 云端版本号 }
changes.log        每次改动一行：时间 | 表 | 操作 | 摘要
```

- 每次写云端后，同步更新镜像文件，并刷新 `sync.json`。
- 冲突时不要擅自覆盖：重新读取云端，合并后再写；被覆盖的旧值写入 `changes.log`。
- 网页本身也会在“设置 → 导出全部备份”里生成同格式文件，可随时手动放进镜像目录。

## 8. 新建小狗

读 `template.json`：`skills` 数组是技能树节点，`factCategories` 是信息分类。在 `dogs` 加一行后，把 24 个节点批量加入 `dog_skills`（`skill_key`、`level`、`name`）。网页的“新建小狗”按钮做的是同样的事。

## 9. 不要做的事

- 不要删除记录；需要作废就标 `superseded` 或把技能标 `dropped`。
- 不要把推测写成事实。
- 不要在网站目录里放个人数据文件，网站目录会被发布。
- 不要直接改动或删除云端 `vault` 表，只通过 `vault_get` / `vault_put`。
- 不要覆盖云端 `rev` 不一致的数据。
