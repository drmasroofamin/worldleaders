import WorldVote from '@/components/worldvote';
export default async function Page({params}:{params:Promise<{path:string[]}>}){return <WorldVote initialPage={(await params).path.join('/')}/>}
