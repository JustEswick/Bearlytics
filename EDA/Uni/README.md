# EDA / Uni

Observaciones del análisis exploratorio univariado de las señales de vibración de los rodamientos: RMS, kurtosis, crest factor y skewness en los sensores horizontal (H) y vertical (V). Este documento describe los resultados de la fase EDA/Uni; no define modelos ni particiones de entrenamiento.

## 1. Objetivo y alcance

El análisis cubre los **17 rodamientos completos** disponibles: 6 de `Learning_set` y 11 de `Full_Test_Set`. Se procesaron **24.889 snapshots** de aceleración, con **2 sensores** y **4 features** de dominio temporal por snapshot. El alcance es descriptivo: caracterizar el comportamiento de las features a lo largo de la ventana observada de cada rodamiento.

Quedan fuera del análisis:

- `Test_set`: contiene los mismos 11 rodamientos que `Full_Test_Set` con series truncadas; no es una partición independiente y no se usa como validación ni como test.
- Los ficheros `temp_*.csv`: son registros de temperatura, no snapshots de aceleración, y no se analizan aquí.
- Cualquier etiqueta o evaluación de RUL: `RUL_FEMTO.txt` no está presente en el dataset.

No se evalúa RUL, no se comparan modelos y no se decide ninguna partición train/validation/test en este documento.

## 2. Metodología

### 2.1 Datos de entrada

Cada snapshot es un fichero `acc_*.csv` sin cabecera, de 2.560 filas × 6 columnas. Las columnas 5 y 6 contienen las señales de aceleración H y V, respectivamente: 2.560 muestras que corresponden a 0,1 s a 25,6 kHz. Los snapshots se registran cada 10 s.

El tiempo de cada snapshot se calcula como:

```text
t = (i - 1) · 10 / 3600  horas
```

donde `i` es el índice del snapshot dentro del rodamiento. El origen de tiempo de cada rodamiento es su primer snapshot (`t = 0`), de modo que los tiempos absolutos no son comparables entre rodamientos: solo lo son las ventanas relativas dentro de cada serie.

Solo se recorren las carpetas `Learning_set` y `Full_Test_Set`. El dataset se abre en modo lectura y no se modifica.

### 2.2 Definición de las features

Para cada snapshot y sensor se centra la señal antes de calcular las features:

```text
x = s - mean(s)
RMS = sqrt(mean(x.^2))
crestFactor = max(abs(x)) / RMS
```

- **RMS**: raíz de la media cuadrática de la señal centrada. Conserva las unidades originales de la señal; no se aplica ninguna conversión de unidades.
- **Kurtosis**: `kurtosis(x)` estándar de MATLAB, no kurtosis de exceso. Una distribución gaussiana tiende a un valor de 3. Es adimensional.
- **Crest factor**: cociente entre el máximo valor absoluto y el RMS. Es adimensional.
- **Skewness**: `skewness(x)` estándar de MATLAB. Un valor de 0 indica simetría. Es adimensional.

Este repositorio no documenta la unidad física de las señales de aceleración; por eso el RMS se expresa en las unidades originales del CSV y no se asume `g` ni se aplica conversión.

Las features se calculan sobre las 2.560 muestras completas de cada snapshot de 0,1 s.

### 2.3 Tablas generadas

- `results/eda_uni_features.csv`: una fila por snapshot; las features de H y V van en columnas separadas. Contiene 24.889 filas y las columnas `partition`, `bearing`, `condition`, `snapshotIndex`, `elapsedHours`, `rmsH`, `rmsV`, `kurtosisH`, `kurtosisV`, `crestFactorH`, `crestFactorV`, `skewnessH` y `skewnessV`.
- `results/eda_uni_summary.csv`: una fila por rodamiento × feature × sensor (17 × 4 × 2 = **136 filas**). Para cada combinación resume `first`, `last`, `delta` (`last - first`), `min`, `max` y `monotonicFraction`.

`monotonicFraction` se define como la fracción de diferencias consecutivas cuyo signo coincide con el signo del delta total. Si el rodamiento tiene un solo snapshot, vale 1. Un valor cercano a 0,5 indica que no hay una dirección persistente en la serie; no implica degradación monotónica ni funciona como indicador de salud.

### 2.4 Figuras

