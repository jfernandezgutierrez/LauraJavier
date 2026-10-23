export type Move='U'|'D'|'L'|'R'
export const WIDTH=8, HEIGHT=6
export const blocked=(x:number,y:number)=>x===3&&[1,2,3].includes(y)||x===5&&y===4
export function nextPosition(x:number,y:number,m:Move) {const nx=x+(m==='R'?1:m==='L'?-1:0),ny=y+(m==='D'?1:m==='U'?-1:0);return nx<0||nx>=WIDTH||ny<0||ny>=HEIGHT||blocked(nx,ny)?null:{x:nx,y:ny}}
export function scoreFor(moves:number){return Math.max(100,2000-moves*20)}
export function replay(moves:string){let x=0,y=5,r1=false,r2=false;for(const m of moves){if(!'UDLR'.includes(m))throw new Error('Invalid move');const n=nextPosition(x,y,m as Move);if(!n)throw new Error('Invalid route');x=n.x;y=n.y;r1 ||= x===1&&y===1;r2 ||= x===6&&y===4}return {x,y,r1,r2,won:r1&&r2&&x===7&&y===0,score:scoreFor(moves.length)}}
