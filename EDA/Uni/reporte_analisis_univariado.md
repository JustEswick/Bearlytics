# Reporte — Análisis Exploratorio Univariado (EDA/Uni)

**Proyecto:** Bearlytics (predicción de RUL de rodamientos)  
**Fase:** EDA/Uni (análisis univariado)  
**Dataset:** FEMTO / PRONOSTIA (IEEE PHM 2012), carpeta `10. FEMTO Bearing/` (solo lectura)  
**Rama:** `feature/eda-uni-tendencias-univariadas`  
**Commit de referencia:** `16b8987` (solo `EDA/Uni/README.md` modificado sobre `85ef7dd`)  
**Ejecutor:** MATLAB R2026b  

---

## 1. Resumen ejecutivo

Se completó la Fase 1 **EDA/Uni** sobre los 17 rodamientos completos del dataset FEMTO. El análisis es **descriptivo y univariado**: para cada snapshot se calcularon 4 features de dominio temporal (RMS, kurtosis, crest factor y skewness) en los dos sensores (H y V), se generaron 68 figuras (una por rodamiento × feature) y se produjeron dos tablas CSV tidy (24.889 filas de features y 136 filas de resumen).

**Resultado clave:** ninguna de las 136 tendencias es monotónica (`monotonicFraction` entre 0,477 y 0,536). La degradación no es lineal ni sostenida en toda la ventana; los máximos pueden ser transitorios y no representan un nivel estable. Esto tiene implicaciones directas para la fase PreProcess (Health Index, normalización y split por rodamiento).

---

## 2. Alcance y datos

| Partición | Rodamientos | Snapshots | Condición 1 | Condición 2 | Condición 3 |
|-----------|-------------|-----------|-------------|-------------|-------------|
| `Learning_set` | 6 | 7.534 | 7 rodamientos / 14.647 snapshots | 7 / 7.656 | 3 / 2.586 |
| `Full_Test_Set` | 11 | 17.355 | — | — | — |
| **Total** | **17** | **24.889** | — | — | — |

- Se excluyó `Test_set` (copia truncada de los mismos 11 rodamientos de `Full_Test_Set`; no es partición independiente).
- Se excluyeron los ficheros `temp_*.csv` (no son snapshots de 2560×6).
- Cada snapshot: `acc_*.csv`, sin cabecera, 2560 filas × 6 columnas; columnas 5 y 6 = aceleración H y V; 2560 muestras = 0,1 s a 25,6 kHz; cadence = 10 s entre snapshots.
- El origen de tiempo de cada rodamiento es su primer snapshot (`t = 0`); los tiempos absolutos no son comparables entre rodamientos.
- `Full_Test_Set/Bearing1_4` usa delimitador `;`; el resto `,`.

---

## 3. Metodología

### 3.1 Features (por snapshot y sensor)

La señal se centra antes de calcular cada feature: `x = s - mean(s)`.

| Feature | Definición | Unidad | Comentario |
|---------|-----------|--------|------------|
| RMS | `sqrt(mean(x.^2))` | Original del CSV (no se asume `g`) | Conserva unidades originales |
| Kurtosis | `kurtosis(x)` de MATLAB (no exceso) | Adimensional | Gaussiana ≈ 3 |
| Crest factor | `max(abs(x)) / RMS` | Adimensional | — |
| Skewness | `skewness(x)` de MATLAB | Adimensional | 0 = simetría |

### 3.2 Tablas generadas

- `results/eda_uni_features.csv`: 24.889 filas, una por snapshot; H y V en columnas separadas; 13 columnas; precisión completa.
- `results/eda_uni_summary.csv`: 136 filas (17 × 4 × 2); `first`, `last`, `delta`, `min`, `max`, `monotonicFraction` por rodamiento × feature × sensor.

### 3.3 Figuras

- 68 figuras PNG (17 rodamientos × 4 features), una por rodamiento y feature, H y V superpuestos, eje X en horas, 150 dpi.
- Patrón: `results/eda_uni_<bearing>_<feature>_trend.png`.
- El eje Y se ajusta automáticamente por figura; las alturas no son comparables entre rodamientos (para niveles, usar la tabla de cobertura o los CSV).

### 3.4 Reproducción

Desde la raíz del repositorio:

```matlab
matlab -batch "run('EDA/Uni/test_eda_uni.m')"
matlab -batch "run('EDA/Uni/run_eda_uni.m')"
```

