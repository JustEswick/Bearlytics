
import pandas as pd
import matplotlib.pyplot as plt


data = pd.read_csv('eda_uni_features.csv')

# Seleccionar y ordenar un rodamiento
bearing = data[
    data['bearing'] == 'Bearing3_2'
].sort_values('snapshotIndex')

comparaciones = [
    
    
    ('kurtosisH', 'crestFactorH',
     'Kurtosis H', 'Crest factor H'),

    ('rmsH', 'kurtosisH',
     'RMS H — unidades originales', 'Kurtosis H')
]

for x, y, etiqueta_x, etiqueta_y in comparaciones:
    fig, ax = plt.subplots(figsize=(8, 5))

    puntos = ax.scatter(
        bearing[x],
        bearing[y],
        c=bearing['elapsedHours'],
        cmap='viridis',
        s=12,
        alpha=0.6
    )

    fig.colorbar(
        puntos,
        ax=ax,
        label='Tiempo transcurrido (h)'
    )

    ax.set_xlabel(etiqueta_x)
    ax.set_ylabel(etiqueta_y)
    ax.set_title(f'Bearing3_2: {etiqueta_x} frente a {etiqueta_y}')
    ax.grid(alpha=0.25)

    fig.tight_layout()
    plt.show()