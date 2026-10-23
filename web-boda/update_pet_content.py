from pathlib import Path
p=Path('src/App.vue');s=p.read_text(encoding='utf-8')
for old,new in [
("import PixelDog from './components/PixelDog.vue'","import VirtualDog from './components/VirtualDog.vue'"),
('class="section adventure-section"','class="section adventure-section" :class="{\'pet-open\':gameOpen}"'),
('También tiene<br/><em>una misión.</em>','Un nuevo amigo.<br/><em>Mucho que cuidar.</em>'),
('Nuestro compañero más fiel no podía perderse este día. Y necesita tu ayuda para que los anillos lleguen a tiempo.','Nuestro compañero más fiel tiene su propio rincón. Dale de comer, prepara un baño de burbujas y sal a jugar con él.'),
('Un jardín, dos anillos y una pequeña aventura que deja huella.','Una mascota virtual para acompañarnos hasta la boda. Un poquito de cariño cada día, y muchas huellas por el camino.'),
('<PixelDog moving/>','<VirtualDog class="intro-dog"/>'),
('Guardián oficial de los anillos','Experto en mimos y en perseguir pelotas'),
('Jugar con el perrito','Cuidar a nuestro perrito'),
('Sin descargas · A tu ritmo · En móvil y ordenador','Comida, baños y siestas · Tu progreso se guarda'),
('Nuestro perrito marrón, el guardián de los anillos','Nuestro perrito marrón, el protagonista de la mascota virtual'),
('<DogGame v-else :dog-name="settings.dog_name" @login="login"/>','<DogGame v-else :dog-name="settings.dog_name" @login="login" @close="gameOpen=false"/>')]:
 assert old in s,old
 s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
p=Path('src/components/AdminPanel.vue');s=p.read_text(encoding='utf-8')
for old,new in [
('runs=ref<{id:string;user_id:string;score:number;steps:number;hidden:boolean}[]>([])','runs=ref<{user_id:string;xp:number;care_count:number;coins:number;hidden:boolean}[]>([])'),
("db.from('wedding_game_runs').select('id,user_id,score,steps,hidden').not('finished_at','is',null).order('score',{ascending:false}).limit(100)","db.from('wedding_pets').select('user_id,xp,care_count,coins,hidden').order('xp',{ascending:false}).limit(100)"),
("db.from('wedding_game_runs').update({hidden}).eq('id',id)","db.from('wedding_pets').update({hidden}).eq('user_id',id)"),
("id:'scores',label:'Partidas'","id:'scores',label:'Perritos'"),
('Las aventuras del perrito','Los cuidadores del perrito'),
('Las puntuaciones se calculan tras validar el recorrido. Puedes ocultar una partida de la clasificación.','Las monedas y la experiencia se calculan en el servidor. Puedes moderar la clasificación de cuidadores sin borrar su mascota.'),
('Todavía no hay partidas guardadas.','Todavía no hay mascotas guardadas.'),
('v-for="r in runs" :key="r.id"','v-for="r in runs" :key="r.user_id"'),
('{{r.score}} puntos · {{r.steps}} pasos','{{r.xp}} XP · {{r.care_count}} cuidados · {{r.coins}} monedas'),
('moderate(r.id,!r.hidden)','moderate(r.user_id,!r.hidden)')]:
 assert old in s,old
 s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
