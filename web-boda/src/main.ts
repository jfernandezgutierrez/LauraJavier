import { createApp } from 'vue'
import App from './App.vue'
import './style.css'
import './pet.css'
import './pet-world.css'
import './lib/install'
import './invitation.css'
createApp(App).mount('#app')

if(import.meta.env.PROD&&'serviceWorker' in navigator){window.addEventListener('load',()=>{void navigator.serviceWorker.register('/sw.js').catch(()=>{/* Installation remains available without offline mode. */})})}
import './runner.css'
