
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


data = pd.read_csv('eda_uni_features.csv')


bearing = data[data['bearing'] == 'Bearing3_2']

if bearing.empty:
    raise ValueError("No se encontraron datos de Bearing1_2")


columnas = [
    'rmsH', 'rmsV',
    'kurtosisH', 'kurtosisV',
    'crestFactorH', 'crestFactorV',
    'skewnessH', 'skewnessV'
]

#matriz de correlacion
matriz = bearing[columnas].corr(method='spearman')

print(matriz.round(2))

# mapa de calor
plt.figure(figsize=(10, 8))

sns.heatmap(
    matriz,
    annot=True,       # Mostrar los coeficientes
    fmt='.2f',        # Mostrar dos decimales
    cmap='coolwarm',  # Azul: negativo; rojo: positivo
    vmin=-1,
    vmax=1,
    center=0,
    square=True
)

plt.title('Correlación de Spearman — Bearing3_2')
plt.tight_layout()
plt.show()