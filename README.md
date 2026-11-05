# Retail Spellbook

Addon para World of Warcraft: Forever. Cambia la organización del libro de hechizos por la de retail.

## Qué hace

El libro de Forever tiene una pestaña de icono por cada escuela (General, Arcano, Fuego, Escarcha...).
Este lo organiza como el de retail:

- Pestañas arriba con nombre: **tu clase**, **General** y **Mascota** (si tienes).
- En la pestaña de clase, todas tus escuelas seguidas, cada una con su encabezado.
- Dos páginas abiertas con tres columnas, rueda del ratón o flechas para pasar página.
- Buscador (busca en todas las pestañas, sin tildes ni mayúsculas) y casilla «Ocultar pasivas».
- Clic: lanza el hechizo. Arrastrar: a la barra de acción. Mayús+clic: enlace en el chat.
  Mascota: clic derecho activa o quita el lanzamiento automático.

Se abre con la **tecla del libro** que ya tengas (P por defecto) y con `/libro`. La opción «Abrir con
la tecla del libro» devuelve la tecla al libro de Blizzard. El botón del menú inferior sigue abriendo
el de Blizzard.

## Por qué es un libro propio

El de Blizzard lanza los hechizos desde su propio código; si un addon cambia cómo arma sus pestañas,
lanzar desde él da «acción bloqueada». Aquí cada hechizo es un botón seguro que lanza sin ese problema.
El precio: **en combate** la página, la pestaña y la búsqueda se quedan fijas (abrir, cerrar y lanzar
sí funcionan). Se actualiza al salir de combate.

## Comandos

- `/libro` o `/retailspellbook`: abre o cierra el libro (fuera de combate).
- `/retailspellbook config`: opciones (tecla, ocultar pasivas, escala).
- `/retailspellbook debug`: diagnóstico para informar de un problema.

## Estado

0.1.0 (05-11-2026): pasa las comprobaciones fuera del juego (luacheck, StyLua, LuaLS, API de Forever,
95 tests). **Sin probar en el cliente.** Pruebas pendientes en el juego:

1. Abrir con P: salen las pestañas Clase / General y los encabezados por escuela.
2. Clic en un hechizo lo lanza sin error de «acción bloqueada» (BugSack).
3. Arrastrar un hechizo a la barra.
4. En combate: P abre y cierra; lanzar desde la página abierta funciona.
5. Con mascota (cazador o brujo): pestaña Mascota, clic derecho cambia el autolanzamiento.
6. Hechizos con desplegable (si los hay en tu clase): el clic abre el desplegable.
7. Que las texturas del pergamino y el divisor de encabezado se vean (atlas de Blizzard).