El script de pruebas termina imprimiendo `TODO OK`. La última ejecución completa verificó 24.889 snapshots, sin NaN/Inf, en 761,7 s (12,70 min) con MATLAB R2026b (tiempo dependiente del equipo).

---

## 4. Hallazgos principales

### 4.1 Tabla de cobertura (primer → último valor)

| Rodamiento | Partición | Cond. | Snapshots | Ventana (h) | RMS H | RMS V | Kurtosis H | Kurtosis V |
|------------|-----------|-------|-----------|-------------|-------|-------|------------|------------|
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

Nota de formato: la tabla conserva el punto decimal de los CSV; la prosa de este reporte usa coma decimal.

### 4.2 Hallazgos destacados

- **Sin monotonicidad:** `monotonicFraction` oscila entre 0,477 y 0,536 en todas las combinaciones; ninguna tendencia es monotónica. El último snapshot es una observación puntual, no un nivel robusto.
- **Kurtosis extrema:** Bearing2_5 es el caso extremo (línea base ≈3-4, disparo final a 79,2 H y 80,2 V; máximos transitorios ≈106 H y ≈232 V). Su RMS H no muestra tendencia sostenida (pico aislado de 2,03 a ≈0,33 h), lo que demuestra que kurtosis y RMS pueden divergir.
- **RMS final más altos:** Bearing1_4 (H 9,33; V 10,5) y Bearing1_3 (H 9,24; V 6,75) tienen los valores finales de RMS más altos del conjunto, pero su kurtosis final es moderada (H 4,08 / 3,23). RMS alto y kurtosis alta no aparecen necesariamente juntos.
- **Transitorios que ocultan el nivel final:** Bearing3_1 es el ejemplo más claro (kurtosis H máximo ≈416, luego vuelve a ≈3,52 final). Bearing1_2 y Bearing1_6 tienen máximos de kurtosis muy grandes (≈195/≈319 y ≈126/≈222) que no se reflejan en el valor final.
- **Diferencia H/V notable:** Bearing2_3 (RMS final 7,26 H vs 1,27 V), Bearing2_5 (skewness H ≈-2,25 final, mínimo ≈-6,13) y Bearing2_7 (ventana corta 0,64 h, lectura poco estable).
- **Condición 3 es la muestra más pequeña y heterogénea:** 3 rodamientos, ventanas de 0,64 h a 7,78 h; no permite ordenar condiciones ni inferir severidad.

### 4.3 Síntesis por condición de operación

- **Condición 1** (7 rodamientos, 14.647 snapshots): incluye los dos RMS finales H más altos (Bearing1_4, Bearing1_3) y el aumento de Bearing1_1 hasta 5,61, pero también casos moderados (Bearing1_5, Bearing1_6). Kurtosis final de ≈3,2 a ≈19,6. RMS alto y kurtosis alta no coinciden necesariamente.
- **Condición 2** (7 rodamientos, 7.656 snapshots): el grupo más heterogéneo. Bearing2_5 es el caso extremo de kurtosis final (≈79,2 H / ≈80,2 V); Bearing2_2 termina con kurtosis V ≈46,8; Bearing2_3 muestra fuerte diferencia H/V; Bearing2_7 es muy corto (0,64 h).
- **Condición 3** (3 rodamientos, 2.586 snapshots): Bearing3_1 tiene picos transitorios extremos pero kurtosis final baja; Bearing3_3 tiene los máximos de kurtosis y crest factor más bajos del conjunto. Muestra demasiado pequeña para comparar severidad.

---

## 5. Limitaciones y restricciones metodológicas

1. **`Test_set` excluido:** no es una partición independiente de `Full_Test_Set`; no debe usarse como validación ni test. `Full_Test_Set` y `Test_set` comparten identidad.
2. **Sin etiquetas RUL:** `RUL_FEMTO.txt` no existe. Este EDA no define train/validation/test. Cualquier partición futura debe hacerse **por rodamiento, nunca por snapshot**, y documentar la restricción de fuga de información entre snapshots de un mismo rodamiento.
3. **Temperatura no analizada:** los ficheros `temp_*.csv` quedan fuera.
4. **Solo dominio temporal:** no hay análisis frecuencial, de órdenes, filtrado, normalización, eliminación de outliers ni cuantificación de incertidumbre.
5. **Último snapshot = observación puntual:** los máximos pueden ser transitorios y no representan un nivel estable.
6. **Sin interpretación causal:** se describe el comportamiento de las features, no se explica su origen.
7. **`monotonicFraction` cercano a 0,5** indica ausencia de degradación monotónica; no es indicador de salud.
8. **Unidad física no documentada:** el RMS se expresa en unidades originales del CSV; no se asume `g` ni conversión.

