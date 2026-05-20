-- ============================================================
-- Live投票ツール用スキーマ (全テーブル + RLS)
-- Supabase Dashboard → SQL Editor で全文貼り付け → Run
-- 既存DBへの再実行も安全 (IF NOT EXISTS / DROP POLICY IF EXISTS)
-- ============================================================

-- ── セッション (進行中の出題状態を保持) ──
create table if not exists poll_sessions (
  code            text primary key,
  mode            text not null default 'wordcloud',  -- 'wordcloud' | 'ranking'
  question        text default '',
  options         jsonb default '[]'::jsonb,
  phase           text default 'idle',                -- 'idle' | 'live' | 'revealed'
  deadline        timestamptz,                        -- 投票締切時刻 (live中のみセット)
  time_limit_sec  int,                                -- 出題時の制限時間 (秒)
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- 既存DB向け: 後から追加した列をマイグレーション
alter table poll_sessions add column if not exists phase          text default 'idle';
alter table poll_sessions add column if not exists deadline       timestamptz;
alter table poll_sessions add column if not exists time_limit_sec int;

-- ── 学生の回答 ──
create table if not exists poll_responses (
  id          bigserial primary key,
  code        text not null references poll_sessions(code) on delete cascade,
  student_id  text not null,
  payload     jsonb not null,
  created_at  timestamptz default now(),
  unique (code, student_id)
);

create index if not exists idx_poll_responses_code on poll_responses(code);

-- ── 問題リスト (デック単位で講師が事前作成) ──
create table if not exists poll_questions (
  id              text primary key,
  deck            text not null default 'default',
  mode            text not null,                      -- 'wordcloud' | 'ranking'
  question        text not null,
  options         jsonb default '[]'::jsonb,
  time_limit_sec  int not null default 30,
  position        int not null default 0,
  created_at      timestamptz default now()
);

create index if not exists idx_poll_questions_deck on poll_questions(deck, position);

-- ============================================================
-- Row Level Security
-- 教室内ツール用:匿名アクセスを全て許可
-- (本番でセキュリティを強化する場合は anon の DELETE/UPDATE を絞る)
-- ============================================================
alter table poll_sessions  enable row level security;
alter table poll_responses enable row level security;
alter table poll_questions enable row level security;

drop policy if exists "anon read sessions"   on poll_sessions;
drop policy if exists "anon write sessions"  on poll_sessions;
drop policy if exists "anon read responses"  on poll_responses;
drop policy if exists "anon write responses" on poll_responses;
drop policy if exists "anon read questions"  on poll_questions;
drop policy if exists "anon write questions" on poll_questions;

create policy "anon read sessions"   on poll_sessions  for select using (true);
create policy "anon write sessions"  on poll_sessions  for all    using (true) with check (true);
create policy "anon read responses"  on poll_responses for select using (true);
create policy "anon write responses" on poll_responses for all    using (true) with check (true);
create policy "anon read questions"  on poll_questions for select using (true);
create policy "anon write questions" on poll_questions for all    using (true) with check (true);

-- ── 自動クリーンアップ関数(任意・推奨) ──
-- 24時間以上更新がないセッションを削除。pg_cronで毎日呼ぶか手動実行。
create or replace function cleanup_old_poll_sessions() returns void as $$
  delete from poll_sessions where updated_at < now() - interval '24 hours';
$$ language sql;
