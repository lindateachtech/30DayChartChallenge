# Día 07 - Multiscale
# #30DayChartChallenge
# Mapa de calor de tiros a tres escalas: LaLiga, el Barcelona y Messi (2017/18)

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggsoccer)
library(patchwork)
library(ggtext)
library(glue)
library(ragg)

carpeta <- file.path("2026", "07-multiscale")

# Colores y tipografía ----------------------------------------------------
fondo <- "#F3F4F1"
texto <- "#1C2321"
suave <- "#5F6B66"
lineas <- "#AEB5AF"

systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/07-multiscale/fuentes", "Anton-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("2026/07-multiscale/fuentes", "SairaCondensed-Regular.ttf"),
  bold = file.path("2026/07-multiscale/fuentes", "SairaCondensed-SemiBold.ttf")
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: Pappalardo y Massucco (2019), Soccer match event dataset, figshare
# https://doi.org/10.6084/m9.figshare.c.4415000
ruta_tiros <- file.path(carpeta, "datos", "tiros_laliga_1718.csv")

if (!file.exists(ruta_tiros)) {
  dir.create(dirname(ruta_tiros), showWarnings = FALSE)
  options(timeout = 600)
  zip <- tempfile(fileext = ".zip")
  download.file(
    "https://ndownloader.figshare.com/files/14464685",
    zip,
    mode = "wb"
  )
  unzip(zip, files = "events_Spain.json", exdir = tempdir())
  eventos <- jsonlite::fromJSON(file.path(tempdir(), "events_Spain.json"))

  tiros_raw <- eventos |> filter(subEventName %in% c("Shot", "Free kick shot"))
  tiros_raw |>
    transmute(
      id,
      matchId,
      teamId,
      playerId,
      tipo = subEventName,
      x = map_dbl(positions, \(p) p$x[1]),
      y = map_dbl(positions, \(p) p$y[1]),
      gol = map_lgl(tags, \(t) 101 %in% t$id) # etiqueta 101 de Wyscout, gol
    ) |>
    write_csv(ruta_tiros)
}

tiros <- read_csv(ruta_tiros, show_col_types = FALSE)

# Preparación -------------------------------------------------------------
# Identificadores de Wyscout: Barcelona 676, Lionel Messi 3359
escalas <- bind_rows(
  tiros |> mutate(escala = "LaLiga"),
  tiros |> filter(teamId == 676) |> mutate(escala = "Barcelona"),
  tiros |> filter(playerId == 3359) |> mutate(escala = "Messi")
) |>
  mutate(escala = factor(escala, levels = c("LaLiga", "Barcelona", "Messi")))

# Fuera del área: el área grande de Wyscout va de x = 84 a 100 y de y = 19 a 81
resumen <- escalas |>
  group_by(escala) |>
  summarise(
    tiros = n(),
    goles = sum(gol),
    faltas = sum(tipo == "Free kick shot"),
    fuera = mean(!(x >= 84 & between(y, 19, 81)))
  )

# Celdas de 4 x 5 unidades de Wyscout (unos 4,2 x 3,4 metros)
celdas <- escalas |>
  mutate(xc = floor(x / 4) * 4 + 2, yc = floor(y / 5) * 5 + 2.5) |>
  count(escala, xc, yc) |>
  group_by(escala) |>
  mutate(pct = n / sum(n)) |>
  ungroup() |>
  filter(xc >= 56) # los pocos tiros desde más lejos no caben en el encuadre

max_pct <- max(celdas$pct)

# Formatos
pct <- function(x) paste0(round(100 * x), " %")
miles <- function(x) format(x, big.mark = ".", decimal.mark = ",", trim = TRUE)
dato <- function(e, v) resumen[[v]][resumen$escala == e]

# Iconos de los títulos ---------------------------------------------------
icono <- function(
  colores,
  anchos,
  archivo,
  sentido = "horizontal",
  texto_icono = NULL
) {
  lim <- c(0, cumsum(anchos) / sum(anchos)) * 2 - 1
  franjas <- tibble(
    desde = head(lim, -1),
    hasta = tail(lim, -1),
    color = colores
  )
  t <- seq(0, 2 * pi, length.out = 200)
  mascara <- bind_rows(
    tibble(
      x = c(-1.2, 1.2, 1.2, -1.2),
      y = c(-1.2, -1.2, 1.2, 1.2),
      parte = "marco"
    ),
    tibble(x = cos(t), y = sin(t), parte = "hueco")
  )
  p <- ggplot() +
    {
      if (sentido == "horizontal") {
        geom_rect(
          data = franjas,
          aes(xmin = -1, xmax = 1, ymin = desde, ymax = hasta, fill = color)
        )
      } else {
        geom_rect(
          data = franjas,
          aes(xmin = desde, xmax = hasta, ymin = -1, ymax = 1, fill = color)
        )
      }
    } +
    geom_polygon(
      data = mascara,
      aes(x, y, group = 1, subgroup = parte),
      fill = fondo
    ) +
    geom_path(
      data = tibble(x = cos(t), y = sin(t)),
      aes(x, y),
      colour = texto,
      linewidth = 1.2
    ) +
    scale_fill_identity() +
    coord_equal(xlim = c(-1.05, 1.05), ylim = c(-1.05, 1.05), expand = FALSE) +
    theme_void()
  if (!is.null(texto_icono)) {
    p <- p +
      annotate(
        "text",
        x = 0,
        y = -0.05,
        label = texto_icono,
        family = "Titulo",
        size = 13,
        colour = "#EDBB00"
      )
  }
  ggsave(
    archivo,
    p,
    device = agg_png,
    width = 1,
    height = 1,
    dpi = 200,
    bg = fondo
  )
  archivo
}