Se generan **68 figuras PNG** (17 rodamientos × 4 features), una por rodamiento y feature, con H y V superpuestos, eje x en horas y resolución de 150 dpi. El patrón de nombre es:

```text
results/eda_uni_<bearing>_<feature>_trend.png
```

con `<bearing>` en minúsculas y `<feature>` en las claves `rms`, `kurtosis`, `crest_factor` y `skewness`. Por ejemplo, `results/eda_uni_bearing1_1_rms_trend.png`.

El eje y se ajusta automáticamente en cada figura; las alturas no son comparables entre rodamientos. Para comparar niveles, usar la tabla de la sección 3 o los CSV.

### 2.5 Reproducción

Desde la raíz del repositorio:

```matlab
matlab -batch "run('EDA/Uni/test_eda_uni.m')"
matlab -batch "run('EDA/Uni/run_eda_uni.m')"
```

El script de pruebas recorre los casos de carga y cálculo de features y termina imprimiendo `TODO OK` si todos pasan. La última ejecución completa verificada procesó 24.889 snapshots en **761,7 s (12,70 min)** con MATLAB R2026b; el tiempo depende del equipo.

## 3. Cobertura por rodamiento

| Rodamiento | Partición | Cond. | Snapshots | Ventana (h) | RMS H (1.º→últ.) | RMS V (1.º→últ.) | Kurtosis H (1.º→últ.) | Kurtosis V (1.º→últ.) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Bearing1_1 | Learning_set | 1 | 2803 | 7.78 | 0.562 → 5.61 | 0.436 → 5.09 | 2.87 → 11 | 2.96 → 19.6 |
| Bearing1_2 | Learning_set | 1 | 871 | 2.42 | 0.539 → 2.23 | 0.421 → 4.07 | 3.41 → 10.3 | 3.27 → 6.94 |
| Bearing2_1 | Learning_set | 2 | 911 | 2.53 | 0.509 → 2.37 | 0.263 → 2.21 | 3.11 → 10.9 | 2.98 → 4.41 |
| Bearing2_2 | Learning_set | 2 | 797 | 2.21 | 0.28 → 1.96 | 0.19 → 2.7 | 3.16 → 17.5 | 2.86 → 46.8 |
| Bearing3_1 | Learning_set | 3 | 515 | 1.43 | 0.402 → 0.857 | 0.3 → 1.44 | 4.14 → 3.52 | 3.05 → 3.4 |
| Bearing3_2 | Learning_set | 3 | 1637 | 4.54 | 0.354 → 1.91 | 0.241 → 2.19 | 2.97 → 13.5 | 2.97 → 6.9 |
| Bearing1_3 | Full_Test_Set | 1 | 2375 | 6.59 | 0.416 → 9.24 | 0.302 → 6.75 | 3.07 → 3.23 | 3.05 → 5.35 |
| Bearing1_4 | Full_Test_Set | 1 | 1428 | 3.96 | 0.403 → 9.33 | 0.455 → 10.5 | 2.98 → 4.08 | 3.14 → 3.87 |
| Bearing1_5 | Full_Test_Set | 1 | 2463 | 6.84 | 0.401 → 1.4 | 0.357 → 1.87 | 3.23 → 17.7 | 2.93 → 4.46 |
| Bearing1_6 | Full_Test_Set | 1 | 2448 | 6.80 | 0.473 → 1.29 | 0.478 → 1.95 | 3.97 → 8.03 | 2.87 → 3.97 |
| Bearing1_7 | Full_Test_Set | 1 | 2259 | 6.27 | 0.438 → 2.36 | 0.392 → 2.39 | 3.44 → 12.9 | 3.1 → 9.14 |
| Bearing2_3 | Full_Test_Set | 2 | 1955 | 5.43 | 0.431 → 7.26 | 0.251 → 1.27 | 3.37 → 7.15 | 3.17 → 12.5 |
| Bearing2_4 | Full_Test_Set | 2 | 751 | 2.08 | 0.341 → 1.56 | 0.239 → 1.59 | 3.03 → 5.49 | 2.91 → 5.58 |
| Bearing2_5 | Full_Test_Set | 2 | 2311 | 6.42 | 0.528 → 0.734 | 0.226 → 1.67 | 4.13 → 79.2 | 3.01 → 80.2 |
| Bearing2_6 | Full_Test_Set | 2 | 701 | 1.94 | 0.344 → 1.5 | 0.333 → 2.24 | 3 → 4.32 | 3.12 → 3.67 |
| Bearing2_7 | Full_Test_Set | 2 | 230 | 0.64 | 0.413 → 5.4 | 0.36 → 2 | 3.02 → 3.39 | 3.32 → 15.4 |
| Bearing3_3 | Full_Test_Set | 3 | 434 | 1.20 | 0.288 → 1.3 | 0.297 → 2.23 | 3.35 → 4.19 | 3.03 → 7.43 |

