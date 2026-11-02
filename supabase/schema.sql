-- Run once in a fresh Supabase project using the SQL editor.
create extension if not exists pgcrypto;
create table public.users (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null, email text not null, avatar text,
 role text not null default 'voter' check (role in ('voter','leader','admin')),
 created_at timestamptz not null default now()
);
create table public.leaders (
 id text primary key, user_id uuid unique references public.users(id),
 name text not null, country text not null, position text not null, bio text not null default '',
 verified boolean not null default false, cover_image text, avatar text, region text
);
create table public.work_posts (
 id text primary key default gen_random_uuid()::text, leader_id text not null references public.leaders(id),
 title text not null check(char_length(title) between 1 and 200), body text not null,
 images text[] not null default '{}' check(cardinality(images)<=5),
 category text not null check(category in ('Economy','Health','Education','Environment','Peace','Infrastructure')),
 country text not null, work_date date not null default current_date, created_at timestamptz not null default now()
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id),
 post_id text not null references public.work_posts(id), leader_id text not null references public.leaders(id),
 stripe_session_id text unique, checkout_key uuid not null, unique(user_id,checkout_key), type text not null check(type in ('positive','negative')),
 quantity integer not null check(quantity between 1 and 100), reason text not null check(char_length(trim(reason)) between 20 and 1000),
 amount integer not null check(amount=quantity*100), currency text not null default 'usd' check(currency='usd'),
 status text not null default 'pending' check(status in ('pending','paid','refunded','failed')),
 created_at timestamptz not null default now()
);
create table public.votes (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id),
 post_id text not null references public.work_posts(id), leader_id text not null references public.leaders(id),
 type text not null check(type in ('positive','negative')), quantity integer not null check(quantity between 1 and 100),
 amount_usd numeric(10,2) not null check(amount_usd=quantity), payment_id uuid not null unique references public.payments(id),
 refunded boolean not null default false, created_at timestamptz not null default now()
);
create table public.comments (
 id uuid primary key default gen_random_uuid(), vote_id uuid not null unique references public.votes(id),
 user_id uuid not null references public.users(id), post_id text not null references public.work_posts(id),
 text text not null check(char_length(trim(text)) between 20 and 1000), hidden boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.replies (
 id uuid primary key default gen_random_uuid(), comment_id uuid not null references public.comments(id),
 user_id uuid not null references public.users(id), text text not null check(char_length(text) between 1 and 1000), created_at timestamptz not null default now()
);
create table public.reports (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id),
 comment_id uuid not null references public.comments(id), reason text not null check(char_length(reason) between 10 and 1000),
 status text not null default 'open' check(status in ('open','reviewed','dismissed')), created_at timestamptz not null default now(), unique(user_id,comment_id)
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id), message text not null,
 read boolean not null default false, created_at timestamptz not null default now()
);
create table public.checkout_limits (user_id uuid primary key references public.users(id),window_start timestamptz not null default now(),attempts integer not null default 0);

create function public.handle_signup() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.users(id,name,email,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','WorldVote member'),new.email,'voter'); return new; end $$;
create trigger on_auth_signup after insert on auth.users for each row execute function public.handle_signup();

create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.users where id=auth.uid() and role='admin'); $$;
create function public.consume_checkout_limit(v_user_id uuid) returns boolean language plpgsql security definer set search_path=public as $$
declare n integer;
begin
 insert into checkout_limits(user_id,attempts) values(v_user_id,1)
 on conflict(user_id) do update set attempts=case when checkout_limits.window_start<now()-interval '1 minute' then 1 else checkout_limits.attempts+1 end,
 window_start=case when checkout_limits.window_start<now()-interval '1 minute' then now() else checkout_limits.window_start end returning attempts into n;
 return n<=5;
end $$;

-- One transaction, row lock, unique payment ID: webhook retries never duplicate votes.
create function public.confirm_paid_vote(v_payment_id uuid,v_session_id text,v_amount integer,v_currency text) returns void language plpgsql security definer set search_path=public as $$
declare p public.payments; v_vote_id uuid;
begin
 select * into p from payments where id=v_payment_id for update;
 if not found then raise exception 'Unknown payment'; end if;
 if p.amount<>v_amount or v_currency<>'usd' then raise exception 'Payment amount/currency mismatch'; end if;
 if p.stripe_session_id is not null and p.stripe_session_id<>v_session_id then raise exception 'Payment session mismatch'; end if;
 if p.status='paid' then return; end if;
 if p.status<>'pending' then raise exception 'Invalid payment state'; end if;
 if not exists(select 1 from users where id=p.user_id and role='voter') then raise exception 'Voter role required'; end if;
 if not exists(select 1 from work_posts where id=p.post_id and leader_id=p.leader_id) then raise exception 'Leader mismatch'; end if;
 update payments set status='paid',stripe_session_id=v_session_id where id=p.id;
 insert into votes(user_id,post_id,leader_id,type,quantity,amount_usd,payment_id) values(p.user_id,p.post_id,p.leader_id,p.type,p.quantity,p.quantity,p.id) returning id into v_vote_id;
 insert into comments(vote_id,user_id,post_id,text) values(v_vote_id,p.user_id,p.post_id,p.reason);
 insert into notifications(user_id,message) values(p.user_id,'Your vote was posted. Thank you for sharing your perspective.');
