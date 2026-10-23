import {ref} from 'vue'
interface InstallEvent extends Event {prompt:()=>Promise<void>;userChoice:Promise<{outcome:string}>}
export const installPrompt=ref<InstallEvent|null>(null)
export const installed=ref(matchMedia('(display-mode: standalone)').matches||(navigator as Navigator&{standalone?:boolean}).standalone===true)
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installPrompt.value=event as InstallEvent})
window.addEventListener('appinstalled',()=>{installed.value=true;installPrompt.value=null})
export async function install(){const event=installPrompt.value;if(!event)return;await event.prompt();await event.userChoice;installPrompt.value=null}
