import {NextRequest,NextResponse} from 'next/server';
import {supabaseAdmin} from '@/lib/supabase';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest){try{const period=req.nextUrl.searchParams.get('period');const since=period==='This week'?new Date(Date.now()-7*86400000).toISOString():period==='This month'?new Date(new Date().getFullYear(),new Date().getMonth(),1).toISOString():'-infinity';const {data,error}=await supabaseAdmin().rpc('public_rankings',{v_since:since});if(error)throw error;return NextResponse.json({rankings:data},{headers:{'Cache-Control':'no-store'}})}catch{return NextResponse.json({error:'Rankings unavailable.'},{status:503})}}
