export interface PetState {hunger:number;hygiene:number;energy:number;happiness:number;coins:number;xp:number;care_count:number;sleeping:boolean;updated_at?:string;last_action_at?:string}
export type PetAction='visit'|'feed'|'apple'|'bone'|'wash'|'play'|'pet'|'sleep'|'wake'
export function newPet():PetState{return {hunger:65,hygiene:60,energy:75,happiness:65,coins:60,xp:0,care_count:0,sleeping:false}}
export function demoAction(state:PetState,action:PetAction):PetState {
 const p={...state};let gain=0
 if(p.sleeping&&!['visit','wake','sleep'].includes(action))throw new Error('Tu perrito está dormido. Despiértalo primero.')
 if(['feed','apple','bone'].includes(action)){if(p.hunger>=95)throw new Error('¡La barriguita ya está llena!');const cost=action==='feed'?6:action==='apple'?10:18;if(p.coins<cost)throw new Error('Te faltan monedas. Juega a la pelota para conseguir más.');p.coins-=cost;p.hunger=Math.min(100,p.hunger+(action==='feed'?25:action==='apple'?40:60));p.happiness=Math.min(100,p.happiness+4);gain=8}
 if(action==='wash'){if(p.hygiene>=95)throw new Error('Tu perrito ya está reluciente.');p.hygiene=100;p.happiness=Math.min(100,p.happiness+3);gain=8}
 if(action==='play'){if(p.energy<10)throw new Error('Necesita una siesta antes de seguir jugando.');if(p.hunger<5)throw new Error('Necesita comer algo antes de jugar.');p.happiness=Math.min(100,p.happiness+20);p.energy-=8;p.hygiene=Math.max(0,p.hygiene-9);p.hunger-=5;p.coins+=8;gain=12}
 if(action==='pet'){if(p.happiness>=95)throw new Error('¡Está feliz como una perdiz! Prueba otro cuidado.');p.happiness=Math.min(100,p.happiness+15);gain=3}
 if(action==='sleep')p.sleeping=true;if(action==='wake')p.sleeping=false
 p.xp+=gain;if(gain)p.care_count++
 return p
}
