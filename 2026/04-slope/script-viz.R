# Día 04 · Slope
# #30DayChartChallenge
# Gráfico de pendiente: jugadores de los juegos postapocalípticos y de zombis
# en Steam antes y durante el confinamiento por la covid-19

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext) # para leer las portadas necesita también el paquete jpeg instalado
library(glue)
library(ragg)
library(tidytuesdayR)

# Colores y tipografía ----------------------------------------------------
fondo <- "#14161C"
texto <- "#F1F2F4"
suave <- "#8E95A3"
linea <- "#2A2E38"

# Paul Tol vibrant (khroma), apta para daltonismo
vibrant <- khroma::colour("vibrant")(7)
colores <- c("Sube" = vibrant[[3]], "Baja" = vibrant[[4]])

# Tipografías de Google Fonts (licencia OFL) guardadas en la carpeta fuentes
systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = "2026/04-slope/fuentes/Rajdhani-Bold.ttf"
)
systemfonts::register_font(
  "Texto",
  plain = "2026/04-slope/fuentes/Lato-Regular.ttf",
  bold = "2026/04-slope/fuentes/Lato-Bold.ttf"
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: Steam Charts vía TidyTuesday (2021-03-16)
juegos <- tidytuesdayR::tt_load("2021-03-16")$games

# Candidatos y su identificador en la tienda de Steam, para descargar la portada
candidatos <- tribble(
  ~gamename            , ~appid ,
  "Unturned"           , 304930 ,
  "7 Days to Die"      , 251570 ,
  "DayZ"               , 221100 ,
  "Fallout 4"          , 377160 ,
  "Left 4 Dead 2"      ,    550 ,
  "Dying Light"        , 239140 ,
  "Kenshi"             , 233860 ,
  "SCUM"               , 513710 ,
  "They Are Billions"  , 644930 ,
  "Fallout: New Vegas" ,  22380 ,
  "The Long Dark"      , 305620 ,
  "Project Zomboid"    , 108600 ,
  "Fallout Shelter"    , 588430
)

# Preparación -------------------------------------------------------------
antes <- juegos |>
  filter(year == 2020, month == "January") |>
  select(gamename, antes = avg)
durante <- juegos |>
  filter(year == 2020, month == "April") |>
  select(gamename, durante = avg)

top <- antes |>
  inner_join(candidatos, by = "gamename") |>
  slice_max(antes, n = 10) |>
  left_join(durante, by = "gamename") |>
  mutate(
    cambio = durante / antes - 1,
    direccion = if_else(cambio >= 0, "Sube", "Baja")
  )

# Portadas ----------------------------------------------------------------
# Imagen de cabecera de la tienda (460 x 215 px). Se descarga una sola vez.
dir.create("2026/04-slope/portadas", showWarnings = FALSE)
top <- top |>
  mutate(portada = file.path("2026/04-slope/portadas", paste0(appid, ".jpg")))
top |> select(gamename, portada)

walk2(top$appid, top$portada, function(id, destino) {
  if (file.exists(destino)) {
    return(invisible())
  }
  urls <- c(
    glue("https://cdn.cloudflare.steamstatic.com/steam/apps/{id}/header.jpg"),
    glue(
      "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{id}/header.jpg"
    )
  )
  for (u in urls) {
    ok <- tryCatch(
      download.file(u, destino, mode = "wb", quiet = TRUE) == 0,
      error = function(e) FALSE
    )
    if (ok) break
  }
})

# Posición de las etiquetas -----------------------------------------------
# Se reparten en escala logarítmica con un hueco mínimo entre ellas para que no
# se monten, y cada etiqueta se une a su punto con un segmento.
repartir <- function(y, hueco) {
  orden <- order(y)
  v <- log10(y[orden])
  for (i in seq_along(v)[-1]) {
    v[i] <- max(v[i], v[i - 1] + hueco)
  }
  v <- v - (mean(v) - mean(log10(y[orden]))) # recentra el grupo
  for (i in rev(seq_along(v))[-1]) {
    v[i] <- min(v[i], v[i + 1] - hueco)
  }
  out <- numeric(length(y))
  out[orden] <- 10^v
  out
}

top <- top |>
  mutate(
    y_izq = repartir(antes, 0.036),
    y_der = repartir(durante, 0.088)
  )

# Formato largo para dibujar las líneas
pendientes <- top |>
  pivot_longer(
    c(antes, durante),
    names_to = "momento",
    values_to = "jugadores"
  ) |>
  mutate(x = if_else(momento == "antes", 1, 2))

# Formatos para las cifras
miles <- function(x) {
  format(round(x), big.mark = ".", decimal.mark = ",", trim = TRUE)
}
pct <- function(x) paste0(if_else(x >= 0, "+", "−"), round(abs(x) * 100), " %")

# Textos ------------------------------------------------------------------
titulo <- "El fin del mundo durante el confinamiento por la covid-19"
subtitulo <- glue(
  "Media mensual de jugadores simultáneos en Steam de los 10 juegos postapocalípticos y de zombis ",
  "más jugados en enero de 2020."
)
nota <- glue(
  "La escala vertical es logarítmica. ",
  "Datos Steam Charts vía TidyTuesday · Portadas de la tienda de Steam, propiedad de sus editoras · ",
  "#30DayChartChallenge Día 04 Slope · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot(
  pendientes,
  aes(x, jugadores, group = gamename, colour = direccion)
) +
  # ejes verticales de cada momento
  geom_vline(xintercept = c(1, 2), colour = linea, linewidth = 0.6) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.4) +
  # segmentos de cada punto a su etiqueta
  geom_segment(
    data = top,
    aes(x = 1, xend = 0.96, y = antes, yend = y_izq),
    inherit.aes = FALSE,
    colour = suave,
    alpha = 0.5,
    linewidth = 0.25
  ) +
  geom_segment(
    data = top,
    aes(x = 2, xend = 2.04, y = durante, yend = y_der),
    inherit.aes = FALSE,
    colour = suave,
    alpha = 0.5,
    linewidth = 0.25
  ) +
  # nombre y jugadores a la izquierda
  geom_text(
    data = top,
    aes(
      0.94,
      y_izq,
      label = glue("{gamename}  {miles(antes)}"),
      colour = direccion
    ),
    inherit.aes = FALSE,
    hjust = 1,
    size = 3.3
  ) +
  # portada, jugadores y cambio a la derecha
  geom_richtext(
    data = top,
    aes(2.06, y_der, label = glue("<img src='{portada}' width='54'/>")),
    inherit.aes = FALSE,
    hjust = 0,
    fill = NA,
    label.colour = NA,
    label.padding = unit(0, "pt"),
    label.margin = unit(0, "pt")
  ) +
  geom_text(
    data = top,
    aes(2.47, y_der, label = pct(cambio), colour = direccion),
    inherit.aes = FALSE,
    hjust = 0,
    size = 4.2,
    fontface = "bold"
  ) +
  annotate(
    "text",
    x = c(1, 2),
    y = max(pendientes$jugadores) * 1.35,
    label = c("Enero de 2020", "Abril de 2020"),
    colour = texto,
    size = 4.2,
    fontface = "bold"
  ) +
  scale_colour_manual(values = colores, guide = "none") +
  scale_y_log10() +
  scale_x_continuous(limits = c(0.1, 3.05)) +
  coord_cartesian(clip = "off") +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_size = 13, base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 30, 20, 30),
    plot.title = element_textbox_simple(
      family = "Titulo",
      size = 34,
      colour = texto,
      lineheight = 1.1,
      margin = margin(b = 12)
    ),
    plot.subtitle = element_textbox_simple(
      size = 14,
      colour = suave,
      lineheight = 1.3,
      margin = margin(b = 30)
    ),
    plot.caption = element_textbox_simple(
      size = 10,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 20)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5 que funciona bien en LinkedIn
ggsave(
  "2026/04-slope/grafico.png",
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = fondo
)
