import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
test('PostgreSQL: schema, idempotent confirmation, amount integrity, refunds, RLS and rate limits',async()=>{
const db=new PGlite();
try{
await db.exec(`create role anon; create role authenticated; create role service_role bypassrls; create schema auth; create schema storage;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name,'/') $$;`);
// Supabase provides pgcrypto and the Realtime publication. Embedded PostgreSQL has UUIDs built in.
const schema=readFileSync('supabase/schema.sql','utf8').replace('create extension if not exists pgcrypto;','').replace('alter publication supabase_realtime add table public.work_posts, public.leaders;','');
await db.exec(schema);await db.exec(readFileSync('supabase/seed.sql','utf8'));
const uid='00000000-0000-4000-8000-000000000001';
await db.query(`insert into auth.users(id,email,raw_user_meta_data) values($1,'test@example.com','{"full_name":"Test Voter","role":"admin"}')`,[uid]);
assert.equal((await db.query<{role:string}>('select role from users where id=$1',[uid])).rows[0].role,'voter','signup metadata cannot escalate roles');
const {rows:[p]}=await db.query<{id:string}>(`insert into payments(user_id,post_id,leader_id,type,quantity,reason,amount,checkout_key,stripe_session_id) values($1,'solar-future','elena-martinez','negative',5,'I want to see a transparent breakdown of project costs.',500,gen_random_uuid(),'cs_test') returning id`,[uid]);
await assert.rejects(db.query(`select confirm_paid_vote($1,'cs_test',100,'usd')`,[p.id]),/mismatch/);
assert.equal((await db.query<{n:number}>('select count(*)::int as n from votes')).rows[0].n,0);
await db.query(`select confirm_paid_vote($1,'cs_test',500,'usd')`,[p.id]);
await db.query(`select confirm_paid_vote($1,'cs_test',500,'usd')`,[p.id]);
assert.equal((await db.query<{n:number}>('select count(*)::int as n from votes')).rows[0].n,1,'webhook retries must not duplicate votes');
assert.equal((await db.query<{n:number}>('select count(*)::int as n from comments')).rows[0].n,1);
assert.equal(Number((await db.query<{net:number}>(`select net from leader_rankings where id='elena-martinez'`)).rows[0].net),-5);
await db.exec(`select confirm_full_refund('cs_test'); select confirm_full_refund('cs_test');`);
assert.equal(Number((await db.query<{net:number}>(`select net from leader_rankings where id='elena-martinez'`)).rows[0].net),0,'refund removes net votes');
assert.equal((await db.query<{n:number}>('select count(*)::int as n from public_comments')).rows[0].n,0,'refunded comments are excluded');
for(let i=0;i<5;i++)assert.equal((await db.query<{allowed:boolean}>('select consume_checkout_limit($1) as allowed',[uid])).rows[0].allowed,true);
assert.equal((await db.query<{allowed:boolean}>('select consume_checkout_limit($1) as allowed',[uid])).rows[0].allowed,false);
await db.exec('set role anon');
await assert.rejects(db.query(`select confirm_paid_vote($1,'cs_test',500,'usd')`,[p.id]),/permission denied/);
await assert.rejects(db.query('select confirm_full_refund($1)',['cs_test']),/permission denied/);
await db.exec('reset role; grant usage on schema public,auth to authenticated; grant select,insert,update on all tables in schema public to authenticated;');
await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[uid]);await db.exec('set role authenticated');
await assert.rejects(db.query(`insert into votes(user_id,post_id,leader_id,type,quantity,amount_usd,payment_id) values($1,'solar-future','elena-martinez','positive',1,1,gen_random_uuid())`,[uid]),/row-level security/);
await db.query(`update users set role='admin' where id=$1`,[uid]);
assert.equal((await db.query<{role:string}>('select role from users where id=$1',[uid])).rows[0].role,'voter','client cannot edit role');
}finally{await db.close()}
});
