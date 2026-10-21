---
description: Ejecuta la fase EDA (univariado y multivariado) del proyecto Bearlytics sobre el dataset FEMTO/PRONOSTIA.
agent: bearlytics-lead
---

Fase **EDA** de Bearlytics. Objetivo: entender cómo evoluciona la degradación de los rodamientos antes de construir features y modelos.

Alcance de esta petición: $ARGUMENTS

## Pasos

1. **Estado previo**: comprueba qué hay en `EDA/Uni/`, `EDA/Multi/` y `results/`, y qué partición del dataset está disponible localmente. Si el dataset no está descargado, dilo y para: no se puede hacer EDA sin datos.
2. **Inspección del layout**: documenta la estructura real de los ficheros (rodamientos, snapshots, sensores) antes de analizarlos.
3. **Univariado** (`EDA/Uni/`): evolución temporal de RMS, kurtosis, crest factor, skewness y peak-to-peak por rodamiento y sensor; delimitación de la zona degradada; espectros de inicio/medio/final; detección de artefactos.
4. **Multivariado** (`EDA/Multi/`): matriz de correlación de features, correlación entre sensores horizontal/vertical, PCA (varianza explicada y loadings), comparación entre las 3 condiciones de operación y ranking de candidatas a Health Index.
5. **Documentación**: cada análisis deja una sección en el `README.md` de su carpeta con figuras, números e interpretación.

## Gate de salida

- Una figura por rodamiento con features clave rotuladas (título, ejes con unidades, leyenda).
- Una tabla de la feature de mejor comportamiento indicador por rodamiento.
- Sección escrita en `EDA/Uni/README.md` y `EDA/Multi/README.md` con los hallazgos.
- Números citados que salgan de la ejecución real (`matlab -batch`), no de suposiciones.

## Entrega

Informa de: ficheros creados, figuras generadas (rutas), hallazgos principales con cifras, y qué queda abierto para `PreProcess`.
