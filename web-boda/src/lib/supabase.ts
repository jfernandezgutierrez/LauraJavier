import { createClient } from '@supabase/supabase-js'
import { SUPABASE_URL, SUPABASE_KEY } from './config'
export const db = createClient(import.meta.env.VITE_SUPABASE_URL || SUPABASE_URL, import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || SUPABASE_KEY)
export function fail(error: {message:string}|null) { if(error) throw new Error(error.message) }
export function friendly(error: unknown):string {
 const message=error instanceof Error ? error.message : String(error)
 if(message.includes('Invalid login')) return 'El correo o la contraseña no coinciden.'
 if(message.includes('Email not confirmed')) return 'Confirma tu correo antes de entrar.'
 if(message.includes('rate limit')) return 'Demasiados intentos. Espera unos minutos y vuelve a probar.'
 if(message.includes('row-level') || message.includes('permission denied')) return 'No tienes permiso para esta acción. Revisa tu invitación o contacta con los novios.'
 if(message.includes('duplicate key')) return 'Esta canción ya se ha propuesto.'
 if(message.includes('fetch')) return 'No hemos podido conectar. Comprueba tu conexión y vuelve a intentarlo.'
 return message
}
