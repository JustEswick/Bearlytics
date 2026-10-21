# Agentes de IA de Bearlytics

Configuración de agentes para que todo el equipo trabaje con la misma lógica. Vive **en el repositorio**: cualquier colaborador que lo clone la obtiene automáticamente.

## Qué hay aquí

```
Bearlytics/
├── AGENTS.md              # reglas del proyecto (cargadas automáticamente)
├── opencode.json          # config de proyecto: permisos, agente por defecto
├── .opencode/
│   ├── agent/             # 5 agentes
│   ├── command/           # 4 comandos /flujos
│   └── skill/             # 4 skills de dominio
├── Agentes/
│   ├── README.md          # este documento
│   └── WORKFLOWS.md       # flujo end-to-end, handoffs y gates
└── CLAUDE.md              # puente para Claude Code / Cursor
```

## Los agentes

| Agente | Tipo | Rol | Escribe en |
|--------|------|-----|-------------|
| `bearlytics-lead` | primary | Orquestador: sitúa la fase, valida el gate, delega y verifica | todo el repo (menos el dataset) |
| `eda-analyst` | subagent | EDA univariado y multivariado de las señales | `EDA/**`, `results/**` |
| `feature-engineer` | subagent | PreProcess: features, Health Index, tabla y splits | `PreProcess/**`, `results/**` |
| `rul-modeler` | subagent | Modeling: baselines, modelos de RUL y evaluación PHM | `Modeling/**`, `results/**` |
| `matlab-reviewer` | subagent | Revisión de código MATLAB (no edita, informa) | nada |

### Cómo invocarlos

En opencode, con mención directa:

```
@eda-analyst ¿cuándo empieza la degradación en Bearing1_1?
@feature-engineer construye la tabla de features del split de training
@rul-modeler entrena el baseline lineal sobre el HI y evalúa con el score PHM
@matlab-reviewer revisa PreProcess/build_dataset.m
```

O deja que `bearlytics-lead` los invoque por ti cuando la tarea lo requiera.

## Los comandos (flujos listos)

| Comando | Qué hace |
|---------|----------|
| `/eda` | Fase EDA completa (univariado + multivariado) con su gate |
| `/preprocess` | Fase PreProcess: features, HI, ground truth y splits |
| `/model` | Fase Modeling: baseline + modelos + evaluación PHM 2012 |
| `/score` | Evalúa un modelo existente y genera el informe de resultados |

## Las skills (conocimiento de dominio)

Se cargan bajo demanda cuando la tarea lo necesita:

| Skill | Contenido |
|-------|-----------|
| `femto-dataset` | Estructura del dataset FEMTO/PRONOSTIA, condiciones, muestreo, lectura de CSV, cálculo del RUL real |
| `matlab-conventions` | Estilo de código del repo, toolbox, ejecución con `matlab -batch`, checklist de calidad |
| `rul-features` | Catálogo de features (time/frequency/envelope/WPD) y construcción del Health Index |
| `phm-scoring` | Función de score asimétrico del IEEE PHM 2012, RMSE/MAE y protocolo de evaluación |

## Permisos: aislamiento por fase

Cada agente solo puede escribir en la carpeta de su fase. Además:

- `10. FEMTO Bearing/**` es **deny** de escritura para todos: el dataset es solo lectura.
- Los `.mat` pesados no se editan ni se versionan.
- `git commit` requiere confirmación, `git push` está bloqueado: los commits y pushes los decide una persona.

Esto evita que un agente "arregle" datos o que un modelo se contamine con información de validation/test.

## Qué necesitan los colaboradores

1. **Clonar el repo** (la configuración viene dentro).
2. **Tener MATLAB R2026b** instalado y la extensión oficial "MATLAB" de MathWorks en VS Code.
3. **Descargar el dataset** por su cuenta en `10. FEMTO Bearing/` (ver `README.md` raíz): no se versiona por tamaño.
4. **Reiniciar opencode** tras el pull: la configuración se carga al arrancar, no en caliente.

> Si usas Claude Code o Cursor, `CLAUDE.md` hace de puente hacia las mismas reglas.

## Mantenimiento de esta configuración

- Los agentes, comandos y skills son ficheros markdown: se editan, revisan y versionan como código.
- Al cambiar un agente, revisa que su `description` siga siendo inequívoca: es lo que el modelo lee para decidir a quién delegar.
- Mantén `AGENTS.md` corto y accionable: se inyecta en **cada** sesión, así que cada línea debe ganar su lugar.
