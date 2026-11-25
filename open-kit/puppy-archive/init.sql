-- ============================================================
-- Puppy Archive · 后端初始化（最小可用版本）
-- ------------------------------------------------------------
-- 整个后端只有一张表 + 两个函数。
-- 表开了 RLS 且不给任何策略 → 匿名角色不能直接读写，
-- 只能通过下面两个 SECURITY DEFINER 函数访问，
-- 于是“权限”完全由 code_hash（也就是口令）决定。
--
-- 在 WorkBuddy 云 / Supabase / 自建 Postgres 的 SQL 编辑器里整体执行即可。
-- ============================================================

create table if not exists public.vault (
  code_hash  text primary key,
  data       jsonb not null,
  rev        integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 不给任何策略：默认拒绝所有直连，只留函数这一条路
alter table public.vault enable row level security;

-- 读：返回 { data, rev, updated_at }
create or replace function public.vault_get(p_hash text)
returns table(data jsonb, rev integer, updated_at timestamptz)
language sql
security definer
set search_path to 'public'
as $function$
  select v.data, v.rev, v.updated_at
  from public.vault v
  where length(p_hash) = 64 and v.code_hash = p_hash
$function$;

-- 写：base_rev 是乐观锁。返回 { ok, rev }；ok=false 表示别人先写过，需要前端合并
create or replace function public.vault_put(p_hash text, p_data jsonb, p_base_rev integer)
returns table(ok boolean, rev integer)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare cur int;
begin
  if length(p_hash) <> 64 then raise exception 'bad code'; end if;
  if octet_length(p_data::text) > 8000000 then raise exception 'too large'; end if;

  select v.rev into cur from public.vault v where v.code_hash = p_hash for update;

  if not found then
    insert into public.vault(code_hash, data, rev) values (p_hash, p_data, 1);
    return query select true, 1;
    return;
  end if;

  if cur <> p_base_rev then
    return query select false, cur;           -- 版本冲突，交给前端处理
    return;
  end if;

  update public.vault set data = p_data, rev = cur + 1, updated_at = now()
  where code_hash = p_hash;
  return query select true, cur + 1;
end
$function$;

-- Postgres 默认给函数 PUBLIC 执行权限，正常不需要额外 grant。
-- 如果你的平台收紧了默认权限，补这两行：
-- grant execute on function public.vault_get(text) to public;
-- grant execute on function public.vault_put(text, jsonb, integer) to public;

-- 自测（可选）：
-- select * from public.vault_get(repeat('a', 64));                      -- 空表时应返回 0 行
-- select * from public.vault_put(repeat('a', 64), '{"tables":{}}'::jsonb, 0);  -- ok=true rev=1
-- select * from public.vault_put(repeat('a', 64), '{"tables":{}}'::jsonb, 0);  -- ok=false rev=1（版本冲突）
