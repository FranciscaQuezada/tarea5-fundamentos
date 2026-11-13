
* T5 — Do-file automatizado
* Autor: Francisca Quezada        Fecha: 2026-11-12

** 1. Encabezado con macros de configuración
version 14
clear all
set more off
cd "C:\Users\franc\OneDrive\Documentos\Programación\tarea5-fundamentos"
capture mkdir "output"
capture log close
log using "output/tarea_t5.log", replace text

pwd

* Parámetros (lo único que se edita)
local datos "data/raw/casen_reducido.csv"
local depvar "ingreso"
local xeduc      "educ"                          //variable de educ
local numericas "ingreso educ edad experiencia"  
local controles "educ experiencia"              // sin edad
local grupos "sector region genero"
local grupo_reg  "sector"                       //para la reg por grupo
global umbral = 500000

* Justificación "local" y "global"
* Local: para datos, depvar, xeduc, numericas, controles, grupos y
* grupo_reg porque solo se usan dentro de este do-file; así no 
* "contaminan" la sesión de Stata ni pueden ser pisadas por otro 
* do-file, y mueren al terminar la corrida.
* Global: para umbral porque es un parámetro de definición (qué es un 
* "ingreso alto") que querría compartir con otros do-files del 
* proyecto; se evalúa con $umbral y sobrevive toda la sesión.

** 2. Carga y prepara los datos
import delimited "`datos'", clear varnames(1) encoding("utf-8")
describe, short                                //60 obs, 7 variables

* Experiencia potencial (Mincer), con piso en 0. 
generate experiencia = max(edad - educ - 6, 0) 
label variable experiencia "Experiencia potencial (años)"

* genero es texto ("F"/"M"): no puede entrar a una regresión. Creo 
* una 0/1.
generate mujer = (genero == "F") if !missing(genero)
label variable mujer "Mujer (1 = sí)"
label define sexo 0 "Hombre" 1 "Mujer"
label values mujer sexo
tabulate mujer

** 3. Un `foreach` sobre una lista de variables
foreach v of local numericas {
    display _newline "===== `v' ====="
    summarize `v', detail
}

** 4. Un `forvalues` con un rango
* Tramos de 4 años: 4-7, 8-11, 12-15 y 16-19 (quien tenga 20 años o 
* menos de 4 queda fuera de los tramos).
display _newline "Personas por tramo de educación (" "`xeduc'" ")"
forvalues t = 4(4)16 {
    quietly count if `xeduc' >= `t' & `xeduc' < `t' + 4
    display "Educación de `t' a " `t' + 3 " años: " r(N) " personas"
}

** 5. Un `program` reutilizable con argumentos
* Un programa no ve las macros locales del do-file (scope): por eso 
* todo lo que necesita entra como argumento. 1 = variable de grupo,
* 2 = variable dependiente, 3 = variable de educación
capture program drop descriptivos_grupo
program define descriptivos_grupo
    display _newline "=== Descriptivos de `2' y `3' por `1' ==="
    tabulate `1'
    tabstat `2' `3', by(`1') statistics(mean sd n)
end

foreach g of local grupos {
    descriptivos_grupo `g' `depvar' `xeduc'
}

** 6. Usa `tempvar` al menos una vez
tempvar ing_miles
generate `ing_miles' = `depvar' / 1000
summarize `ing_miles'

* tempvar es más seguro que crear una variable normal y borrarla 
* después porque Stata le da un nombre único (que no choca con 
* ninguna variable mía) y la elimina sola al terminar; si el do-file
* se detiene por un error a mitad de camino, no queda basura en los 
* datos ni un "variable already defined" al volver a correrlo. Con 
* generate + drop, un error antes del drop deja la variable en la base.

** 7. Maneja los missing correctamente
display _newline "Umbral de ingreso (pesos): " %9.0fc $umbral

* Incorrecto: en Stata el missing (.) es MAYOR que cualquier 
* número, así que "ingreso > umbral" también es verdadero para los 
* missing y count los suma como si fueran ingresos altos (infla el 
* resultado).
count if `depvar' > $umbral

* Correcto: excluyo explícitamente los faltantes.
count if `depvar' > $umbral & !missing(`depvar')

** 8. Modelos guardados y comparados (S13)
quietly regress `depvar' `controles'
estimates store m1

quietly regress `depvar' `controles' i.mujer
estimates store m2

estimates table m1 m2, b(%9.0f) se stats(N r2) stfmt(%5.3f)

* Coeficiente de educación de cada modelo, leído de e() / _b[] (no copiado a mano)
foreach m in m1 m2 {
    estimates restore `m'
    display "`m': beta de `xeduc' = " %9.0fc _b[`xeduc'] ///
        "  (ee = " %9.0fc _se[`xeduc'] ")  N = " e(N)
}

** 9. Una regresión por grupo, guardada en una matriz y exportada
levelsof `grupo_reg', local(sectores)
local k : word count `sectores'
matrix R = J(`k', 3, .)

local i = 1
foreach s of local sectores {
    quietly regress `depvar' `xeduc' if `grupo_reg' == "`s'"
    matrix R[`i', 1] = _b[`xeduc']
    matrix R[`i', 2] = _se[`xeduc']
    matrix R[`i', 3] = e(N)
    local i = `i' + 1
}
matrix colnames R = beta_`xeduc' ee n
matrix rownames R = `sectores'
matrix list R, format(%9.0f)

putexcel set "output/tarea_t5_por_sector.xlsx", replace
putexcel A1 = ("Sector") B1 = ("Beta `xeduc'") C1 = ("Error est.") D1 = ("n")
putexcel B2 = matrix(R)

local fila = 2
foreach s of local sectores {
    putexcel A`fila' = ("`s'")
    local fila = `fila' + 1
}

** 10. Cierra el log e interpreta
log close

* Interpretación
* En m1, cada año de educación se asocia a unos $42.019 más de 
* ingreso mensual; en m2, al agregar la indicadora de mujer, pasa a 
* $42.246 (ee $6.355): casi no cambia. En m2, ser mujer se asocia a 
* unos $55.686 menos de ingreso, pero con un error estándar de 
* $43.302, por lo que esa diferencia es imprecisa. Por sector, el 
* coeficiente de educación va de $23.800 (Construcción) a $42.700 
* (Industria), pero cada regresión usa solo entre 5 y 15 personas, 
* así que son muy imprecisas. Limitación: muestra pequeña (55 con 
* ingreso) y variables omitidas; son asociaciones.

** Declaración de autoría y uso de IA
* Herramienta utilizada: Claude
* Para qué la usé: apoyo para corregir punto 6 "tempvar", punto 7 y 
* 8 y entender errores de Stata (macros locales, scope de los 
* programas, missing).
* Qué hice yo: armar el do-file en Stata y luego correrlo, 
* interpretar resultados, y subir los archivos a GitHub.
* Verificación: confirmo que entiendo y puedo explicar todo lo que 
* entrego.