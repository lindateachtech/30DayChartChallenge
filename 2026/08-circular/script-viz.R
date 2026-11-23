# Día 08 - Circular
# #30DayChartChallenge
# Reloj radial de los avistamientos de ovnis en Estados Unidos por hora y mes

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(tidytuesdayR)
library(rcartocolor)

carpeta <- file.path("2026", "08-circular")

# Colores y tipografía ----------------------------------------------------
fondo <- "#1E2124"
texto <- "#E6E8EA"
suave <- "#8D949B"
rejilla <- "#3A3F44"

# Del gris del fondo a los verdes de CARTO Emrld (rcartocolor), secuencial y apta
# para daltonismo. Se quitan sus dos tonos más azules para que todo sea gris o verde.
verdes <- c("#2C3136", rev(rcartocolor::carto_pal(7, "Emrld"))[3:7])

systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/08-circular/fuentes", "Audiowide-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("2026/08-circular/fuentes", "ShareTech-Regular.ttf")
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: National UFO Reporting Center vía TidyTuesday (2019-06-25)
ovnis <- tidytuesdayR::tt_load("2019-06-25")$ufo_sightings

# Preparación -------------------------------------------------------------
meses <- c(
  "Ene",
  "Feb",
  "Mar",
  "Abr",
  "May",
  "Jun",
  "Jul",
  "Ago",
  "Sep",
  "Oct",
  "Nov",
  "Dic"
)
hueco <- 3 # anillos vacíos en el centro

eeuu <- ovnis |>
  filter(country == "us") |>
  mutate(
    fecha = lubridate::mdy_hm(date_time),
    hora = lubridate::hour(fecha),
    mes = lubridate::month(fecha)
  ) |>
  filter(!is.na(fecha), lubridate::year(fecha) >= 1995) # antes de 1995 hay muy pocos

celdas <- eeuu |>
  count(mes, hora) |>
  mutate(pct = n / sum(n), anillo = mes + hueco)

pico <- slice_max(celdas, pct, n = 1)

# Etiquetas de las horas alrededor del reloj y de los meses en un radio
horas <- tibble(hora = 0:23, label = paste0(0:23, " h"))
etiquetas_mes <- tibble(anillo = 1:12 + hueco, label = meses)

miles <- function(x) format(x, big.mark = ".", decimal.mark = ",", trim = TRUE)
pct <- function(x) {
  paste0(format(round(100 * x, 1), decimal.mark = ",", nsmall = 1), " %")
}

# Textos ------------------------------------------------------------------
titulo <- "A qué hora se ven los ovnis"
subtitulo <- glue(
  "Avistamientos de ovnis en Estados Unidos según la hora del día y el mes, {min(lubridate::year(eeuu$fecha))} a {max(lubridate::year(eeuu$fecha))}."
)
nota <- glue(
  "Cada vuelta son 24 horas y cada anillo un mes, de enero en el centro a diciembre fuera. {miles(nrow(eeuu))} avistamientos.<br>",
  "Datos NUFORC vía TidyTuesday · #30DayChartChallenge Día 08 Circular · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot(celdas) +
  geom_tile(aes(hora, anillo, fill = pct), colour = fondo, linewidth = 0.4) +
  # horas alrededor
  geom_text(
    data = horas,
    aes(hora, 12 + hueco + 1.25, label = label),
    size = 3.4,
    colour = suave
  ) +
  # meses en una cuña libre antes de medianoche
  geom_text(
    data = etiquetas_mes,
    aes(-1, anillo, label = label),
    size = 2.8,
    colour = texto,
    hjust = 0.5,
    alpha = 0.85
  ) +
  # celda máxima
  annotate(
    "point",
    x = pico$hora,
    y = pico$anillo,
    shape = 21,
    size = 6.5,
    colour = texto,
    stroke = 0.8
  ) +
  annotate(
    "text",
    x = pico$hora,
    y = pico$anillo + 2.6,
    label = glue("{meses[pico$mes]}, {pico$hora} h\n{pct(pico$pct)} del total"),
    size = 3.6,
    colour = texto,
    lineheight = 0.95
  ) +
  scale_fill_gradientn(
    colours = verdes,
    labels = pct,
    name = "Porcentaje de todos los avistamientos",
    guide = guide_colourbar(title.position = "top", title.hjust = 0.5)
  ) +
  scale_x_continuous(limits = c(-1.5, 23.5), expand = c(0, 0)) +
  scale_y_continuous(
    limits = c(0, 12 + hueco + 0.5),
    expand = c(0, 0),
    oob = scales::oob_keep
  ) + # las horas se dibujan fuera del círculo
  coord_polar(start = -2 * pi * 0.5 / 25, clip = "off") + # la cuña de los meses queda arriba
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 20, 20, 20),
    plot.title = element_text(
      family = "Titulo",
      size = 30,
      colour = texto,
      margin = margin(b = 10)
    ),
    plot.subtitle = element_text(
      size = 15,
      colour = suave,
      margin = margin(b = 4)
    ),
    plot.caption = element_textbox_simple(
      size = 10.5,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 6)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    legend.position = "bottom",
    legend.title = element_text(size = 12, colour = suave),
    legend.text = element_text(size = 11, colour = suave),
    legend.key.width = unit(2.6, "cm"),
    legend.key.height = unit(0.3, "cm")
  )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5
ggsave(
  file.path(carpeta, "grafico.png"),
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = fondo
)
