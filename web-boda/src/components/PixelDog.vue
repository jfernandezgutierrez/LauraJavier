<script setup lang="ts">
defineProps<{ moving?: boolean }>();
</script>
<template><svg class="pixel-dog" :class="{moving}" viewBox="0 0 32 32" shape-rendering="crispEdges" role="img" aria-label="Nuestro perrito marrón en pixel art"><path fill="#493222" d="M8 4h15v2h3v3h2v12h-3v5h-2v4h-5v-4h-6v4H7v-6H4V12h2V7h2Z"/><path fill="#875330" d="M10 5h11v2h3v13h-2v5H10v-3H7V10h3ZM24 21h4v-7h2v10h-6Z"/><path fill="#ae7849" d="M11 7h3v2h-3Zm6-1h3v3h-3Zm4 5h3v3h-3ZM8 12h3v4H8Zm4 5h9v5h-9ZM10 23h3v3h-3Zm9 0h3v3h-3Z"/><path fill="#67402a" d="M5 10h4v11H5Zm18-2h4v13h-4ZM11 10h3v2h-3Zm6 0h3v2h-3Z"/><path fill="#241e1b" d="M11 13h2v2h-2Zm8 0h2v2h-2Zm-5 4h5v3h-5Z"/><path fill="#e9dcc8" d="M11 13h1v1h-1Zm8 0h1v1h-1Z"/><path fill="#bc694e" d="M10 22h13v2H10Zm4 2h6v2h-2v3h-2v-3h-2Z"/></svg></template>
