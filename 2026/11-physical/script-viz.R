# Día 11 - Physical
# #30DayChartChallenge
# Dot plot de Wilkinson de la altura de los 151 Pokémon de Kanto, a escala con Mayita y una palmera

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggforce)
library(ggtext)
library(glue)
library(ragg)
library(tidytuesdayR)
library(ggimage)

carpeta <- file.path("2026", "11-physical")

# Colores y tipografía ----------------------------------------------------
# Paul Tol vibrant (khroma), apta para daltonismo: naranja frente al azul del cielo y el mar
referencia <- khroma::colour("vibrant")(7)[1]
tinta <- "#123049"
punto <- "#FFFFFF"
cinta <- "#F4C542"

systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path(
    carpeta,
    "fuentes",
    "LilitaOne-Regular.ttf"
  )
)
systemfonts::register_font(
  "Texto",
  plain = file.path(
    carpeta,
    "fuentes",
    "VarelaRound-Regular.ttf"
  )
)

# Datos -------------------------------------------------------------------
# Fuente: paquete pokemon vía TidyTuesday (2025-04-01)
pokemon <- tidytuesdayR::tt_load("2025-04-01")$pokemon_df

# Pokémon conocidos que sirven de referencia dentro de las pilas, separados al menos 0,2 m
conocidos <- c(
  "pikachu",
  "charmander",
  "psyduck",
  "ivysaur",
  "slowpoke",
  "gengar",
  "charizard",
  "snorlax",
  "lapras"
)

kanto <- pokemon |>
  filter(generation_id == 1) |>
  mutate(nombre = str_to_title(pokemon), conocido = pokemon %in% conocidos)

stopifnot(nrow(kanto) == 151, sum(kanto$conocido) == length(conocidos))

# Cada pila es una altura (precisión de 0,1 m); los conocidos van al final de su pila
inicio_pilas <- 1.1
puntos <- kanto |>
  arrange(height, conocido, species_id) |>
  group_by(height) |>
  mutate(x = inicio_pilas + 0.1 * (row_number() - 1)) |>
  ungroup()

x_etiquetas <- max(puntos$x) + 0.25
etiquetas <- puntos |> filter(conocido)

# Columna libre entre la regla y las pilas para las imágenes de los gigantes y de Diglett
imagenes <- puntos |>
  filter(height > 2.5 | height == min(height)) |>
  transmute(pokemon, x = inicio_pilas / 2, y = height)

gigantes <- puntos |> filter(height > 2.5)
bajo_2m <- sum(kanto$height <= 2)
metros <- function(h) format(h, decimal.mark = ",", nsmall = 1)

# Fondo a escala ----------------------------------------------------------
# La palmera va de la fila 1200 (base) a la 250 (copa): esos 950 px son 9 m
fondo <- png::readPNG(file.path(carpeta, "img/fondo.png"))
m_px <- 9 / (1200 - 250)
x0_px <- 200 # columna de la imagen donde está x = 0
img <- c(
  xmin = -x0_px * m_px,
  xmax = (ncol(fondo) - x0_px) * m_px,
  ymin = -(nrow(fondo) - 1200) * m_px,
  ymax = 1200 * m_px
)

# Lienzo 4:5 recortando el cielo de la izquierda
alto <- img[["ymax"]] - img[["ymin"]]
lim_x <- c(img[["xmax"]] - alto * 0.8, img[["xmax"]])
lim_y <- c(img[["ymin"]], img[["ymax"]])

# Mayita, mi chihuahua, mide 25 cm: a escala real y ampliada en una lupa
mayita <- png::readPNG(file.path(carpeta, "img/mayita.png"))
alto_mayita <- 0.25
ancho_mayita <- alto_mayita * ncol(mayita) / nrow(mayita)
x_mayita <- 5.85
lupa <- c(x = x_mayita, y = 1.6, r = 0.75)
alto_lupa <- 1.3
ancho_lupa <- alto_lupa * ncol(mayita) / nrow(mayita)

# Cinta métrica a la izquierda
marcas <- tibble(y = round(seq(0, 9, 0.1), 1)) |>
  mutate(
    largo = case_when(
      y %% 1 == 0 ~ 0.22,
      round(y %% 0.5, 1) == 0 ~ 0.14,
      .default = 0.07
    )
  )

# Textos ------------------------------------------------------------------
titulo <- "La altura de Mayita y los Pokémon"
subtitulo <- "Los 151 Pokémon de la primera generación apilados según su altura en metros."
nota <- "Datos pokemon vía TidyTuesday · #30DayChartChallenge Día 11 Physical · Linda Cabrera Orellana"

