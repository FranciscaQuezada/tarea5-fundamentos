# T5 — Do-file automatizado
### Módulo IV · Semana 13 · **Tarea calificada — 13 % de la nota final**
#### Fundamentos de Programación para Análisis Económico · UdeC-EAN

**Tipo:** calificada.
**Entrega:** jueves 19 de noviembre, 23:59 (semana sin clases; consultas por correo).
`.do` comentado + su `.log`, en tu repositorio de GitHub.
**Vienes preparado si hiciste:** [A5 (S12, do-file básico)](tarea_semana12.md).
**Uso de IA:** restringido (ver el final).

---

## Objetivo

Convertir el do-file «escrito a mano» de la A5 en uno **automatizado**: sin código
repetido, parametrizado con macros, con un **programa reutilizable** y con los
resultados **guardados y exportados** en vez de solo mirarlos en pantalla.

> Datos: `data/raw/casen_reducido.csv` (las mismas 60 personas de siempre).
> Antes de correr, Stata debe estar en la carpeta del proyecto (`pwd`, `cd`).

---

## La idea central

En R casi no escribiste loops: la vectorización los hacía por ti. En Stata la
repetición es **explícita**, y ahí es donde aparecen las macros, los loops y los
programas.

**El criterio de esta tarea es uno:** si cambias un parámetro (una variable, un
umbral, una lista de grupos), debes poder hacerlo **en un solo lugar** y que todo
el do-file se adapte. Si tienes que editar cinco líneas, no está automatizado.

---

## Qué debes hacer

Crea `scripts/tarea_t5.do`. Cada paso corresponde a algo que vimos en la S12 o la S13.

### 1. Encabezado con macros de configuración

Todo lo que podría cambiar va **arriba**, en macros — nunca repetido en el cuerpo:

```stata
version 14
clear all
set more off
capture mkdir "output"
capture log close
log using "output/tarea_t5.log", replace text

* --- Parámetros (lo único que se edita) ---
local datos     "data/raw/casen_reducido.csv"
local depvar    "ingreso"
local numericas "ingreso educ edad experiencia"
local controles "educ experiencia"
local grupos    "sector region genero"
global umbral   = 500000
```

> Usa `local` para lo que vive solo en este do-file y `global` para lo que
> quisieras compartir entre do-files. **Justifica en un comentario** por qué
> elegiste cada tipo al menos una vez.

### 2. Carga y prepara los datos

