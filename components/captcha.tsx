'use client';
import Script from 'next/script';
import {useEffect,useRef,useState} from 'react';
type Turnstile={render:(el:HTMLElement,options:Record<string,unknown>)=>string;remove:(id:string)=>void};
export default function Captcha({onToken}:{onToken:(token:string)=>void}){const ref=useRef<HTMLDivElement>(null);const [loaded,setLoaded]=useState(false);const sitekey=process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;
useEffect(()=>{const api=(window as unknown as {turnstile?:Turnstile}).turnstile;if(!loaded||!ref.current||!api||!sitekey)return;const id=api.render(ref.current,{sitekey,callback:onToken,'expired-callback':()=>onToken(''),'error-callback':()=>onToken('')});return()=>{api.remove(id)}},[loaded,sitekey,onToken]);
if(!sitekey)return <p className="muted" style={{fontSize:10,lineHeight:1.7,marginBottom:15}}>Public signups need CAPTCHA configuration. You can use an existing account or Google sign in.</p>;return <><Script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" onReady={()=>setLoaded(true)}/><div ref={ref} style={{marginBottom:20}}/></>}
