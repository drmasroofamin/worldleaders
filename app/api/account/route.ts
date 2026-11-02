import {NextRequest,NextResponse} from 'next/server';
import {requireRole} from '@/lib/server';
export async function GET(req:NextRequest){try{const {db,user,role}=await requireRole(req,['voter','leader','admin']);const {data}=await db.from('votes').select('quantity,amount_usd,leader_id').eq('user_id',user.id).eq('refunded',false);return NextResponse.json({role,votes:(data||[]).reduce((s,v)=>s+v.quantity,0),spent:(data||[]).reduce((s,v)=>s+Number(v.amount_usd),0)},{headers:{'Cache-Control':'no-store'}})}catch{return NextResponse.json({error:'Please sign in.'},{status:401})}}
