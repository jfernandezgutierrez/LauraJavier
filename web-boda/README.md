# Laura y Javier — web de boda

## Huellas Sprint (28 octubre 2026)

Tercer minijuego del patio: carrera lateral con el perrito, saltos sobre troncos y rocas, velocidad progresiva y cambio de día a noche. Espacio/↑/W o un toque para saltar; P/Esc para pausar. Compatible con el modo de pantalla completa; se pausa al ocultar la pestaña o cambiar el tamaño de la ventana. Requiere cuenta y perfil.

Cada paseo consume 3 de energía y 2 de comida (también 1 de higiene). Dura hasta 60 segundos. El récord y la clasificación son independientes de Flappy y Surfer. Las recompensas se suman a la mascota: máximo 60 monedas y 90 XP. `supabase/sprint.sql` refleja la migración remota aplicada: el servidor reproduce los saltos con física entera, comprueba colisiones y duración y entrega los premios una sola vez. No acepta puntuaciones calculadas por el cliente.

Validación: compilación de producción y 25 pruebas locales aprobadas. `supabase/sprint-tests.sql` aprobado con rollback de los datos ficticios: paridad JS/SQL (930 puntos, 33 obstáculos, 60 monedas y 90 XP), costes, idempotencia, aislamiento, acceso anónimo y rechazo de partidas inválidas. La revisión visual automatizada quedó interrumpida por la herramienta de control del navegador; queda pendiente la prueba manual en un teléfono real.

Vue 3 + TypeScript + Vite + Tailwind CSS + Supabase. Proyecto conectado: `zalbymwlhythibeafpac` (laura). El contenido visual y las imágenes siguen el Word del encargo. Los textos narrativos iniciales son editables y no se han inventado fechas ni lugares.

## Ejecutar

Node 22.12 o superior y pnpm 11.25.0. Ejecutar `pnpm install`, `pnpm dev`, `pnpm test` y `pnpm build`. La salida es `dist/`. `pnpm preview` sirve la compilación. Versiones fijadas en package.json y pnpm-lock.yaml. Se permiten únicamente los scripts de instalación de esbuild y Tailwind Oxide.

La configuración pública de Supabase está en `src/lib/config.ts`; puede sustituirse con las variables de `.env.example`. No contiene claves de servicio ni secretos. Todas las tablas expuestas tienen RLS y privilegios explícitos.

## Acceso para los novios

El panel está en `/#admin` (también se reconoce `/admin` si el alojamiento resuelve rutas SPA). No existen administradores por defecto ni contraseñas compartidas. Los correos autorizados se añaden desde el SQL Editor de Supabase a la tabla privada `wedding_private.admin_emails`. Después, cada titular se registra y verifica ese correo. La función de autorización comprueba en el servidor tanto el email como su verificación.

Ejemplo para ejecutar solo tras sustituir por correos aprobados:

```sql
insert into wedding_private.admin_emails(email)
values (lower('CORREO_AUTORIZADO')) on conflict do nothing;
```

La tabla de administradores no tiene permisos directos para el cliente. Está protegida con RLS sin políticas de acceso, intencionadamente. Las funciones privadas con privilegios elevados tienen search_path vacío, identidad comprobada y EXECUTE revocado para PUBLIC y anon. Las funciones RPC públicas son invoker.

## Registro y correo de confirmación

En Supabase → Authentication → URL Configuration configurar Site URL con la URL definitiva y añadirla a Redirect URLs. Para desarrollo, añadir `http://127.0.0.1:5173/`. Mantener activada la verificación del email. Configurar un SMTP de producción para que las confirmaciones y recuperaciones lleguen a cualquier invitado; el servicio de correo predeterminado de Supabase tiene restricciones. No se ha desactivado la confirmación de correo ni configurado un proveedor sin credenciales.

Los novios crean la postal y asignan el cupo → el invitado abre su enlace → crea la cuenta con el correo invitado → confirma el email → activa y personaliza su perfil. La asistencia queda habilitada con el cupo de la postal. Las cuentas anteriores conservan su acceso y pueden gestionarse desde el panel.