Cobertura agregada: **24.889 snapshots** en total, de los cuales 7.534 pertenecen a `Learning_set` (6 rodamientos) y 17.355 a `Full_Test_Set` (11 rodamientos). Por condición de operación: **condición 1 = 14.647 snapshots / 7 rodamientos**, **condición 2 = 7.656 / 7** y **condición 3 = 2.586 / 3**.

La columna «Ventana (h)» es el intervalo entre el primer y el último snapshot, calculado como `(nSnapshots - 1) · 10 / 3600`. No es la duración total del experimento ni una medida del tiempo real transcurrido entre ensayos; cada serie tiene su propio origen en el primer snapshot.

Nota de formato: la tabla conserva el punto decimal de los CSV y redondea a un máximo de 3 cifras significativas; la prosa usa coma decimal. Los CSV conservan la precisión completa.

## 4. Observaciones por rodamiento

En las 136 filas del resumen, `monotonicFraction` oscila entre 0,477 y 0,536 en todas las features y sensores. Por tanto, **ninguna de las tendencias es monotónica**. Un valor cercano a 0,5 indica que el ascenso no se sostiene a lo largo de toda la ventana; no contradice el aumento visible al final de muchas series. Las observaciones siguientes describen primer valor, último valor y máximos o mínimos cuando aportan información; el último snapshot es una observación puntual y no un nivel robusto.

**Bearing1_1** (Learning_set, condición 1; 2.803 snapshots, 7,78 h). El RMS se mantiene en una línea base baja durante las primeras ~4 h (con un pico aislado de V hacia 3,6 h) y después asciende de forma progresiva, con un tramo final pronunciado: H pasa de 0,562 a 5,61 y V de 0,436 a 5,09. La kurtosis también aumenta al final, con V (2,96→19,6) por encima de H (2,87→11,0); los máximos aislados son mucho mayores (≈60 en H y ≈189 en V) y no representan el nivel final. La diferencia H/V es notable en la kurtosis final y en el crest factor (H 3,57→7,05; V 3,66→9,49). Tendencia no monotónica.

**Bearing1_2** (Learning_set, condición 1; 871 snapshots, 2,42 h). La ventana es corta y el RMS se mantiene bajo la mayor parte del tiempo, con un ascenso abrupto al final: H 0,539→2,23 y V 0,421→4,07, claramente por encima en V. La kurtosis es muy intermitente: los máximos H ≈195 y V ≈319 son picos transitorios, mientras que los valores finales son moderados (H 10,3; V 6,94). El crest factor acompaña esos picos (máximos ≈23,3 H y ≈25,8 V) y la skewness alterna signos sin un nivel final destacado. Tendencia no monotónica.

**Bearing2_1** (Learning_set, condición 2; 911 snapshots, 2,53 h). El RMS presenta un tramo inicial con un pico aislado, una meseta intermedia y un ascenso final abrupto: H 0,509→2,37 (máximo 2,70) y V 0,263→2,21 (máximo 2,62). La kurtosis H termina en 10,9 frente a 4,41 en V; ambas tienen máximos transitorios grandes (≈51 H y ≈135 V). La diferencia H/V se aprecia en la kurtosis final y en el crest factor (H 8,01 frente a V 5,51). Tendencia no monotónica.

**Bearing2_2** (Learning_set, condición 2; 797 snapshots, 2,21 h). El RMS dibuja un abultamiento hacia la mitad de la ventana, desciende después y da un salto final: H 0,280→1,96 y V 0,190→2,70. El incremento absoluto es mayor en V, que termina por encima de H. La kurtosis V termina muy alta (46,8) frente a 17,5 en H, y el máximo de V coincide con el valor final. La skewness H se vuelve fuertemente negativa (≈-2,57; mínimo ≈-3,20) y el crest factor sube en ambos canales (H 4,43→8,96; V 3,59→14,2). Tendencia no monotónica.

