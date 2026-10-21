<!-- Descripción de la plantilla de Pull Request de Bearlytics -->

## Qué hace este PR

<!-- Fase: eda-uni | eda-multi | preprocess | modeling | fix | docs | chore -->

<!-- Una o dos frases: el entregable y por qué. -->

## Fase y gate

<!-- Marca la casilla del gate que aplica. -->

- [ ] `eda-uni` — figuras rotuladas por rodamiento, tabla de la feature con mejor early warning, sección en `EDA/Uni/README.md`
- [ ] `eda-multi` — figuras de correlación y PCA, veredicto de comparabilidad entre condiciones, sección en `EDA/Multi/README.md`
- [ ] `preprocess` — tabla de features reproducible, conteo por partición, split por rodamiento documentado, sección en `PreProcess/README.md`
- [ ] `modeling` — tabla comparativa de modelos, score PHM 2012 por rodamiento y agregado, figura de trayectorias, sección en `Modeling/README.md`
- [ ] otro (docs / chore / fix) — describir el criterio de aceptación

## Evidencia de ejecución

<!-- Pega aquí la salida real (matlab -batch / logs). Sin esto, el PR no puede revisarse. -->

```
```

## Resultados (solo PRs de `modeling`)

| Modelo | Score PHM 2012 | RMSE | MAE | Tiempo (s) |
|---|---|---|---|---|
| baseline (media RUL train) | | | | |
| baseline (RUL ~ HI) | | | | |

<!-- Si el PR no es de modeling, borra esta tabla. -->

## Cambios

<!-- Ficheros y carpetas tocados, y por qué. -->

- 

## Checklist

- [ ] La rama sigue la nomenclatura (`feature/<fase>-<tarea>`) y parte de `main` actualizado
- [ ] El PR toca solo la carpeta de su fase (+ `results/` y el README de la fase)
- [ ] El gate de la fase está cumplido y documentado
- [ ] Se incluye la evidencia de ejecución real
- [ ] `git status` limpio; sin dataset, `.mat` pesados ni ficheros del editor
- [ ] Split por rodamiento, sin fuga de información entre train/validation/test
- [ ] Sin rutas absolutas en el código
- [ ] Los cambios del dataset local no se han versionado
- [ ] El título sigue Conventional Commits (`feat(preprocess): ...`) — lo verifica la CI
- [ ] La CI está en verde

## Revisión

- Revisor(a):
- ¿Ejecutado con MATLAB R2026b?:
- ¿Aprobación de otra persona? (el autor no puede aprobar su propio PR)

> GitHub exige 1 revisión aprobadora de otra persona y la CI en verde para poder mergear. El merge a `main` lo hace el owner del repositorio.