## Funciones implementadas

- Invitación adaptable con las tres imágenes, historia conectada con huellas, ubicaciones, programa, cuenta atrás al configurar fecha y calendario descargable.
- Registro exclusivo por invitación personal, inicio/cierre de sesión, recuperación y actualización de contraseña.
- Perfil privado, teléfono opcional y preferencias independientes para avisos web, correo y clasificación.
- Asistencia con cupo controlado en PostgreSQL, plazo configurable, acompañantes, menú y transporte.
- Panel privado con edición de contenidos, aprobación de invitaciones, respuestas y exportación CSV neutralizada contra fórmulas.
- Sugerencias musicales, deduplicación por enlace y revisión manual. Enlace a playlist y canción.
- Avisos con borrador y publicación en el área privada. Exportación de contactos que consienten correo.
- Mascota virtual inspirada en los juegos de cuidados: perrito original, seis espacios, comida, baño, mimos, Flappy Perrito, armario y descanso. Acceso exclusivamente con cuenta y perfil, con progreso persistente.
- Hambre, higiene, energía y felicidad; monedas, experiencia y niveles calculados en PostgreSQL. Pausa de cuatro segundos entre cuidados, descanso de dos puntos de energía por minuto y clasificación voluntaria moderable.

## Integraciones pendientes de credenciales

**Spotify:** no se ha conectado una cuenta Spotify. El flujo real disponible guarda propuestas y permite añadirlas manualmente a la playlist. El estado «Añadida» lo marca el administrador tras hacerlo. Para sincronización automática: registrar una aplicación Spotify, comprobar elegibilidad/modo de cuota, realizar OAuth de la cuenta propietaria y guardar refresh tokens solo en servidor. No usar secretos VITE_.

**Email de novedades:** los avisos dentro de la web sí funcionan. No se envían emails de campañas ni notificaciones push. Configurar un proveedor transaccional, remitente verificado y envío exclusivo a perfiles con consentimiento vigente antes de activar campañas. El CSV con consentimiento permite una gestión manual desde un servicio elegido por la pareja.

## Base de datos y comprobaciones

`supabase/schema.sql` refleja la migración inicial aplicada al proyecto remoto. No volver a ejecutarlo sobre el mismo esquema. Las migraciones remotas quedan registradas en Supabase. `supabase/security-tests.sql` comprueba el aislamiento entre invitados, acceso admin, cupos, puntuaciones inventadas, reutilización de partida, privacidad del ranking y restricciones anónimas. Usa registros ficticios dentro de una transacción y los revierte al terminar.

`supabase/pet.sql` contiene la mascota virtual que sustituye al laberinto inicial. `supabase/pet-tests.sql` verifica costes, experiencia, pausa entre acciones, descanso sin acumulación duplicada, aislamiento y bloqueo de modificaciones directas. `supabase/arcade.sql` añade Atrapa los premios y Parejas perrunas, con 12 partidas/hora, coste de energía/comida y premios calculados en servidor. `supabase/arcade-tests.sql` verifica aislamiento, duración mínima, movimientos y reintentos sin premios duplicados. `tests/arcade.test.ts` verifica las reglas locales de los minijuegos. Las validaciones limitan los premios y rechazan movimientos imposibles; no pretenden detectar bots que completen partidas válidas. Los archivos del juego inicial se conservan como histórico; ya no se muestra en la interfaz.

## Antes de invitar a personas reales

Confirmar emails admin, fecha con zona horaria, lugares, nombre del perrito, historia y contacto. Revisar plazo de conservación de datos y quién coordinará los menús. Configurar URLs/SMTP de Auth y probar con un correo real autorizado. La publicación inicial en Sites es privada para el propietario; cambiar el público solo cuando la pareja decida compartirla.

No se han enviado invitaciones, avisos ni correos a invitados durante el desarrollo. Las pruebas de base de datos se revierten y no generan usuarios reales.


