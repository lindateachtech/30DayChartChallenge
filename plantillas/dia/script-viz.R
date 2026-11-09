# Día {{DIA}} · {{TEMA}}
# #30DayChartChallenge

# Paquetes ----------------------------------------------------------------
library(tidyverse)

# Datos -------------------------------------------------------------------
# Fuente:
datos <- read_csv("")

# Preparación -------------------------------------------------------------


# Gráfico -----------------------------------------------------------------
grafico <- ggplot(datos) +
  labs(
    title = "",
    subtitle = "",
    caption = "Datos: ... · #30DayChartChallenge Día {{DIA}} · Linda Cabrera Orellana"
  )

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5 que funciona bien en LinkedIn
ggsave(
  file.path("{{CARPETA}}", "grafico.png"),
  grafico, width = 8, height = 10, dpi = 135, bg = "white"
)