end $$;
revoke all on function public.confirm_paid_vote(uuid,text,integer,text) from public,anon,authenticated;
grant execute on function public.confirm_paid_vote(uuid,text,integer,text) to service_role;
revoke all on function public.consume_checkout_limit(uuid) from public,anon,authenticated;
grant execute on function public.consume_checkout_limit(uuid) to service_role;

alter table public.users enable row level security;
alter table public.leaders enable row level security;
alter table public.work_posts enable row level security;
alter table public.payments enable row level security;
alter table public.votes enable row level security;
alter table public.comments enable row level security;
alter table public.replies enable row level security;
alter table public.reports enable row level security;
alter table public.notifications enable row level security;
alter table public.checkout_limits enable row level security;
create policy "Own profile" on users for select using(id=auth.uid() or public.is_admin());
create policy "Verified leaders are public" on leaders for select using(verified or public.is_admin());
create policy "Admins manage leaders" on leaders for all using(public.is_admin()) with check(public.is_admin());
create policy "Public work updates" on work_posts for select using(exists(select 1 from leaders where id=leader_id and verified));
create policy "Leaders publish own work" on work_posts for insert with check(exists(select 1 from leaders join users on leaders.user_id=users.id where leaders.id=leader_id and users.id=auth.uid() and users.role='leader' and leaders.verified));
create policy "Own payment records" on payments for select using(user_id=auth.uid() or public.is_admin());
create policy "Own vote history" on votes for select using(user_id=auth.uid() or public.is_admin());
create policy "Visible comments" on comments for select using(not hidden or public.is_admin());
create policy "Admins moderate" on comments for update using(public.is_admin()) with check(public.is_admin());
create policy "Public leader replies" on replies for select using(true);
create policy "Leaders reply on own posts" on replies for insert with check(user_id=auth.uid() and exists(select 1 from comments c join work_posts p on p.id=c.post_id join leaders l on l.id=p.leader_id join users u on u.id=l.user_id where c.id=comment_id and l.user_id=auth.uid() and l.verified and u.role='leader'));
create policy "Members report comments" on reports for insert with check(user_id=auth.uid());
create policy "Own reports and admins" on reports for select using(user_id=auth.uid() or public.is_admin());
create policy "Admins review reports" on reports for update using(public.is_admin()) with check(public.is_admin());
create policy "Own notifications" on notifications for select using(user_id=auth.uid());
create policy "Mark own notifications" on notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
-- No client insert/update policies exist for payments or votes. Profile roles cannot be self-edited.
create index votes_leader_time on votes(leader_id,created_at);
create index posts_leader on work_posts(leader_id);
create index comments_post on comments(post_id);
create index payments_user_time on payments(user_id,created_at);
create view public.leader_rankings as select l.id,l.name,l.country,l.avatar,
 coalesce(sum(v.quantity) filter(where v.type='positive' and not v.refunded),0) as positive,
 coalesce(sum(v.quantity) filter(where v.type='negative' and not v.refunded),0) as negative,
 coalesce(sum(case when v.refunded then 0 when v.type='positive' then v.quantity else -v.quantity end),0) as net
 from leaders l left join votes v on v.leader_id=l.id where l.verified group by l.id;
grant select on public.leader_rankings to anon,authenticated;
-- Enable Realtime only for public posts/leader records; never expose payment rows.
alter publication supabase_realtime add table public.work_posts, public.leaders;

-- Public read, verified-leader upload, max 5 MB/image. Post attachment count is constrained above.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('work-images','work-images',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy "Public work images" on storage.objects for select using(bucket_id='work-images');
create policy "Verified leaders upload images" on storage.objects for insert to authenticated with check(bucket_id='work-images' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.leaders where user_id=auth.uid() and verified));

-- Safe public projections expose display names and paid participation, never emails/payment IDs.
create view public.public_comments as
 select c.id,c.post_id,c.text,c.created_at,u.name,v.type,v.quantity,
 coalesce((select json_agg(json_build_object('text',r.text,'name',ru.name,'created_at',r.created_at)) from replies r join users ru on ru.id=r.user_id where r.comment_id=c.id),'[]') as replies
 from comments c join users u on u.id=c.user_id join votes v on v.id=c.vote_id where not c.hidden and not v.refunded;
