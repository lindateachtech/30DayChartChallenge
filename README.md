# 30DayChartChallenge

Mis gráficos para el [#30DayChartChallenge](https://github.com/30DayChartChallenge), trato de representar gráficos editoriales hechos en R, pensados como los de una portada o un medio de comunicación, con un mensaje claro y anotaciones que guían la lectura.


## Estructura

```
30DayChartChallenge/
├── 2026/      temas de la edición 2026 asistidos con IA
└── R/         funciones comunes
```

Cada día tiene su propia carpeta, por ejemplo `2026/01-part-to-whole/`, con:

- un `README.md` que explica la pregunta, los datos, el gráfico y cómo leerlo, 
- el `script.R` para reproducirlo, 
- un `prompts.md` con el proceso de trabajo con IA y 
- la imagen final.


## Cómo trabajo

Construyo los gráficos con ayuda de IA y lo cuento abiertamente. La IA me acelera el código, pero la pregunta, la elección del gráfico, la historia, las anotaciones y la revisión de datos y estadística son decisiones mías. En cada `prompts.md` dejo los prompts principales, lo que tuve que corregir y lo que aprendí. El código es la parte reproducible, porque los prompts no dan siempre el mismo resultado.

## Reproducir un gráfico

Abre el proyecto de RStudio y ejecuta el `script.R` del día. Los paquetes necesarios aparecen al principio de cada script. Para empezar un día nuevo

```r
source("R/nuevo_dia.R")
nuevo_dia(1, "Part-to-Whole")
```


## Datos

Datos públicos con fuentes citadas, las principales son [Rdatasets](https://vincentarelbundock.github.io/Rdatasets/), [TidyTuesday](https://github.com/rfordatascience/tidytuesday) y el [dataset de eventos de Wyscout](https://github.com/koenvo/wyscout-soccer-match-event-dataset), además de los conjuntos que propone el propio reto.

