# T5 — Do-file automatizado
Autor: Francisca Quezada
Fecha: 2026-11-19

## Contenido
- `scripts/tarea_t5.do`: do-file comentado.
- `output/tarea_t5.log`: log de la corrida completa.
- `output/tarea_t5_por_sector.xlsx`: regresión de ingreso en educación por sector.
- `data/raw/casen_reducido.csv`: datos (60 personas).

## Qué automaticé
- Todos los parámetros (archivo de datos, variable dependiente, variable de educación, listas de variables, controles, grupos y umbral) están en un bloque de macros al inicio. Cambiar una macro actualiza todo el do-file.
- `foreach` para los descriptivos de la lista de variables numéricas.
- `forvalues` para contar personas por tramo de educación, usando `r(N)`.
- Un `program` (`descriptivos_grupo`) con argumentos, llamado desde un loop para todos los grupos.
- `tempvar` para una variable intermedia que no queda en la base.
- Filtro por umbral con `!missing()` para no contar los faltantes.
- Dos modelos guardados con `estimates store` y comparados en una tabla.
- Una regresión por sector en un loop, guardada en una matriz con `J()` y exportada a Excel con `putexcel`.

## Cómo correrlo
1. Abrir Stata y ajustar la línea `cd` del do-file a la carpeta del proyecto.
2. Ejecutar el do-file completo (`do scripts/tarea_t5.do`).

## Qué editar para usarlo con otros datos
- En el bloque de parámetros: `datos`, `depvar`, `xeduc`, `numericas`, `controles`, `grupos`, `grupo_reg` y `umbral`.
- La línea `cd` con la ruta de la carpeta del proyecto.
- Si la base no tiene las variables `edad`, `educ` y `genero` (texto "F"/"M"), hay que ajustar el paso 2: la fórmula de `experiencia` y la creación de `mujer`.
- El modelo m2 usa `i.mujer`; si se cambia esa variable, hay que cambiarla ahí también.