**Bearing3_1** (Learning_set, condición 3; 515 snapshots, 1,43 h). El RMS es casi plano hasta un episodio transitorio al final de la ventana. El RMS H alcanza un máximo aislado de ≈2,44 y luego vuelve a 0,857, mientras que V termina en 1,44 (máximo 1,68). La kurtosis, el crest factor y la skewness concentran ahí sus valores extremos (kurtosis H máximo ≈416; crest H máximo ≈31,7; skewness H mínimo ≈-14,4), pero la kurtosis final vuelve a ≈3,52 H y ≈3,40 V. Es el ejemplo más claro de un transitorio que el valor final oculta. Tendencia no monotónica.

**Bearing3_2** (Learning_set, condición 3; 1.637 snapshots, 4,54 h). El RMS se mantiene bajo hasta ~4 h, con un pequeño abultamiento previo al ascenso final: H 0,354→1,91 y V 0,241→2,19. La kurtosis sube en ambos canales (H 2,97→13,5; V 2,97→6,90); el máximo V ≈219 es un pico transitorio temprano, no el nivel final. La skewness H termina negativa (≈-0,58) y el crest factor aumenta (H 3,56→8,23; V 3,31→8,01). Tendencia no monotónica.

**Bearing1_3** (Full_Test_Set, condición 1; 2.375 snapshots, 6,59 h). Después de varias horas con RMS bajo, el RMS H asciende de forma sostenida desde ~4 h y se acentúa al final (0,416→9,24; máximo 10,3). El RMS V también aumenta, pero de forma más intermitente: 0,302→6,75, con un máximo transitorio de 13,5 que no es el nivel final. Pese a ese nivel final alto, la kurtosis final se mantiene baja (H 3,23; V 5,35); los máximos de kurtosis son transitorios (≈74 H y ≈245 V). El crest factor H apenas cambia (3,55→3,64), mientras que el V sube a 5,39. En este rodamiento, un RMS final alto coexiste con una kurtosis final baja. Tendencia no monotónica.

**Bearing1_4** (Full_Test_Set, condición 1; 1.428 snapshots, 3,96 h). El RMS permanece bajo hasta ~3 h y luego asciende de forma marcada y sostenida: H 0,403→9,33 (máximo 11,1) y V 0,455→10,5 (máximo 14,6), los valores finales de RMS más altos entre los 17 rodamientos. La kurtosis final sigue siendo moderada (H 4,08; V 3,87), con un pico transitorio H ≈21,1 al inicio del ascenso. El crest factor V es casi plano al final (4,50→4,49) pese al aumento de RMS; el H sube a 5,14. Tendencia no monotónica.

**Bearing1_5** (Full_Test_Set, condición 1; 2.463 snapshots, 6,84 h). El RMS se mantiene bajo y estable durante casi toda la ventana y solo sube de forma abrupta al final: H 0,401→1,40 y V 0,357→1,87 (máximo 1,93). La kurtosis H termina alta (17,7), mientras que V termina en 4,46; V presenta máximos transitorios muy superiores (≈118) en el tramo final. El crest factor H sube a 8,89 y el V a 5,36. Tendencia no monotónica.

**Bearing1_6** (Full_Test_Set, condición 1; 2.448 snapshots, 6,80 h). El RMS se mantiene bajo, con un abultamiento transitorio antes del tramo final y un ascenso abrupto al cierre: H 0,473→1,29 y V 0,478→1,95. La kurtosis final es H 8,03 y V 3,97, con máximos transitorios muy grandes (≈126 H y ≈222 V) que no se reflejan en el valor final. El crest factor sube en ambos canales (H 5,69→7,07; V 3,46→4,88). Tendencia no monotónica.

**Bearing1_7** (Full_Test_Set, condición 1; 2.259 snapshots, 6,27 h). El RMS desciende ligeramente al inicio, asciende de forma gradual desde ~3 h y termina con un pico final: H 0,438→2,36 y V 0,392→2,39, con valores finales casi iguales entre sensores (máximos 2,48 y 2,44). La kurtosis sube en ambos canales (H 3,44→12,9; V 3,10→9,14), con el máximo concentrado en el pico final. El crest factor aumenta (H 4,12→9,02; V 3,82→9,00) y la skewness V termina positiva (≈0,62; máximo 1,62). Tendencia no monotónica.

