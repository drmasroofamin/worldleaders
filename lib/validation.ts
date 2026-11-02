import {z} from 'zod';
export const voteSchema=z.object({postId:z.string().min(1).max(100),type:z.enum(['positive','negative']),quantity:z.number().int().min(1).max(100),reason:z.string().trim().min(20).max(1000)}).strict();
