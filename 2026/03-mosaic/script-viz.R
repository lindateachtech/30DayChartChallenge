# Día 03 - Mosaic
# #30DayChartChallenge
# Mosaico (Marimekko) del test de Bechdel por décadas

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(tidytuesdayR)

# Colores y tipografía ----------------------------------------------------
fondo <- "#F6F1E9"
texto <- "#24201C"
suave <- "#6E655C"

# De aprobar (abajo) a suspender por el motivo más grave (arriba)
categorias <- c(
  "3" = "Aprueba",
  "2" = "Solo hablan de un hombre",
  "1" = "No hablan entre ellas",
  "0" = "Menos de dos mujeres"
)
# Paul Tol sunset (khroma), divergente, apta para daltonismo
p <- rcartocolor::carto_pal(7, "TealRose")
colores <- c(
  "Aprueba" = p[1],
  "Solo hablan de un hombre" = p[5],
  "No hablan entre ellas" = p[6],
  "Menos de dos mujeres" = p[7]
)


# Tipografías de Google Fonts (licencia OFL) guardadas en la carpeta fuentes
systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("fuentes", "DMSerifDisplay-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("fuentes", "Lato-Regular.ttf"),
  bold = file.path("fuentes", "Lato-Bold.ttf")
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: bechdeltest.com vía TidyTuesday (2021-03-09)
peliculas <- tidytuesdayR::tt_load("2021-03-09")$raw_bechdel |>
  filter(year >= 1950, year <= 2019)

# Preparación -------------------------------------------------------------
decadas <- peliculas |>
  mutate(
    decada = floor(year / 10) * 10,
    categoria = factor(categorias[as.character(rating)], levels = categorias)
  ) |>
  count(decada, categoria) |>
  group_by(decada) |>
  mutate(total = sum(n), pct = n / total) |>
  ungroup()

# Columnas del mosaico: el ancho es el peso de cada década, con un pequeño hueco
columnas <- decadas |>
  distinct(decada, total) |>
  arrange(decada) |>
  mutate(
    ancho = total / sum(total),
    xmin = lag(cumsum(ancho), default = 0) + (row_number() - 1) * 0.01,
    xmax = xmin + ancho,
    xmed = (xmin + xmax) / 2,
    etiqueta = if_else(
      decada >= 2000,
      as.character(decada),
      as.character(decada %% 100)
    ),
    estrecha = ancho < 0.05 # columnas donde el porcentaje no cabe en horizontal
  )

# Rectángulos apilados de abajo (aprueba) a arriba
rects <- decadas |>
  left_join(columnas, by = c("decada", "total")) |>
  arrange(decada, categoria) |>
  group_by(decada) |>
  mutate(ymax = cumsum(pct), ymin = ymax - pct) |>
  ungroup()

# Formatos para las cifras
pct <- function(x) paste0(round(x * 100), "\u00a0%") # espacio que no se parte
miles <- function(x) format(x, big.mark = ".", decimal.mark = ",")

# Etiquetas de categoría a la derecha de la última columna
ultima <- rects |>
  filter(decada == max(decada)) |>
  mutate(ymed = (ymin + ymax) / 2)

# Textos ------------------------------------------------------------------
titulo <- "El test de Bechdel, década a década"
subtitulo <- glue(
  "Resultado del test en {miles(nrow(peliculas))} películas de 1950 a 2019."
)
nota <- glue(
  "El test pide al menos dos personajes femeninos con nombre que hablen entre ellos de algo que no sea un hombre. ",
  "Las películas las añaden y valoran los usuarios de bechdeltest.com, así que no son una muestra de todo el cine.<br>",
  "Datos bechdeltest.com vía TidyTuesday, {miles(nrow(peliculas))} películas de 1950 a 2019 · ",
  "#30DayChartChallenge Día 03 Mosaic · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot() +
  geom_rect(
    data = rects,
    aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = categoria),
    colour = fondo,
    linewidth = 0.6
  ) +
  # porcentaje que aprueba, dentro de la franja de abajo (en vertical si la columna es estrecha)
  geom_text(
    data = filter(rects, categoria == "Aprueba", !estrecha),
    aes((xmin + xmax) / 2, ymax - 0.035, label = pct(pct)),
    size = 4.2,
    fontface = "bold",
    colour = "white"
  ) +
  geom_text(
    data = filter(rects, categoria == "Aprueba", estrecha),
    aes((xmin + xmax) / 2, ymax - 0.015, label = pct(pct)),
    angle = 90,
    hjust = 1,
    size = 3.6,
    fontface = "bold",
    colour = "white"
  ) +
  # porcentaje con menos de dos mujeres, dentro de la franja de arriba
  geom_text(
    data = filter(rects, categoria == "Menos de dos mujeres", !estrecha),
    aes((xmin + xmax) / 2, (ymin + ymax) / 2, label = pct(pct)),
    size = 4.2,
    fontface = "bold",
    colour = "white"
  ) +
  geom_text(
    data = filter(rects, categoria == "Menos de dos mujeres", estrecha),
    aes((xmin + xmax) / 2, ymax - 0.012, label = pct(pct)),
    angle = 90,
    hjust = 1,
    size = 3.6,
    fontface = "bold",
    colour = "white"
  ) +
  # década y número de películas debajo
  geom_text(
    data = columnas,
    aes(xmed, -0.025, label = etiqueta),
    vjust = 1,
    size = 3.4,
    fontface = "bold",
    colour = texto
  ) +
  annotate(
    "text",
    x = 0,
    y = -0.025,
    label = "Años",
    hjust = 1.15,
    vjust = 1,
    size = 3.4,
    fontface = "bold",
    colour = texto
  ) +
  geom_text(
    data = columnas,
    aes(xmed, -0.065, label = miles(total)),
    vjust = 1,
    size = 3.1,
    colour = suave
  ) +
  annotate(
    "text",
    x = 0,
    y = -0.065,
    label = "Películas",
    hjust = 1.15,
    vjust = 1,
    size = 3.1,
    colour = suave
  ) +
  # nombres de las categorías a la derecha
  geom_text(
    data = ultima,
    aes(
      max(columnas$xmax) + 0.015,
      ymed,
      label = categoria,
      colour = categoria
    ),
    hjust = 0,
    size = 3.5,
    fontface = "bold"
  ) +
  scale_fill_manual(values = colores, guide = "none") +
  scale_colour_manual(values = colores, guide = "none") +
  coord_cartesian(
    xlim = c(-0.1, max(columnas$xmax) + 0.27),
    ylim = c(-0.1, 1),
    clip = "off",
    expand = FALSE
  ) +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_size = 13, base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 30, 20, 30),
    plot.title = element_textbox_simple(
      family = "Titulo",
      size = 28,
      colour = texto,
      lineheight = 1.2,
      margin = margin(b = 15)
    ),
    plot.subtitle = element_textbox_simple(
      size = 14,
      colour = suave,
      lineheight = 1.3,
      margin = margin(b = 25)
    ),
    plot.caption = element_textbox_simple(
      size = 10,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 25)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5
ggsave(
  "2026/03-mosaic/grafico.png",
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = fondo
)
