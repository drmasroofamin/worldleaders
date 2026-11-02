import {NextResponse} from 'next/server';
import {supabaseAdmin} from '@/lib/supabase';
export const dynamic='force-dynamic';
export async function GET(_req:Request,{params}:{params:Promise<{id:string}>}){if(!process.env.SUPABASE_SERVICE_ROLE_KEY)return NextResponse.json({demo:true});try{const {data,error}=await supabaseAdmin().from('public_comments').select('*').eq('post_id',(await params).id).order('created_at',{ascending:false}).limit(100);if(error)throw error;return NextResponse.json({comments:data},{headers:{'Cache-Control':'no-store'}})}catch{return NextResponse.json({error:'Comments unavailable.'},{status:503})}}