**Bearing2_3** (Full_Test_Set, condición 2; 1.955 snapshots, 5,43 h). El RMS H permanece bajo y estable hasta un pico final aislado (máximo 14,3) que deja el último valor en 7,26; el V, mucho más ruidoso, termina en 1,27 (máximo 2,95). La diferencia H/V es fuerte. La kurtosis V termina más alta (12,5) que la H (7,15), con un máximo V transitorio ≈406. El crest factor V sube a 7,43 frente a 4,90 en H. Tendencia no monotónica.

**Bearing2_4** (Full_Test_Set, condición 2; 751 snapshots, 2,08 h). El RMS se mantiene bajo casi toda la ventana y da un salto final muy abrupto: H 0,341→1,56 y V 0,239→1,59, que son también los máximos. La kurtosis termina en ≈5,5 en ambos canales (H 5,49; V 5,58), tras un grupo de picos transitorios a mitad de ventana (máximos ≈21,5 H y ≈28,3 V). La skewness H se vuelve negativa (≈-0,66; mínimo ≈-1,63). Tendencia no monotónica.

**Bearing2_5** (Full_Test_Set, condición 2; 2.311 snapshots, 6,42 h). Es el caso extremo de kurtosis: tras una línea base larga con valores ≈3-4 (con picos menores intercalados), la kurtosis se dispara en el tramo final hasta 79,2 H y 80,2 V, con máximos transitorios de ≈106 H y ≈232 V. El RMS H no muestra una tendencia sostenida: 0,528→0,734, con un pico aislado de 2,03 a ≈0,33 h; el V pasa de 0,226 a 1,67. El crest factor sube con fuerza (H 4,84→14,8; V 3,72→13,5) y la skewness H termina fuertemente negativa (≈-2,25; mínimo ≈-6,13). Tendencia no monotónica.

**Bearing2_6** (Full_Test_Set, condición 2; 701 snapshots, 1,94 h). La ventana es corta. El RMS se mantiene bajo hasta el salto final: H 0,344→1,50 y V 0,333→2,24 (máximo 2,31), con V por encima. La kurtosis final es moderada (H 4,32; V 3,67); el máximo V ≈100 es un pico aislado a mitad de ventana. El crest factor sube ligeramente (H 3,62→4,46; V 3,60→4,51) y la skewness H termina algo negativa (≈-0,26). Tendencia no monotónica.

**Bearing2_7** (Full_Test_Set, condición 2; 230 snapshots, 0,64 h). Es la ventana más corta del conjunto, por lo que la lectura debe ser prudente. El RMS H da un pico final muy alto (máximo 6,28) y termina en 5,40, mientras que el V termina en 2,00 (máximo 2,58); la diferencia H/V es notable. La kurtosis H termina solo en 3,39, pero la V en 15,4, con numerosos picos transitorios (máximos ≈83 H y ≈185 V). El crest factor H termina algo más bajo (3,32→3,11), mientras que el V sube a 8,76. Tendencia no monotónica; con esta ventana no puede separarse el posible carácter transitorio del pico final.

**Bearing3_3** (Full_Test_Set, condición 3; 434 snapshots, 1,20 h). Es la serie de condición 3 más corta. El RMS se mantiene bajo hasta ~0,8 h, luego asciende de forma gradual y da un salto final: H 0,288→1,30 y V 0,297→2,23, con V por encima. La kurtosis termina en 4,19 H y 7,43 V; sus máximos son los más bajos del conjunto (≈6,11 H y ≈8,38 V), y el crest factor también es el más bajo (≈7,47 H y ≈7,91 V), sin que esto permita generalizar. La skewness V termina positiva (≈0,60) y la H negativa (≈-0,40). Tendencia no monotónica.

## 5. Síntesis por condición

### Condición 1