---

## 6. Conclusiones

1. El EDA/Uni está **completo y validado**: 24.889 snapshots, 17 rodamientos, 68 figuras, 136 filas de resumen, sin NaN/Inf, pruebas `TODO OK`.
2. La degradación de los rodamientos **no es monotónica**; cualquier modelo de RUL debe soportar comportamientos no lineales, transitorios y divergencia entre sensores/features.
3. La kurtosis puede ser un indicador más sensible que el RMS en etapas avanzadas (caso Bearing2_5), pero también genera picos transitorios que no representan el estado final.
4. Las condiciones de operación están **desbalanceadas** (7/7/3 rodamientos) y con ventanas muy distintas; no se pueden comparar directamente ni inferir severidad entre condiciones sin más evidencia.
5. El gate de salida de EDA/Uni está cumplido: al menos una figura por rodamiento/feature y observaciones escritas. La fase puede pasar a revisión del owner y, tras el merge, a EDA/Multi.

---

## 7. Siguientes pasos recomendados

### Inmediatos (cerrar la fase EDA/Uni)
1. **Revisión del owner de las 68 figuras** en `results/` antes del merge (requisito previo definido en el plan).
2. **Abrir el PR** `feat(eda-uni): análisis univariado de los 17 rodamientos` hacia `main` tras autorización explícita del usuario.
3. Tras el merge del owner, una persona crea el **tag `v0.1.eda-uni`**.
4. Corregir `Agentes/GIT_WORKFLOW.md` §8.4 (CODEOWNERS «puede activarse» → afirmar que está activo) en un PR pequeño separado.

### Fase siguiente: EDA/Multi (no iniciar hasta que el gate de EDA/Uni esté cerrado y mergeado)
5. **Correlaciones entre sensores (H/V) y entre features** dentro de cada rodamiento y entre condiciones.
6. **PCA / reducción de dimensión** sobre la tabla de features para identificar componentes principales de degradación.
7. **Construcción de un Health Index (HI)** candidato combinando features, validando su monotonía relativa (aunque las features individuales no sean monotónicas, el HI podría serlo).
8. **Interpretación sobre la degradación:** qué combinaciones de feature/sensor mejor separan estados iniciales vs finales.

### Fase siguiente: PreProcess (después de EDA/Multi)
9. **Tabla de features reproducible** y split train/validation/test **por rodamiento**, nunca por snapshot.
10. Ajuste de normalización/imputación/selección solo sobre train, aplicado a val/test.
11. Documentar explícitamente la restricción de fuga entre snapshots del mismo rodamiento.

### Fase siguiente: Modeling (después de PreProcess)
12. Línea base + modelo evaluado con el score PHM 2012 y tablas comparativas.

---

## 8. Artefactos y código asociado

| Artefacto | Contenido |
|-----------|-----------|
| `results/eda_uni_features.csv` | 24.889 filas; una por snapshot; H y V en columnas separadas; 13 columnas; precisión completa. |
| `results/eda_uni_summary.csv` | 136 filas; resumen por rodamiento × feature × sensor. |
| `results/eda_uni_<bearing>_<feature>_trend.png` | 68 figuras PNG (17 × 4), H/V superpuestos, 150 dpi. |
| `EDA/Uni/README.md` | Observaciones finales (este reporte se basa en él). |
| `+bearlytics/loadAccSnapshot.m` | Lectura con detección de `,`/`;` y validación 2560×6. |
| `+bearlytics/computeTimeFeatures.m` | RMS, kurtosis, crest y skewness. |
| `EDA/Uni/run_eda_uni.m` | Orquestador y parser de condición (`tokens{1}`). |
| `EDA/Uni/plotFeatureTrend.m` | Generación de las 68 figuras. |
| `EDA/Uni/test_eda_uni.m` | Pruebas TDD (`TODO OK`). |

**Comando de verificación:** `matlab -batch "run('EDA/Uni/test_eda_uni.m')"` → `TODO OK`.

---
*Reporte generado a partir de `EDA/Uni/README.md`, `results/eda_uni_features.csv` y `results/eda_uni_summary.csv`. Sin datos inventados; todas las cifras provienen de las ejecuciones verificadas.*
