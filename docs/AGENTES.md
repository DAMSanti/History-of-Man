# Varios agentes a la vez

Cómo trabajan dos o más agentes sobre este repositorio sin romperse el trabajo
entre ellos.

No es una preocupación teórica. Está escrito el día que costó una medida:

> *«Verano, otoño e invierno quedan sin medir: una corrida de un año a
> `time_scale = 5` cuesta más de una hora, y el día que tocaba medirlo **había
> cuatro agentes con sondas distintas compitiendo por la misma máquina**.»*
> — [ESTADO.md](ESTADO.md) §7.4

---

## 1. Lo que NO se hace

Tres soluciones evidentes, y las tres descartadas a propósito:

- **Nada de worktrees ni ramas por agente.** Un agente en su propia copia no se
  entera de lo que hacen los demás hasta que toca fusionar, que es justo cuando
  duele. Todos trabajan sobre el mismo árbol.
- **Nada de repartir carpetas.** Un agente no tiene territorio. Cualquiera puede
  tocar cualquier fichero; lo que hace falta es que **se sepa** antes.
- **Nada de un agente coordinador.** No hay jefe. El protocolo es entre iguales.

Lo único que queda, y es suficiente: **decir lo que vas a tocar, mirar lo que
tocan los demás, y respetar el turno de Godot.**

---

## 2. La pizarra

Un fichero, `.claude/agentes/pizarra.md`, donde cada agente declara en qué anda
**antes** de tocar nada.

Una línea por agente, y se borra al terminar:

```
## <nombre del agente> — <hora de inicio>
tarea: SECADERO_Y_RIO, tarea 3 (el secadero como cuello de botella del otoño)
toco: scripts/sim/Despensa.gd, scripts/economia/Materia.gd, scripts/tests/TestDespensa.gd
puede que toque: scripts/sim/Tajo.gd
```

**Antes de la primera edición** se lee la pizarra entera. Si un fichero que
vas a tocar ya está declarado por otro:

1. **No lo edites.** Ni «sólo una línea», ni «en otra función».
2. **Háblale.** `ListAgents` para ver quién hay, `SendMessage` para preguntarle:
   qué está cambiando ahí, cuánto le queda, si prefiere hacerlo él.
3. **Reordena tu trabajo** mientras tanto: haz lo que no dependa de ese fichero.
   Casi siempre hay algo.
4. Si nadie responde y el bloque es viejo, comprueba si el agente sigue vivo
   antes de dar el fichero por libre. Un bloque huérfano se retira **diciéndolo
   en la pizarra**, no borrándolo en silencio.

**«Puede que toque» también cuenta.** Declarar de más es barato; descubrir a
mitad de camino que otro lleva veinte minutos en el mismo fichero, no.

**La pizarra se actualiza cuando cambia el plan**, no sólo al empezar. Si al
implementar resulta que hay que tocar `SettlementSim`, se apunta antes de
tocarlo.

---

## 3. El turno de Godot

**Godot es de uno en uno.** No es una preferencia:

- Cada proceso de Godot **parsea todos los scripts al arrancar**. Tocar un `.gd`
  a mitad de una tanda la rompe por dentro, y no siempre con un error: a veces
  con un número distinto.
- Las sondas miden **reloj de pared**. Dos corridas con la máquina cargada de
  forma distinta no se comparan. Los tirones y los fps de una sonda que corre
  junto a otras dos no dicen nada.
- Las sondas de número fijo de fotogramas avanzan **menos horas de juego** si la
  máquina va cargada. Dos corridas seguidas del mismo código dieron 35,8 y 48,9
  raciones.

### Cómo se toma el turno

Con un directorio, porque `mkdir` **es atómico** y crear un fichero no lo es:

```bash
# Tomar el turno (falla si ya lo tiene otro)
mkdir .claude/agentes/turno-godot 2>/dev/null \
  && echo "<agente> · <qué corro> · $(date +%H:%M)" > .claude/agentes/turno-godot/quien \
  || cat .claude/agentes/turno-godot/quien

# ... correr lo que sea ...

# Soltarlo, SIEMPRE, también si la corrida falló
rm -rf .claude/agentes/turno-godot
```

Con el turno tomado:

- **Nadie edita un `.gd`.** Ni el que tiene el turno ni los demás. Editar
  documentación (`.md`) sí se puede: Godot no la lee.
- Al soltarlo, se dice en la pizarra qué se midió y qué salió, para que el
  siguiente no repita la misma corrida.

### Si el turno lleva mucho tomado

Una corrida de un año a `time_scale = 5` pasa de una hora. Eso es normal, no un
turno colgado. **Pregunta antes de forzar** (`SendMessage` al agente que figura
en `quien`). Un turno se rompe sólo cuando el agente ya no existe, y se dice.

---

## 4. Git

El árbol es compartido, así que:

- **Nadie hace `commit` de lo que no es suyo.** `git add` de ficheros concretos,
  nunca `git add -A` ni `git commit -a`: te llevarías el trabajo a medias de
  otro y lo dejarías en un commit con su mensaje equivocado.
- **Nadie hace `checkout`, `reset --hard`, `stash` ni `rebase`** sin decirlo
  antes en la pizarra y esperar respuesta. Son las operaciones que borran el
  trabajo de otro sin preguntar.
- **Nadie cambia de rama** con otro agente trabajando.

---

## 5. Antes de dar algo por hecho

Con varios agentes encima, la suite es la red de todos:

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

Y con turno, como todo lo que arranca Godot. Dos cosas que mirar, no una:

- que esté en verde,
- y **que el total de comprobaciones no haya bajado**. Una prueba que revienta
  antes de su primer `assert` no falla: pasa. Si tus cambios y los de otro se
  cruzaron, es así como se nota.

Si el número de comprobaciones bajó y no sabes por qué, **dilo en la pizarra
antes de seguir**. Es la señal de que dos trabajos se han pisado.

---

## 6. El resumen, por si no lees el resto

1. Escribe en la pizarra **antes** de tocar nada.
2. Lee la pizarra **antes** de tocar nada.
3. Si el fichero es de otro, **háblale**; no lo edites.
4. Godot, de uno en uno, con `mkdir` y soltando siempre.
5. Con Godot corriendo, **ningún `.gd` se toca**.
6. `git add` de lo tuyo y sólo de lo tuyo.
7. Mira el total de comprobaciones, no sólo el verde.