# Gráfico -----------------------------------------------------------------
grafico <- ggplot() +
  annotation_raster(
    fondo,
    xmin = img[["xmin"]],
    xmax = img[["xmax"]],
    ymin = img[["ymin"]],
    ymax = img[["ymax"]]
  ) +
  # títulos sobre el cielo
  annotate(
    "text",
    x = lim_x[1] + 1.35,
    y = lim_y[2] - 0.62,
    label = titulo,
    family = "Titulo",
    size = 9.4,
    colour = tinta,
    hjust = 0,
    vjust = 1
  ) +
  annotate(
    "text",
    x = lim_x[1] + 1.35,
    y = lim_y[2] - 1.3,
    label = subtitulo,
    family = "Texto",
    size = 4.3,
    colour = tinta,
    hjust = 0,
    vjust = 1
  ) +
  # líneas de metro
  annotate(
    "segment",
    x = -0.2,
    xend = 4.3,
    y = 1:9,
    yend = 1:9,
    colour = "white",
    alpha = 0.45,
    linewidth = 0.5
  ) +
  # cinta métrica
  annotate(
    "rect",
    xmin = -0.62,
    xmax = -0.2,
    ymin = 0,
    ymax = 9.05,
    fill = cinta,
    colour = tinta,
    linewidth = 0.4
  ) +
  geom_segment(
    data = marcas,
    aes(x = -0.2 - largo, xend = -0.2, y = y, yend = y),
    colour = tinta,
    linewidth = 0.35
  ) +
  annotate(
    "text",
    x = -0.5,
    y = 1:9,
    label = 1:9,
    family = "Titulo",
    size = 4.6,
    colour = tinta,
    vjust = -0.25
  ) +
  # Mayita a escala y en la lupa
  annotation_raster(
    mayita,
    xmin = x_mayita - ancho_mayita / 2,
    xmax = x_mayita + ancho_mayita / 2,
    ymin = 0,
    ymax = alto_mayita
  ) +
  annotate(
    "segment",
    x = x_mayita + c(-1, 1) * ancho_mayita / 2,
    xend = lupa[["x"]] + c(-1, 1) * lupa[["r"]],
    y = alto_mayita,
    yend = lupa[["y"]],
    colour = tinta,
    linetype = "22",
    linewidth = 0.4
  ) +
  geom_circle(
    aes(x0 = lupa[["x"]], y0 = lupa[["y"]], r = lupa[["r"]]),
    fill = alpha("white", 0.7),
    colour = tinta,
    size = 0.8
  ) +
  annotation_raster(
    mayita,
    xmin = lupa[["x"]] - ancho_lupa / 2,
    xmax = lupa[["x"]] + ancho_lupa / 2,
    ymin = lupa[["y"]] - alto_lupa / 2,
    ymax = lupa[["y"]] + alto_lupa / 2
  ) +
  annotate(
    "label",
    x = lupa[["x"]],
    y = lupa[["y"]] + lupa[["r"]] + 0.08,
    label = "Mayita, 25 cm,\nsolo supera a Diglett",
    lineheight = 0.95,
    family = "Texto",
    size = 4,
    colour = tinta,
    fill = alpha("white", 0.75),
    label.size = 0,
    vjust = 0
  ) +
  # palmera
  annotate(
    "text",
    x = 7.2,
    y = 9.25,
    label = "Una palmera canaria de 9 m",
    family = "Texto",
    size = 4.4,
    colour = tinta,
    vjust = 0
  ) +
  # puntos
  geom_circle(
    data = puntos,
    aes(x0 = x, y0 = height, r = 0.047, fill = conocido),
    colour = tinta,
    size = 0.12
  ) +
  scale_fill_manual(
    values = c(`TRUE` = referencia, `FALSE` = punto),
    guide = "none"
  ) +
  # nombres de los conocidos, en columna a la derecha de las pilas
  geom_segment(
    data = etiquetas,
    aes(x = x + 0.07, xend = x_etiquetas - 0.05, y = height, yend = height),
    colour = tinta,
    linewidth = 0.3,
    linetype = "22"
  ) +
  geom_label(
    data = etiquetas,
    aes(x_etiquetas, height, label = glue("{nombre} {metros(height)} m")),
    family = "Texto",
    size = 3.7,
    colour = tinta,
    hjust = 0,
    fill = alpha("white", 0.75),
    label.size = 0,
    label.padding = unit(0.12, "lines")
  ) +
  geom_pokemon(
    data = imagenes,
    aes(x = x, y = y, image = pokemon),
    size = 0.04
  ) +
  # gigantes y anotaciones
  geom_text(
    data = gigantes,
    aes(x + 0.13, height, label = glue("{nombre} {metros(height)} m")),
    family = "Texto",
    size = 4.6,
    colour = tinta,
    hjust = 0
  ) +
  annotate(
    "label",
    x = inicio_pilas,
    y = 3.05,
    hjust = 0,
    family = "Texto",
    size = 4,
    colour = tinta,
    label = glue("{bajo_2m} de los 151 miden 2 m o menos"),
    fill = alpha("white", 0.75),
    label.size = 0
  ) +
  # nota sobre la arena
  geom_textbox(
    aes(x = lim_x[1] + 0.45, y = lim_y[1] + 0.12, label = nota),
    family = "Texto",
    size = 3.4,
    colour = tinta,
    hjust = 0,
    vjust = 0,
    halign = 0,
    width = unit(0.9, "npc"),
    fill = NA,
    box.colour = NA,
    lineheight = 1.3
  ) +
  coord_fixed(xlim = lim_x, ylim = lim_y, expand = FALSE) +
  theme_void() +
  theme(plot.margin = margin(0, 0, 0, 0))

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5
ggsave(
  file.path(carpeta, "grafico.png"),
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135
)
