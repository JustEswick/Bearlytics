---
name: rul-features
description: Use when extracting features or building a Health Index for bearing RUL prediction in Bearlytics - time-domain statistics, frequency-domain and band energy, envelope analysis, wavelet packet decomposition, and how to combine them into a monotonic Health Index. Covers RMS, kurtosis, crest factor, envelope spectrum, WPD, HI.
license: MIT
metadata:
  project: Bearlytics
  domain: features
---

# Features para RUL de rodamientos (Bearlytics)

Catálogo de referencia para la fase `PreProcess`. Selecciona las features **guiado por el EDA**, no incluyendo todo sin criterio.

## Time domain (dominio del tiempo)

| Feature | Definición | MATLAB |
|---|---|---|
| Mean / Media | media de la señal | `mean(x)` |
| RMS | raíz de la media cuadrática | `rms(x)` |
| Std | desviación típica | `std(x)` |
| Peak-to-peak | `max - min` | `max(x) - min(x)` |
| Abs. max | valor absoluto máximo | `max(abs(x))` |
| Skewness | asimetría | `skewness(x)` (Statistics) o `mean(((x-mean(x))./std(x)).^3)` |
| Kurtosis | curtosis | `kurtosis(x)` (Statistics) o `mean(((x-mean(x))./std(x)).^4)` |
| Crest factor | pico / RMS | `max(abs(x)) / rms(x)` |
| Shape factor | RMS / media de \|x\| | `rms(x) / mean(abs(x))` |
| Impulse factor | pico / media de \|x\| | `max(abs(x)) / mean(abs(x))` |
| Clearance factor | pico / (media de \|x\|)^2 | `max(abs(x)) / mean(abs(x))^2` |
| Zero crossing rate | cruces por el cero | `sum(x(1:end-1).*x(2:end) < 0)` |

Regla práctica: RMS y crest factor detectan degradación incipiente; kurtosis y crest factor aumentan mucho justo antes del fallo; el pico absoluto es el más ruidoso (depende del montaje).

## Frequency domain

- **Espectro de amplitud** (`fft` + `abs`, normalizado por el número de muestras) y **PSD** (`pwelch`, Signal Processing).
- **Frecuencia de pico** dominante, **centroide espectral**, **bandwidth** y **energía por bandas** (p. ej. baja/media/alta frecuencia).
- Bandas útiles en rodamientos: banda de baja frecuencia (degradación incipiente), banda de resonancia, y alta frecuencia (modulación de la envolvente).

```matlab
X = fft(signal);
amp = abs(X(1:floor(numel(X)/2)+1)) / numel(X);
freq = (0:floor(numel(X)/2)) * fs / numel(X);
```

## Envelope analysis (muy útil en este dataset)

 demodulación de la señal, envolvente por transformada de Hilbert y espectro de la envolvente: revela los lados de banda y sus evoluciones (frecuencias características de fallo del rodamiento).

```matlab
env = abs(hilbert(signal));
envSpectrum = abs(fft(env));
```

En rodamientos de rodillos, las frecuencias de fallo son:
- **BPFO** (BPF): frecuencia de paso de la bola exterior.
- **BPFI** (FTF): paso de la bola interior.
- **BSF**: paso de la esfera.
- **FREF**: frecuencia de rotación (descrita por rpm).

## Wavelet packet decomposition (WPD)

Descomposición en paquetes de wavelet para extraer energía por bandas; útil para separar la banda de alta frecuencia donde vive la información de fallo.

```matlab
% Requiere Wavelet Toolbox
[~, tree] = wpdec(signal, 3, 'sym4');
% energia por paquete -> vector de features
```

Si no hay Wavelet Toolbox: implementa un banco de filtros propio (o usa `bandpower` sobre bandas de la PSD) y documenta la equivalencia.

## Construcción del Health Index (HI)

Objetivo: **un único indicador monótono** que correlacione con la degradación y sea comparable entre rodamientos y entre condiciones de operación.

Dos enfoques estándar:

1. **Media geométrica de features normalizadas** (simple, interpretable):

```matlab
% Normalizar cada feature con su valor al inicio de la degradación
z = (f - f0) ./ max(abs(f0), eps);
hi = prod(max(z, 0).^w, 1);   % w: pesos; el HI debe ser monótono
```

2. **Primera componente principal** del vector de features (captura la varianza dominante de la degradación):

```matlab
[~, score, ~] = pca(Ztrain, 'NumComponents', 1);
hi = score(:, 1);
```

Reglas:
- El HI debe ser **monótono creciente** en el tiempo dentro de cada rodamiento (con tolerancia; el ruido produce pequeñas violaciones).
- Aplica el mismo criterio de normalización a todos los rodamientos.
- Si el EDA muestra que las features tienen escalas distintas según la condición de operación, normaliza por condición antes de construir el HI.

## anti-leakage

- Toda normalización (por condición, por rodamiento, por feature) se calcula **con train** y se aplica al resto.
- Si el HI se construye con PCA, el PCA se ajusta **solo con train**; las componentes se proyectan sobre val/test.
- Documenta en `PreProcess/README.md` qué se ajustó con train y qué no.

## Referencias

- Randall & Antoni, "Rolling element bearing diagnostics—A tutorial" (2011).
- Antoni, "Cyclic spectral analysis of rolling-element bearing signals: Facts and fictions" (2009).
- Lee et al., "A Health Indicator for Bearing Prognostics" (2014) — construcción de HI multifeature.
- Ni et al., "A review of the Wiener–Hinshin..." no aplica; para WPD en rodamientos: Li et al., "Feature extraction for rotating machinery fault diagnosis..." (2016).
