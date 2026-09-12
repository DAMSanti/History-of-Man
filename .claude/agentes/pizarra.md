# Pizarra de agentes

Quién está tocando qué, ahora mismo. El protocolo completo está en
[docs/AGENTES.md](../../docs/AGENTES.md).

Cada agente añade su bloque **antes** de la primera edición, lo actualiza si
cambia el plan, y **lo borra al terminar**.

Plantilla:

```
## <agente> — <hora de inicio>
tarea: <spec y tarea, o qué se está depurando>
toco: <rutas, separadas por comas>
puede que toque: <rutas>
```

Y el turno de Godot va aparte, en `.claude/agentes/turno-godot/` — ver
docs/AGENTES.md §3. No se anota aquí: se toma con `mkdir`.

---

<!-- Los bloques van debajo de esta línea. Si no hay ninguno, nadie está
     trabajando y el repositorio está libre. -->

## epoca-paleolitico-2a — 2026-09-12
tarea: /epoca 1 — escribir la intención de «los dos primeros años»
toco: docs/EPOCA_01_PALEOLITICO.md, docs/SISTEMAS.md, docs/ROADMAP.md
puede que toque: docs/INTERFAZ.md