dir.create(file.path(carpeta, "iconos"), showWarnings = FALSE)
iconos <- c(
  "LaLiga" = icono(
    c("#AA151B", "#F1BF00", "#AA151B"),
    c(1, 2, 1),
    file.path(carpeta, "iconos", "espana.png")
  ),
  "Barcelona" = icono(
    rep(c("#004D98", "#A50044"), length.out = 5),
    rep(1, 5),
    file.path(carpeta, "iconos", "barcelona.png"),
    sentido = "vertical"
  ),
  "Messi" = icono(
    c("#004D98", "#A50044"),
    c(1, 1),
    file.path(carpeta, "iconos", "messi.png"),
    sentido = "vertical",
    texto_icono = "10"
  )
)

# Gráfico de una escala ---------------------------------------------------
campo <- function(e, titulo_panel, tam_titulo) {
  ggplot(filter(celdas, escala == e)) +
    annotate_pitch(
      dimensions = pitch_wyscout,
      colour = lineas,
      fill = fondo,
      limits = FALSE
    ) +
    geom_tile(aes(xc, yc, fill = pct), width = 4, height = 5, alpha = 0.95) +
    annotate_pitch(
      dimensions = pitch_wyscout,
      colour = lineas,
      fill = NA,
      limits = FALSE,
      alpha = 0.6
    ) +
    scale_fill_viridis_c(
      option = "mako",
      direction = -1,
      limits = c(0, max_pct),
      labels = \(x) paste0(round(100 * x), " %"),
      name = "Porcentaje de los tiros de cada escala",
      guide = guide_colourbar(title.position = "top")
    ) +
    coord_flip(xlim = c(55, 100), ylim = c(0, 100), expand = FALSE) +
    labs(title = titulo_panel) +
    theme_void(base_family = "Texto") +
    theme(
      aspect.ratio = (45 * 1.05) / (100 * 0.68), # medio campo en metros reales
      plot.title = element_textbox_simple(
        size = tam_titulo,
        colour = texto,
        lineheight = 1.2,
        margin = margin(b = 6)
      ),
      legend.position = "bottom"
    )
}

panel <- function(e) {
  glue(
    "<img src='{iconos[[e]]}' width='24'/>&emsp;",
    "<span style='font-family:Titulo; font-size:20pt'>{toupper(e)}</span><br>",
    "{miles(dato(e, 'tiros'))} tiros · {pct(dato(e, 'fuera'))} desde fuera del área · ",
    "{dato(e, 'goles')} goles"
  )
}

p_liga <- campo("LaLiga", panel("LaLiga"), 13)
p_barca <- campo("Barcelona", panel("Barcelona"), 11)
p_messi <- campo("Messi", panel("Messi"), 11)

# Textos ------------------------------------------------------------------
titulo <- "Messi frente a LaLiga"
subtitulo <- "Porcentaje de tiros por zona en LaLiga 2017/18, a escala de liga, equipo y jugador."
nota <- glue(
  "Tiros en jugada y faltas directas, sin penaltis. Cada equipo ataca hacia arriba.<br>",
  "Datos Wyscout vía Pappalardo y Massucco (2019), CC BY 4.0 · #30DayChartChallenge Día 07 Multiscale · Linda Cabrera Orellana"
)

# Composición -------------------------------------------------------------
grafico <- p_liga /
  (p_barca | p_messi) +
  plot_layout(heights = c(1.25, 1), guides = "collect") +
  plot_annotation(
    title = titulo,
    subtitle = subtitulo,
    caption = nota,
    theme = theme(
      plot.background = element_rect(fill = fondo, colour = NA),
      plot.margin = margin(28, 30, 18, 30),
      plot.title = element_text(
        family = "Titulo",
        size = 40,
        colour = texto,
        margin = margin(b = 16)
      ),
      plot.subtitle = element_textbox_simple(
        family = "Texto",
        size = 14,
        colour = suave,
        lineheight = 1.25,
        margin = margin(b = 16)
      ),
      plot.caption = element_textbox_simple(
        family = "Texto",
        size = 10,
        colour = suave,
        lineheight = 1.3,
        margin = margin(t = 12)
      )
    )
  ) &
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    legend.position = "bottom",
    legend.title = element_text(
      family = "Texto",
      size = 11,
      colour = suave,
      hjust = 0.5
    ),
    legend.text = element_text(family = "Texto", size = 10, colour = suave),
    legend.key.width = unit(2.4, "cm"),
    legend.key.height = unit(0.3, "cm")
  )

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5
ggsave(
  file.path(carpeta, "grafico.png"),
  grafico,
  device = agg_png,
  width = 8,
  height = 10,
  dpi = 135,
  bg = fondo
)
