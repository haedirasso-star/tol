-- ════════════════════════════════════════════════════════════════════
--  05 — قناة TOTV Live على Supabase (بدل Firestore)
--  • صف واحد فقط (id = 1) — يقرؤه التطبيق بالمفتاح العام (قراءة فقط)
--  • الكتابة من تطبيق الإدارة عبر دالة push (مفتاح الخدمة) — لا كتابة من التطبيق
--  شغّله مرة واحدة: Supabase ← SQL Editor ← الصق ← Run
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.live_channel (
  id          int primary key default 1 check (id = 1),
  visible     boolean     not null default false,
  on_air      boolean     not null default false,
  name        text        not null default 'TOTV Live',
  title       text        not null default '',
  subtitle    text        not null default '',
  poster      text        not null default '',
  url         text        not null default '',
  backup_url  text        not null default '',
  started_at  timestamptz,
  updated_at  timestamptz not null default now()
);
insert into public.live_channel (id) values (1) on conflict (id) do nothing;

alter table public.live_channel enable row level security;
drop policy if exists live_channel_read on public.live_channel;
create policy live_channel_read on public.live_channel for select to anon, authenticated using (true);

revoke insert, update, delete on public.live_channel from anon, authenticated;
grant select on public.live_channel to anon, authenticated;
