import {NextRequest,NextResponse} from 'next/server';
import {requireVoter} from '@/lib/server';
export async function GET(req:NextRequest){try{const {db,user}=await requireVoter(req);const {data,error}=await db.from('votes').select('*, comments(text)').eq('user_id',user.id).order('created_at',{ascending:false});if(error)throw error;return NextResponse.json({votes:data},{headers:{'Cache-Control':'no-store'}})}catch{return NextResponse.json({error:'Sign in to view your votes.'},{status:401})}}
