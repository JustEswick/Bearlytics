# PreProcess

Extracción de features, normalización, ventaneo y construcción del dataset de modelado a partir de los CSV del FEMTO dataset.

## Layout real verificado (2026-10-28)

| Partición | Rodamientos | `acc_*.csv` | `temp_*.csv` | CSV totales | Tipo |
|---|---:|---:|---:|---:|---|
| `Learning_set/` | 6 | 7.534 | 850 | 8.384 | Trayectorias completas hasta el fallo |
| `Full_Test_Set/` | 11 | 17.355 | 2.168 | 19.523 | Trayectorias completas hasta el fallo |
| `Test_set/` | 11 | 13.959 | 1.726 | 15.685 | Prefijo truncado de `Full_Test_Set` |

- Cada snapshot de aceleración es un `acc_*.csv` (`acc_00001.csv`, `acc_00002.csv`, ...).
- Cada `acc_*.csv` tiene 2.560 filas × 6 columnas, sin cabecera: 4 de marca temporal + 2 señales de aceleración (columnas 5 y 6). Muestreo a 25,6 kHz (0,1 s por snapshot).
- Los snapshots se registran cada 10 s.
- Algunos rodamientos incluyen `temp_*.csv` (4 columnas de marca temporal + temperatura; normalmente 600 filas, algunos más cortos); no son snapshots y no entran en el cálculo de RUL.
- No fijes el delimitador: hay ficheros con `,` y con `;`; `readtable` lo detecta.
- No hay `RUL_FEMTO.txt` en ninguna partición.
- `Test_set` no es independiente de `Full_Test_Set`: comparte los mismos 11 rodamientos y es un prefijo truncado de sus trayectorias.
- Para el RUL, `N` es el número de `acc_*.csv` del rodamiento en la partición usada, no el total de CSV.

### Consecuencia para el split

`Full_Test_Set` y `Test_set` no pueden usarse como validation y test independientes. La validación debe salir de rodamientos no usados en test y ningún rodamiento puede cruzar particiones. Antes de implementar el split hay que decidir qué rodamientos van a train/validation y si el test final se evalúa sobre `Full_Test_Set` (con RUL calculable) o sobre `Test_set` (sin etiqueta oficial), dejando constancia en este README.
