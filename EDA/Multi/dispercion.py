

import pandas as pd
import matplotlib.pyplot as plt


data = pd.read_csv('eda_uni_features.csv')


bearing = data[
    data['bearing'] == 'Bearing3_2'
].sort_values('snapshotIndex')

if bearing.empty:
    raise ValueError("No se encontraron datos de Bearing3_2")

fig, ax = plt.subplots(figsize=(8, 5))

puntos = ax.scatter(
    bearing['rmsH'],
    bearing['rmsV'],
    c=bearing['elapsedHours'],
    cmap='viridis',
    s=12,
    alpha=0.6
)

fig.colorbar(puntos, ax=ax, label='Tiempo transcurrido (h)')

ax.set_xlabel('RMS horizontal — unidades originales')
ax.set_ylabel('RMS vertical — unidades originales')
ax.set_title('Bearing3_2: RMS horizontal frente a vertical')
ax.grid(alpha=0.25)

fig.tight_layout()
plt.show()