-- ============================================================
-- Live投票ツール用テーブル
-- 既存のSupabaseプロジェクト(gmkrsgqgndlrabiicvkh)にそのまま追加可能
-- Supabase Dashboard → SQL Editor で全文貼り付け→ Run
-- ============================================================

create table if not exists poll_sessions (
  code        text primary key,
  mode        text not null default 'choice',
  question    text default '',
  options     jsonb default '[]'::jsonb,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists poll_responses (
  id          bigserial primary key,
  code        text not null references poll_sessions(code) on delete cascade,
  student_id  text not null,
  payload     jsonb not null,
  created_at  timestamptz default now(),
  unique (code, student_id)
);

create index if not exists idx_poll_responses_code on poll_responses(code);

-- ── Row Level Security ──
-- 教室内ツール用:匿名アクセスを全て許可(認証なし)
alter table poll_sessions  enable row level security;
alter table poll_responses enable row level security;

drop policy if exists "anon read sessions"  on poll_sessions;
drop policy if exists "anon write sessions" on poll_sessions;
drop policy if exists "anon read responses" on poll_responses;
drop policy if exists "anon write responses" on poll_responses;

create policy "anon read sessions"  on poll_sessions  for select using (true);
create policy "anon write sessions" on poll_sessions  for all    using (true) with check (true);
create policy "anon read responses" on poll_responses for select using (true);
create policy "anon write responses" on poll_responses for all    using (true) with check (true);

-- ── 自動クリーンアップ用関数(任意・推奨) ──
-- 24時間以上更新がないセッションを削除。pg_cronで毎日呼ぶか手動実行。
create or replace function cleanup_old_poll_sessions() returns void as $$
  delete from poll_sessions where updated_at < now() - interval '24 hours';
$$ language sql;
