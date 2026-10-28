# Sprites de los juegos

Generados el 28 de octubre de 2026 con la herramienta integrada de generación de imágenes (sin API/CLI adicional), tomando `public/images/dog-sprites.png` como referencia de identidad y estilo.

Archivo final: `public/images/dog-game-sprites.png`, PNG RGBA de 1774 × 887 px, transparencia exterior conservada sin procesado posterior. Atlas 4 × 2: fila superior de perfil hacia la derecha; fila inferior de espaldas. Columnas: carrera A, carrera B, salto, agachado. La selección usa coordenadas SVG proporcionales, sin redondear las celdas de 443,5 px.

`GameDog.vue` comparte el atlas entre Flappy, Surfer y Sprint y superpone los accesorios equipados. Los fotogramas siguen el reloj del juego; la pausa congela la animación. El modo de movimiento reducido fija la pose de carrera. La mascota en sus habitaciones conserva el atlas original.

Prompt exacto:

```text
Use case: stylized-concept. Asset type: production 2D game sprite atlas, transparent PNG. Input image is identity and rendering-style REFERENCE ONLY: the existing fluffy chocolate brown curly-haired puppy. Create a NEW companion sprite sheet of the EXACT SAME puppy, preserving chocolate curls, lighter tan muzzle and paws, round friendly head, floppy ears, soft detailed illustrated plush rendering, no outlines or vector simplification. EXACT layout: 4 columns by 2 rows, eight equal SQUARE cells, overall 2:1 width:height. Every cell contains only one isolated full-body puppy of equal scale, with 10 percent transparent margins, centered horizontally, feet baseline at 90 percent of cell height. TOP ROW all strict RIGHT-FACING PROFILE: cell 1 running stride A, cell 2 running stride B opposite legs, cell 3 jumping with tucked feet, cell 4 crouched low to slide. BOTTOM ROW all strict REAR VIEW running away from camera (no face visible): cell 1 running stride A, cell 2 running stride B opposite legs, cell 3 jumping with tucked feet, cell 4 crouched low sliding. All poses on four legs, cute same puppy body proportions. No props, no clothing, no accessories, no dirt, no bowls, no scenery, no ground shadows, no captions, no labels, no dividing grid. Genuine transparent background everywhere outside the opaque dog; preserve completely opaque fur/body, no transparency holes. Clean nonoverlapping atlas suitable for exact 4x2 cropping. The puppy identity must clearly match the reference.
```
