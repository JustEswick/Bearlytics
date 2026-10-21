---
description: Ejecuta la fase PreProcess de Bearlytics: extrae features de vibración del dataset FEMTO/PRONOSTIA, construye el Health Index y arma las particiones train/validation/test por rodamiento.
agent: bearlytics-lead
---

Fase **PreProcess** de Bearlytics. Objetivo: convertir las señales crudas del dataset FEMTO/PRONOSTIA en una tabla de features lista para modelar RUL.

Alcance de esta petición: $ARGUMENTS

## Pasos

1. **Gate previo**: confirma que el EDA está hecho y documentado. Si no lo está, indícalo y ofrece volver a `/eda` primero.
2. **Ingesta**: recorre la partición activa, snapshot a snapshot, leyendo con `readtable` sin cargar todo en memoria. Cachea intermedios en `results/` si hace falta.
3. **Features** (ver skill `rul-features`): time domain, frequency domain, envelope analysis y energía por bandas; WPD si hay Wavelet Toolbox.
4. **Health Index**: HI por rodamiento (media geométrica de features normalizadas o primera componente principal), monótono y comparable entre rodamientos.
5. **Ground truth**: `RUL = (N_snapshots_total - i) * 10 s` para rodamientos con fallo completo; para el test truncado, usa la etiqueta oficial si existe y documenta si no.
6. **Tabla de modelado**: una fila por (rodamiento, snapshot, sensor) con id, condición, snapshot, features, HI y RUL. Exporta a `results/` (`.csv` versionable, `.mat` ignorado por git).
7. **Split**: train / validation / test **por rodamiento**, con la lista de rodamientos de cada partición documentada. Todo ajuste (normalización, imputación, selección) se hace solo con train.

## Gate de salida

- Script de entrada reproducible (p. ej. `PreProcess/build_dataset.m`) ejecutable con `matlab -batch`.
- Tabla final sin NaN/Inf, con conteo de rodamientos, snapshots y filas por partición.
- Confirmación explícita de que no hay leakage (ajuste en train, aplicación posterior).
- Sección en `PreProcess/README.md` con el esquema de la tabla y las decisiones tomadas.

## Entrega

Informa de: ficheros creados, dimensiones de la tabla resultante, particiones resultantes, y qué espera `Modeling` como entrada.