```stata
import delimited "`datos'", clear varnames(1) encoding("utf-8")
generate experiencia = max(edad - educ - 6, 0)
```

Crea también una variable **0/1 con etiquetas de valores** para el sexo (por
ejemplo, `mujer` con `label define` + `label values`, S12S2). La necesitarás en el
modelo: `genero` es texto y **no puede entrar a una regresión** (`i.genero` da error).

> **Ojo con los controles.** `experiencia = edad − educ − 6`: si pones `edad`,
> `educ` y `experiencia` juntas en un modelo, Stata omite una por colinealidad. Por
> eso `controles` no incluye `edad`.

### 3. Un `foreach` sobre una lista de variables

Reemplaza el `summarize` repetido de la A5 por un loop:

```stata
foreach v of local numericas {
    summarize `v', detail
}
```

### 4. Un `forvalues` con un rango

Úsalo para algo con sentido económico, por ejemplo tramos de educación. Usa
`r(N)` de `count` para mostrar el resultado con `display` (S13S1):

```stata
forvalues t = 4(4)16 {
    quietly count if educ >= `t' & educ < `t' + 4
    display "Educación de `t' a " `t' + 3 " años: " r(N) " personas"
}
```

### 5. Un `program` reutilizable con argumentos

Define un programa que reciba **al menos un argumento** (<code>&#96;1'</code>, S13S2)
y produzca un bloque de descriptivos. Por ejemplo:

```stata
capture program drop descriptivos_grupo
program define descriptivos_grupo
    display _newline "=== Descriptivos por `1' ==="
    tabulate `1'
    tabstat ingreso educ, by(`1') statistics(mean sd n)
end
```

Y luego **llámalo desde un loop**, de modo que un solo bloque sirva para todos los
grupos:

```stata
foreach g of local grupos {
    descriptivos_grupo `g'
}
```

> `capture program drop` antes de `program define` evita el error al re-ejecutar.

### 6. Usa `tempvar` al menos una vez

Cuando necesites una variable intermedia que no debe quedar en los datos:

```stata
tempvar ing_miles
generate `ing_miles' = ingreso / 1000
summarize `ing_miles'
```

> Explica en un comentario **por qué** `tempvar` es más seguro que crear una
> variable normal y borrarla después.

### 7. Maneja los missing correctamente

Al filtrar por el umbral, excluye explícitamente los faltantes:

```stata
count if ingreso > $umbral & !missing(ingreso)
```

**Deja un comentario** explicando qué pasaría sin el `& !missing(ingreso)`.

### 8. Modelos guardados y comparados (S13)

Estima **al menos dos** regresiones usando las macros, guárdalas con
`estimates store` y compáralas en una tabla:

```stata
quietly regress `depvar' `controles'
estimates store m1
quietly regress `depvar' `controles' i.mujer
estimates store m2
estimates table m1 m2, b(%9.0f) se stats(N r2) stfmt(%5.3f)
```

Muestra el coeficiente de educación con `_b[educ]` y `display`, en vez de copiarlo
a mano. (Si tienes instalado `estout`, puedes usar `esttab` en lugar de
`estimates table`.)

### 9. Una regresión por grupo, guardada en una matriz y exportada

Con `levelsof` + `foreach`, estima una regresión de `ingreso` en `educ` para cada
sector y guarda el coeficiente, su error estándar y el n en una matriz creada con
`J()`. Expórtala a `output/tarea_t5_por_sector.xlsx` con `putexcel`, con los nombres
de los sectores en la primera columna (S13S1 y S13S2).

### 10. Cierra el log e interpreta

```stata
log close
```

Cierra con un comentario de **5 a 8 líneas**: el coeficiente de educación **en
pesos**, con «se asocia» (nunca «causa»), qué cambia entre `m1` y `m2`, qué tan
precisas son las regresiones por sector (cuántas personas hay en cada una) y una
limitación.

---

## Prueba de fuego antes de entregar

Cambia **una sola línea** del bloque de parámetros —por ejemplo, quita
`experiencia` de `controles` o cambia el `global umbral`— y vuelve a correr el
do-file completo.

**Debe correr sin errores y reflejar el cambio en todos los resultados.** Si no lo
hace, tu do-file no está automatizado: tiene valores «quemados» en el cuerpo.

---

## Rúbrica (13 % de la nota final)

| Criterio | Puntos |
|---|---:|
| Macros de configuración al inicio; nada repetido en el cuerpo | 15 |
| `local` vs `global` usados con criterio y justificados | 5 |
| Datos preparados: `experiencia`, indicadora 0/1 con etiquetas de valores | 5 |
| `foreach` sobre lista de variables, funcionando | 5 |
| `forvalues` con rango, con sentido económico y usando `r(N)` | 5 |
| `program` con argumentos, llamado desde un loop | 15 |
| `tempvar` usado y su ventaja explicada | 5 |
| Manejo explícito de missing al filtrar, comentado | 5 |
| Dos modelos con `estimates store`, comparados en una tabla; `_b[educ]` mostrado con `display` | 10 |
| Regresión por sector en un loop, guardada en una matriz `J()` y exportada con `putexcel` | 10 |
| **Interpretación** en pesos, sin lenguaje causal, con una limitación | 10 |
| Do-file corre completo de una vez y el `.log` lo prueba | 10 |
| **Total** | **100** |

> **Prueba de parametrización:** si al cambiar una macro el do-file falla o los
> resultados no cambian, se descuentan 15 puntos. Es el criterio central de la tarea.

---

## Entrega

1. `scripts/tarea_t5.do`, `output/tarea_t5.log` y `output/tarea_t5_por_sector.xlsx` en tu repositorio.
2. En el `README.md`: qué automatizaste y qué habría que editar para reutilizar el
   do-file con otros datos.
3. **Avanza por commits.**
4. Pega el enlace del repositorio en Canvas.

---

## Declaración de autoría y uso de IA

Copia al final de tu `README.md`:

```markdown
## Declaración de autoría y uso de IA
- Herramienta utilizada: ____ (o «ninguna»)
- Para qué la usé: ____ (ej.: entender por qué mi foreach no leía la macro)
- Qué hice yo: ____
- Verificación: confirmo que entiendo y puedo explicar todo lo que entrego.
```

**Uso permitido:** depurar un loop que no corre, entender un mensaje de error,
preguntar la diferencia entre `local` y `global`, pedir alternativas a un bloque
que ya escribiste.

**Uso no permitido:** pedir el do-file completo. En esta tarea se pregunta en
particular por el **diseño**: por qué esa macro, por qué un programa y no un loop,
qué pasa si cambia el argumento. Si el diseño no es tuyo, no podrás responder.

Declarar el uso de IA **no baja la nota**. No saber o no entender tu código, **sí**.
Ocultar el uso constituye falta a la ética académica (Guía de uso ético de
tecnologías digitales, UdeC).