grant select on public.public_comments to anon,authenticated;
create function public.public_rankings(v_since timestamptz default '-infinity') returns table(id text,positive bigint,negative bigint,net bigint) language sql stable security definer set search_path=public as $$
 select l.id,coalesce(sum(v.quantity) filter(where v.type='positive'),0)::bigint,coalesce(sum(v.quantity) filter(where v.type='negative'),0)::bigint,
 coalesce(sum(case when v.type='positive' then v.quantity else -v.quantity end),0)::bigint
 from leaders l left join votes v on v.leader_id=l.id and not v.refunded and v.created_at>=v_since where l.verified group by l.id;
$$;
create function public.public_post_stats() returns table(post_id text,positive bigint,negative bigint,comments bigint) language sql stable security definer set search_path=public as $$
 select p.id,coalesce(sum(v.quantity) filter(where v.type='positive'),0)::bigint,coalesce(sum(v.quantity) filter(where v.type='negative'),0)::bigint,count(v.id) from work_posts p join leaders l on l.id=p.leader_id and l.verified left join votes v on v.post_id=p.id and not v.refunded group by p.id;
$$;
create function public.admin_create_leader(v_user_id uuid,v_name text,v_country text,v_position text) returns text language plpgsql security definer set search_path=public as $$
declare lid text:=gen_random_uuid()::text;
begin
 if not exists(select 1 from auth.users where id=v_user_id and email_confirmed_at is not null) then raise exception 'Verified email required'; end if;
 update users set role='leader' where id=v_user_id;
 if not found then raise exception 'User not found'; end if;
 insert into leaders(id,user_id,name,country,position,verified) values(lid,v_user_id,v_name,v_country,v_position,true);
 return lid;
end $$;
revoke all on function public.admin_create_leader(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.admin_create_leader(uuid,text,text,text) to service_role;

alter table public.leaders add column last_vote_at timestamptz;
create function public.signal_ranking_change() returns trigger language plpgsql security definer set search_path=public as $$
begin update leaders set last_vote_at=now() where id=new.leader_id; return new; end $$;
create trigger on_vote_change after insert or update on public.votes for each row execute function public.signal_ranking_change();

create function public.confirm_full_refund(v_session_id text) returns void language plpgsql security definer set search_path=public as $$
declare p public.payments;
begin
 select * into p from payments where stripe_session_id=v_session_id for update;
 if not found then raise exception 'Unknown payment'; end if;
 if p.status='refunded' then return; end if;
 if p.status<>'paid' then raise exception 'Payment not confirmed yet'; end if;
 update payments set status='refunded' where id=p.id;
 update votes set refunded=true where payment_id=p.id;
 insert into notifications(user_id,message) values(p.user_id,'Your payment was refunded and its votes were reversed.');
end $$;
revoke all on function public.confirm_full_refund(text) from public,anon,authenticated;
grant execute on function public.confirm_full_refund(text) to service_role;
create function public.public_vote_trends(v_leader_id text) returns table(month text,positive bigint,negative bigint) language sql stable security definer set search_path=public as $$
 select to_char(date_trunc('month',v.created_at),'Mon'),
 coalesce(sum(v.quantity) filter(where v.type='positive'),0)::bigint,
 coalesce(sum(v.quantity) filter(where v.type='negative'),0)::bigint
 from votes v join leaders l on l.id=v.leader_id and l.verified
 where v.leader_id=v_leader_id and not v.refunded and v.created_at>=date_trunc('month',now())-interval '5 months'
 group by date_trunc('month',v.created_at) order by date_trunc('month',v.created_at);
$$;

revoke update on public.notifications from authenticated;
grant update(read) on public.notifications to authenticated;
alter table public.users add column public_profile boolean not null default true;
create or replace view public.public_comments as
 select c.id,c.post_id,c.text,c.created_at,case when u.public_profile then u.name else 'WorldVote member' end as name,v.type,v.quantity,
 coalesce((select json_agg(json_build_object('text',r.text,'name',ru.name,'created_at',r.created_at)) from replies r join users ru on ru.id=r.user_id where r.comment_id=c.id),'[]') as replies
 from comments c join users u on u.id=c.user_id join votes v on v.id=c.vote_id where not c.hidden and not v.refunded;
create table public.privacy_requests(user_id uuid primary key references public.users(id),status text not null default 'pending' check(status in ('pending','completed')),created_at timestamptz not null default now());
alter table public.privacy_requests enable row level security;
create policy "Own privacy requests" on public.privacy_requests for select using(user_id=auth.uid() or public.is_admin());