7 rodamientos y 14.647 snapshots. Incluye los dos valores finales de RMS H más altos del conjunto (Bearing1_4, 9,33; Bearing1_3, 9,24) y el aumento final de Bearing1_1 hasta 5,61, pero también casos de RMS final moderado (Bearing1_5, 1,40; Bearing1_6, 1,29). La kurtosis final abarca desde ≈3,2 hasta ≈19,6. En esta condición, un RMS final alto y una kurtosis final alta no aparecen necesariamente juntos: Bearing1_3 termina con RMS H 9,24 y kurtosis H 3,23, mientras que Bearing1_1 termina con RMS H 5,61 y kurtosis V 19,6.

### Condición 2

7 rodamientos y 7.656 snapshots. Es el grupo más heterogéneo. Bearing2_5 es el caso extremo de kurtosis final (≈79,2 H y ≈80,2 V); Bearing2_2 termina con kurtosis V ≈46,8; Bearing2_3 muestra una fuerte diferencia H/V en RMS (7,26 H frente a 1,27 V); Bearing2_4 y Bearing2_6 presentan valores finales moderados (RMS H 1,56 y 1,50; kurtosis ≈5,5 y ≈4,3/3,7); Bearing2_7 es muy corto (0,64 h) y su lectura es la menos estable. Bearing2_1 completa el grupo con un aumento final de RMS hasta 2,37/2,21 y kurtosis H 10,9.

### Condición 3

3 rodamientos y 2.586 snapshots. Bearing3_1 presenta picos transitorios extremos pero una kurtosis final baja (≈3,5/3,4); Bearing3_2 asciende en RMS y kurtosis (H 13,5); Bearing3_3 tiene los máximos de kurtosis y crest factor más bajos del conjunto. La muestra de condición 3 es demasiado pequeña y las ventanas observadas son demasiado distintas para ordenar condiciones o inferir severidad.

### Comparación entre condiciones

Las ventanas observadas van de 0,64 h a 7,78 h; los grupos están desbalanceados (7, 7 y 3 rodamientos; 14.647, 7.656 y 2.586 snapshots) y la condición 1 contiene las ventanas más largas. Estas diferencias confunden cualquier comparación directa entre condiciones. La síntesis anterior es descriptiva, no causal: describe qué features cambian y cuánto, sin atribuir los cambios a una causa concreta.

## 6. Limitaciones y restricciones

- **`Test_set` excluido**: es una copia truncada de los mismos 11 rodamientos de `Full_Test_Set`. No es una partición independiente; no debe usarse como validación ni como test. `Full_Test_Set` y `Test_set` comparten identidad y no pueden ser conjuntos independientes de validación/test.
- **Sin etiquetas RUL**: `RUL_FEMTO.txt` no existe en el dataset. Este EDA no define train/validation/test. Cualquier partición futura debe hacerse **por rodamiento, nunca por snapshot**, y debe documentarse la restricción de fuga de información entre snapshots del mismo rodamiento.
- **Temperatura no analizada**: los ficheros `temp_*.csv` quedan fuera de este análisis.
- **Solo features de dominio temporal** sobre snapshots de 0,1 s: no hay análisis frecuencial ni de órdenes, filtrado, normalización, eliminación de outliers ni cuantificación de incertidumbre.
- **El último snapshot es una sola observación**: los máximos pueden ser transitorios y no representan un nivel estable. Las 68 figuras están versionadas en `results/`; este documento resume las observaciones y no sustituye su revisión visual.
- **`monotonicFraction` cercano a 0,5** indica ausencia de degradación monotónica; no debe usarse como indicador de salud.
- **Sin interpretación causal**: el dataset es run-to-failure, pero aquí se describe el comportamiento de las features, no se explica su origen.

## 7. Artefactos

| Artefacto | Contenido |
|---|---|
| `results/eda_uni_features.csv` | 24.889 filas; una por snapshot, con las features de H y V en columnas separadas; 13 columnas; precisión completa. |
| `results/eda_uni_summary.csv` | 136 filas; resumen por rodamiento × feature × sensor; precisión completa. |
| `results/eda_uni_<bearing>_<feature>_trend.png` | 68 figuras PNG (17 × 4), H/V superpuestos, 150 dpi; versionadas en `results/`. |

Código asociado: `+bearlytics/loadAccSnapshot.m`, `+bearlytics/computeTimeFeatures.m`, `EDA/Uni/run_eda_uni.m`, `EDA/Uni/plotFeatureTrend.m` y `EDA/Uni/test_eda_uni.m`.

Los comandos de reproducción y el tiempo de la última ejecución están en §2.5.
