# Publicar RetailSpellbook en CurseForge — kit

Preparado el 05-11-2026. Paquete: `mods\wow\dist\RetailStyleSpellbook-0.1.0.zip` (generado con
`python -I mods\herramientas\empaquetar-wow.py mods\wow\RetailSpellbook --version 0.1.0`; pasa
`comprobar-paquete.py --juego wow`: solo `.toc`, `.lua`, `LICENSE` y `CHANGELOG.md`).

**Estado honesto:** pasa las comprobaciones fuera del juego (95 tests, 05-11-2026). **Sin ver en el cliente**
(pruebas pendientes en el [README](../README.md#estado)). Nico pidió subirlo el 05-11-2026.

## Campos del formulario

| Campo | Valor |
|---|---|
| Juego | World of Warcraft |
| Nombre del proyecto | `Retail-Style Spellbook` (la carpeta es `RetailSpellbook`) |
| Resumen | `Your spellbook organised like retail: Class, General and Pet tabs, a header per school, search and hide passives. For WoW: Forever.` |
| Categoría principal | Action Bars (secundaria: Miscellaneous). Comprobar los nombres exactos en el formulario |
| Licencia | MIT (está en `LICENSE`) |
| Donaciones | Ko-fi, usuario `thevoltor` |
| Versión de juego | **Forever 1.60.1** (Interface 16001). No marcar retail ni Classic |
| Tipo de fichero | Release (como el resto de addons de Nico) |
| Avatar | `docs/avatar-curseforge.png` (`mods/herramientas/avatares_curseforge.py retailspellbook`) |
| Capturas | `docs/screenshots/`: `spellbook-class-tab.png`, `rank-dropdown.png`, `search.png` (cliente en inglés, brujo nivel 5, 07-11-2026) |

## Descripción (pegar en el editor de CurseForge)

```markdown
**Retail-Style Spellbook** organises your spellbook the way modern retail WoW does, instead of one icon tab per school.

Made for **World of Warcraft: Forever**.

<p align="center"><a href="https://ko-fi.com/thevoltor"><img src="https://storage.ko-fi.com/cdn/kofi6.png?v=6" alt="Buy Me a Coffee at ko-fi.com" width="145" height="36"></a><br><em>Free and always will be. If it helps you, you can buy me a coffee.</em></p>

## What you get

- Named tabs on top: **your class**, **General** and **Pet** (when you have pet spells).
- The class tab shows all your schools one after another, each with its own header (Arcane, Fire, Frost...).
- Two open pages with three columns; turn pages with the arrows or the mouse wheel.
- **One entry per spell**: ranks are merged and it casts your highest one. The arrow next to the rank (or a
  right-click) opens a dropdown to pick a lower rank; your choice is saved per character.
- Search box (searches every tab, ignores accents and case) and a **Hide passives** checkbox.
- Click to cast, drag to your action bars, Shift-click to link in chat. Pet spells: right-click toggles autocast.

It opens with **your usual spellbook key** (P by default) and with `/libro`. The micro menu button still opens
Blizzard's spellbook, and an option gives the key back to it.

## Why a separate book

Blizzard's spellbook casts from its own code: if an addon changes how it builds its tabs, casting from it gets
"action blocked". Here every spell is a secure button, so casting works cleanly. The trade-off: **in combat** the
page, tab and search stay as they are (opening, closing and casting still work). It refreshes when combat ends.

## Commands

- `/libro` or `/retailspellbook` — open or close the book (out of combat).
- `/retailspellbook config` — options: use the spellbook key, hide passives, one spell per rank, scale.
- `/retailspellbook debug` — diagnostics to paste when reporting a problem.

---

**Español.** El libro de hechizos organizado como en retail: pestañas Clase, General y Mascota, un encabezado
por escuela, dos páginas de tres columnas, buscador y ocultar pasivas. Se abre con tu tecla del libro y con `/libro`.
```

## Changelog del fichero 0.1.0

```text
First release: spellbook organised like retail (Class, General and Pet tabs, a header per school, two pages of
three columns), search, hide passives, opens with your spellbook key, secure buttons to cast without "action blocked".
```

## Registro de publicación

**Subido el 05-11-2026 (por Claude, con la sesión de Nico en Chrome, por orden suya: «sube los addons que faltan»):** proyecto «Retail-Style Spellbook», n.º **1785903** (`https://authors.curseforge.com/#/projects/1785903`), estado «New» hasta que lo apruebe un moderador. Fichero «Retail-Style Spellbook 0.1.0», tipo **Release**, versión Forever 1.60.1, publicación automática al aprobarse. Categorías Action Bars + Miscellaneous, comentarios activados, licencia MIT, distribución a terceros permitida, donaciones Ko-fi `thevoltor` (comprobado tras recargar). Al acabar, el fichero estaba en «Processing». Falta: capturas (solo en el juego) y verlo en el cliente.

**0.2.0 (06-11-2026, por Claude con la sesión de Nico en Chrome, por orden suya: «Sí, súbelas»):** fichero «Retail-Style Spellbook 0.2.0», `mods\wow\dist\RetailStyleSpellbook-0.2.0.zip`, tipo **Release**, versiones Forever 1.60.1, publicación automática al aprobarse. Changelog en inglés que nombra lo nuevo: botón «To learn (N)» con What's Training?. Pasa las comprobaciones fuera del juego (06-11-2026); **sin probar en el cliente**.
