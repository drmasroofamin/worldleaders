import {NextRequest,NextResponse} from 'next/server';
import {requireRole} from '@/lib/server';
export async function GET(req:NextRequest){try{const {db,user}=await requireRole(req,['voter','leader','admin']);const {data,error}=await db.from('notifications').select('id,message,read,created_at').eq('user_id',user.id).order('created_at',{ascending:false}).limit(30);if(error)throw error;return NextResponse.json({notifications:data},{headers:{'Cache-Control':'no-store'}})}catch{return NextResponse.json({error:'Please sign in.'},{status:401})}}
