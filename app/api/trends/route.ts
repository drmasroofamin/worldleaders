import {NextRequest,NextResponse} from 'next/server';
import {supabaseAdmin} from '@/lib/supabase';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest){try{const {data,error}=await supabaseAdmin().rpc('public_vote_trends',{v_leader_id:req.nextUrl.searchParams.get('leader')||''});if(error)throw error;return NextResponse.json({points:data.map((d:any)=>({month:d.month,Support:Number(d.positive),Disapprove:Number(d.negative)}))})}catch{return NextResponse.json({error:'Vote trends are unavailable.'},{status:503})}}
