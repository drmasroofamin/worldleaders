import {NextRequest,NextResponse} from 'next/server';
import {requireRole} from '@/lib/server';
import {z} from 'zod';
export async function POST(req:NextRequest){try{const {db,user}=await requireRole(req,['voter','leader','admin']);const body=z.object({commentId:z.string().uuid(),reason:z.string().trim().min(10).max(1000)}).parse(await req.json());const {error}=await db.from('reports').insert({user_id:user.id,comment_id:body.commentId,reason:body.reason});if(error)throw error;return NextResponse.json({ok:true})}catch{return NextResponse.json({error:'Unable to submit report. Sign in and provide a reason of at least 10 characters.'},{status:400})}}