El personaje actual usa un atlas PNG con ocho estados, transparencia solo fuera del cuerpo y accesorios independientes. Las ilustraciones SVG anteriores se conservan como histórico. El modo visita jugable ha sido retirado.

## Invitaciones creadas por los novios

El administrador prepara nombre de la postal, correo titular, dedicatoria y cupo. La cuenta queda reservada y el enlace personal abre una postal animada. El invitado elige nombre, alias y contraseña; confirma su correo y activa su perfil. Su invitación queda aprobada con el cupo definido. Las cuentas anteriores conservan el acceso.

`supabase/guest-passes.sql` es la migración aplicada. Un trigger en `auth.users` rechaza nuevas cuentas sin token válido asociado al correo invitado (los correos admin autorizados tienen excepción de bootstrap). Las lecturas de invitaciones completas son solo admin. El enlace aleatorio de 64 caracteres se almacena como SHA-256, caduca a los 90 días y se consume una vez; renovar lo invalida, desactivarlo no borra cuentas existentes. La consulta pública de postal no expone el email. El token se conserva en metadata como credencial de invitación hasta activarla, para volver desde la confirmación en otro dispositivo incluso si Auth redirige a la raíz. No se usa metadata como rol o autorización admin.

`supabase/guest-passes-tests.sql` prueba en transacción registro cerrado, identidad verificada, personalización, cupo, privacidad, reintentos, renovación y desactivación. Los fixtures se revierten.

### Correo de invitación: pendiente de aprobación

El envío automático NO está desplegado. La revisión automática bloqueó la integración con Resend por falta de autorización del proveedor y los datos transferidos. La interfaz mantiene `INVITATION_EMAIL_ENABLED=false`; crear/copiar enlaces sí funciona. No se han enviado correos de invitación.

La implementación preparada está en `supabase/functions/send-wedding-invitation/index.ts`. Tras autorización del propietario para enviar nombre, email, dedicatoria y enlace a Resend: configurar `RESEND_API_KEY` y `WEDDING_FROM_EMAIL` en secretos de Supabase; desplegar con `verify_jwt=true` y conservar la comprobación interna de identidad y rol; verificar con un destinatario expresamente autorizado antes de habilitar el botón. No poner secretos en VITE_. El remitente debe estar verificado en el proveedor. Los reintentos usan una clave idempotente y se limitan a uno por minuto por invitación.

Los correos de confirmación de cuenta siguen usando Supabase Auth y requieren SMTP apto para destinatarios externos. El sitio continúa privado para su revisión; antes de invitar personas reales habrá que habilitarles el acceso al alojamiento.

