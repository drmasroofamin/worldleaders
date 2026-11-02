import test from 'node:test';
import assert from 'node:assert/strict';
import {voteSchema} from '../lib/validation';
const valid={postId:'solar-future',type:'positive',quantity:5,reason:'Clean energy with measurable benefits for communities.'};
test('accepts valid paid vote input',()=>assert.equal(voteSchema.parse(valid).quantity,5));
test('rejects free, fractional and excessive quantities',()=>{for(const quantity of [0,-1,1.5,101,Infinity])assert.equal(voteSchema.safeParse({...valid,quantity}).success,false)});
test('requires a substantive written reason',()=>{for(const reason of ['', 'short', ' '.repeat(30),'x'.repeat(1001)])assert.equal(voteSchema.safeParse({...valid,reason}).success,false)});
test('rejects amount tampering and invalid vote types',()=>{assert.equal(voteSchema.safeParse({...valid,amount:0}).success,false);assert.equal(voteSchema.safeParse({...valid,type:'neutral'}).success,false)});
