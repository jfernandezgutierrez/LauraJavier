import { createClient } from 'npm:@supabase/supabase-js@2.75.0'

const site = 'https://laura-y-javier-huellas.javiusx.chatgpt.site'
const allowedOrigins = [site, 'http://127.0.0.1:5173']
const escapeHtml = (s: string) => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!))
Deno.serve(async (req: Request) => {
 const origin = req.headers.get('origin') || site
 const headers = {'Content-Type':'application/json','Access-Control-Allow-Origin':allowedOrigins.includes(origin)?origin:site,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'}
 const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status, headers})
 if(req.method === 'OPTIONS') return new Response(null,{status:204,headers})
 if(req.method !== 'POST') return reply({error:'Método no permitido'},405)
 try {
  const authorization = req.headers.get('authorization') || ''
  if(!authorization.startsWith('Bearer ')) return reply({error:'Inicia sesión como administrador'},401)
  const client = createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}})
  const {data:identity,error:identityError} = await client.auth.getUser(authorization.slice(7))
  if(identityError || !identity.user) return reply({error:'Tu sesión no es válida'},401)
  const {data:admin,error:adminError} = await client.rpc('wedding_is_admin')
  if(adminError || !admin) return reply({error:'Solo los novios pueden enviar invitaciones'},403)
  const apiKey = Deno.env.get('RESEND_API_KEY'),from = Deno.env.get('WEDDING_FROM_EMAIL')
  if(!apiKey || !from) return reply({error:'La invitación está creada, pero no se ha enviado. Falta configurar el remitente de correo. Puedes copiar el enlace y compartirlo personalmente.'},503)
  const {pass_id,invite_token} = await req.json()
  if(typeof pass_id !== 'string' || typeof invite_token !== 'string' || !/^[a-f0-9]{64}$/.test(invite_token)) return reply({error:'Enlace no válido'},400)
  const {data:guest,error:guestError} = await client.rpc('wedding_prepare_invite_delivery',{pass_id,invite_token})
  if(guestError || !guest) return reply({error:guestError?.message || 'No se puede enviar esta invitación'},400)
  const link = `${site}/#invite=${invite_token}`
  const name = escapeHtml(guest.display_name),message = escapeHtml(guest.personal_message).replace(/\n/g,'<br>')
  const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(invite_token)))).map(n=>n.toString(16).padStart(2,'0')).join('')
  const delivery = await fetch('https://api.resend.com/emails',{method:'POST',headers:{'Authorization':`Bearer ${apiKey}`,'Content-Type':'application/json','Idempotency-Key':`wedding-${pass_id}-${digest}`},body:JSON.stringify({from,to:[guest.email],subject:`${guest.display_name}, tenemos una invitación para ti · Laura y Javier`,html:`<!doctype html><html lang="es"><body style="margin:0;background:#f5f0e6;font-family:Georgia,serif;color:#594936"><div style="max-width:560px;margin:30px auto;padding:38px;background:#fffaf1;border:1px solid #ded1bb;text-align:center"><p style="letter-spacing:3px;font-size:11px">NOS CASAMOS</p><h1 style="font-weight:400;font-size:38px">Laura &amp; Javier</h1><p style="font-size:22px">Para ${name}</p><p style="font-size:17px;line-height:1.8">${message}</p><p style="margin:32px 0"><a href="${link}" style="display:inline-block;padding:16px 25px;background:#a8785e;color:white;text-decoration:none">Abrir mi postal</a></p><p style="font-size:13px;line-height:1.8">Tu invitación es personal. Abre la postal, crea tu cuenta con este correo y elige tu alias para los juegos.</p><p style="font-style:italic">Con todo nuestro cariño,<br>Laura y Javier</p></div></body></html>`,text:`${guest.display_name},\n\n${guest.personal_message}\n\nAbre tu postal personal: ${link}\n\nCrea tu cuenta usando este correo.\nLaura y Javier`})})
  const service = createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}})
  if(!delivery.ok){await service.from('wedding_guest_passes').update({delivery_error:'El proveedor de correo no ha aceptado el envío. Revisa remitente y configuración.'}).eq('id',pass_id);return reply({error:'No se ha enviado el correo. Revisa el remitente y la configuración del proveedor.'},502)}
  const {error:saveError} = await service.from('wedding_guest_passes').update({sent_at:new Date().toISOString(),delivery_error:null}).eq('id',pass_id)
  if(saveError) return reply({error:'El proveedor aceptó el correo, pero no pudimos actualizar su estado. Actualiza la lista antes de reintentar.'},500)
  return reply({sent:true})
 }catch{return reply({error:'No se ha podido completar el envío. La invitación sigue disponible en el administrador.'},500)}
})