El asesor de Supabase también informa de que la protección frente a contraseñas filtradas no está habilitada; puede activarse desde Auth según el plan: [documentación oficial](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No se cambió esa configuración.


## Huellas: móvil, armario y Flappy Perrito (21 octubre 2026)

La zona de juegos incluye **Flappy Perrito** y, desde el 23 de octubre, **Huellas Surfer**. Las implementaciones anteriores de Atrapa/Parejas quedan como histórico, fuera de la interfaz. Cuidado de la mascota, necesidades que cambian con el tiempo, monedas, XP, niveles y progreso por cuenta se conservan. Es una mascota propia inspirada en los juegos de cuidados.

- Arte: `public/images/dog-sprites.png`, atlas RGBA 4 × 2, ocho estados y animaciones de reposo, parpadeo y acciones. Origen y prompt exacto en `docs/dog-sprites.md`.
- Tienda/armario: cuatro accesorios y tres colores de habitación. Compra persistente y equipamiento por cuenta. Precios y nivel mínimo se comprueban en servidor, compras repetidas no cobran dos veces. La comida se compra y consume en la cocina. Cuenco gratuito de ayuda si hambre <25, una vez cada seis horas, evita un bloqueo por falta de monedas.
- Flappy: controles táctiles, espacio/flecha arriba, pausa manual y al ocultar la app, sonido opcional, resultado, reintento de guardado, récord personal y ranking solo con alias y consentimiento. Partidas hasta 60 segundos y 40 inicios/hora. Cada inicio consume 3 energía, 2 comida y 1 higiene. Cada arco aporta 2 monedas y 3 XP, máximo 60/90. No hay dinero real.
- Supabase: `supabase/pet-world.sql` refleja la migración aplicada. Aritmética entera a 60 pasos/s; la partida guarda una semilla y el servidor reproduce las pulsaciones para calcular colisiones, puntos y recompensas. No acepta puntuación ni dinero enviados por el cliente. Reintentos idempotentes, bloqueo por usuario, RLS y permisos mínimos. No se pretende detectar bots que jueguen una secuencia válida.
- Instalación web: manifest, iconos 192/512 y servicio de pantalla sin conexión. Inicio en `/#mascota`; instrucciones Safari/iPhone y Chrome/Android y botón nativo cuando el navegador lo ofrece. No es una APK ni una publicación en App Store. Requiere conexión para iniciar sesión, jugar y guardar. No se cachean páginas autenticadas, invitaciones ni respuestas de Supabase.
- La cuenta atrás del cuadro toma `wedding_settings.content.date`, configurable por los novios. La fecha real sigue vacía: se muestra «Nuestro gran día está por llegar». Las fechas usadas en QA son ficticias y no se publican. Al alcanzar la fecha muestra una celebración.

Validación: compilación de producción y 15 pruebas locales aprobadas; `supabase/pet-world-tests.sql` aprobado con rollback de fixtures (compras, saldo, nivel, equipamiento, aislamiento, denegación anónima, anti-repetición y replay de 3600 pasos/32 arcos idéntico al navegador con límites de premios). Revisión visual e interacciones con datos ficticios en 390×844, 320×568 y escritorio. No se ha realizado instalación física en un iPhone/Android. La disponibilidad de instalación depende del navegador y del acceso al alojamiento; Sites conserva acceso privado para el propietario.

Documentación consultada: [instalación de PWA](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable), [funciones de base de datos](https://supabase.com/docs/guides/database/functions).

## Controles y Huellas Surfer (23 octubre 2026)

Flappy captura Espacio/↑ dentro del juego aunque un botón conserve el foco, sin activar ese botón ni desplazar la página. P/Esc pausa o continúa; las instrucciones permanecen visibles. No intercepta formularios ni controles fuera del juego.

Huellas Surfer es una carrera original de tres carriles: vallas para saltar, arcos para deslizarse, setos para esquivar y monedas para recoger. PC: flechas/WASD, Espacio para saltar, P/Esc para pausar. Móvil: gestos en cuatro direcciones y botones de al menos 48 px. Pausa al ocultarse la pestaña o si la animación se interrumpe. Reutiliza el perrito y su accesorio equipado. Las partidas terminan por colisión o a los 60 segundos.

La migración aditiva `supabase/runner.sql` está aplicada. Cada carrera consume 3 energía, 2 comida y 1 higiene. Recompensas: dos monedas por objeto recogido más una por cada 10 s completos, máximo 60; XP por segundos completos más objetos recogidos, máximo 90. Récord independiente y clasificación voluntaria con alias. El servidor reproduce la semilla y los controles, aplica los premios una vez y rechaza carreras ajenas, incompletas, aceleradas o que continúan tras una colisión. Los datos de prueba no se publican.

Validación de esta actualización: 20 pruebas locales aprobadas y compilación de producción; `supabase/runner-tests.sql` aprobado con rollback de todas las cuentas ficticias. La carrera de 3600 pasos reproduce exactamente 1320 puntos, 36 objetos, 60 monedas y 90 XP en JS y SQL. Se verificaron coste de inicio, premios idempotentes, permisos, privacidad de récords y rechazo de entradas inválidas. Pruebas de interfaz: teclado con foco en botones, pausa, gestos, carriles, deslizarse, resultado y tamaños 320×568, 390×844 y 1100×800.
