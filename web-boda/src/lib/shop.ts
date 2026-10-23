export interface ShopItem {id:string;name:string;kind:'accessory'|'theme';price:number;level:number}
export interface ShopState {catalog:ShopItem[];owned:string[];style:{accessory:string;theme:string}}
export const emptyShop=():ShopState=>({catalog:[],owned:[],style:{accessory:'',theme:''}})
export const itemIcons:Record<string,string>={bandana:'🔻',collar:'🏅',bow:'🎀',hat:'👒',rose:'🌸',sage:'🌿',lavender:'🪻'}
