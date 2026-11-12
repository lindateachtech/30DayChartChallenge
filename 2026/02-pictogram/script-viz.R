# Día 02 - Pictogram
# #30DayChartChallenge
# Los botes salvavidas del Titanic como columnas de personas sobre el mar,
# colocadas en la hora en que se arriaron
#

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(vcd)

# Colores y tipografía ----------------------------------------------------
cielo <- "#0E1A2B"
mar <- "#13304D"
texto <- "#F2F4F7"
suave <- "#9AA8BA"
vacio <- "#2A3C55"
colores <- c(
  "Tripulación" = "#88CCEE",
  "Hombres" = "#44AA99",
  "Mujeres" = "#E7A3B6"
)

# Tipografías de Google Fonts (licencia OFL), guardadas en la carpeta fuentes del
# proyecto y registradas aquí para que funcionen en cualquier ordenador con ragg
systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/02-pictogram/fuentes", "OldStandard-Bold.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("2026/02-pictogram/fuentes", "Lato-Regular.ttf"),
  bold = file.path("2026/02-pictogram/fuentes", "Lato-Bold.ttf")
)
fuente_titulo <- "Titulo"
fuente_texto <- "Texto"

# Todos los textos de las capas usan la fuente del texto
update_geom_defaults("text", list(family = fuente_texto))

# Datos -------------------------------------------------------------------
# Fuente: Mersey (1912), Report on the loss of the Titanic

vcd::Lifeboats

# Preparación -------------------------------------------------------------
# Eje x en minutos desde la medianoche. Cada columna tiene dos personas de ancho

botes <- Lifeboats |>
  mutate(
    momento = as.POSIXct(launch, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    minuto = as.numeric(format(momento, "%H")) *
      60 +
      as.numeric(format(momento, "%M"))
  ) |>
  arrange(momento, boat) |>
  group_by(minuto) |>
  mutate(x = minuto + (row_number() - (n() + 1) / 2) * 2.2) |>
  ungroup()


# VALIDACIÓN 1: Integridad de los datos
stopifnot(
  nrow(botes) == 18,
  !anyDuplicated(botes$boat),
  !anyNA(botes[, c("cap", "total", "crew", "men", "women", "minuto")]),
  all(botes$cap %in% c(40, 47, 65)),
  all(botes$total == botes$crew + botes$men + botes$women),
  sum(botes$total) == 854
)


# Separación vertical entre filas de personas
paso <- 1.25

# Una fila por plaza, apiladas de abajo arriba en filas de dos:
# tripulación, hombres, mujeres y vacías
plazas <- botes |>
  rowwise() |>
  mutate(
    ocupante = list(c(
      rep("Tripulación", crew),
      rep("Hombres", men),
      rep("Mujeres", women),
      rep("Vacía", max(cap - total, 0))
    ))
  ) |>
  ungroup() |>
  select(boat, x, cap, ocupante) |>
  unnest(ocupante) |>
  group_by(boat) |>
  mutate(
    i = row_number() - 1,
    nivel = (i %/% 2) * paso + 1,
    px = x + (i %% 2 - 0.5) * 1.1
  ) |>
  ungroup() |>
  mutate(ocupante = factor(ocupante, levels = c(names(colores), "Vacía")))


# Cifras para el texto, calculadas a partir de los datos
primeros <- filter(botes, minuto <= 70) # hasta la 1:10
siguientes <- filter(botes, minuto > 70)
ocupacion <- function(x) paste0(round(sum(x$total) / sum(x$cap) * 100), " %")
vacias_total <- sum(pmax(botes$cap - botes$total, 0))


# VALIDACIÓN 2: Fidelidad de los pictogramas
conteo <- plazas |>
  count(boat, name = "figuras") |>
  left_join(
    botes |>
      transmute(boat, esperadas = pmax(cap, total)),
    by = "boat"
  )

stopifnot(
  nrow(conteo) == nrow(botes),
  all(conteo$figuras == conteo$esperadas),
  sum(plazas$ocupante == "Vacía") == vacias_total
)


# VALIDACIÓN 3: Consistencia del mensaje editorial
stopifnot(
  nrow(primeros) == 6,
  nrow(siguientes) == 12,
  round(100 * sum(primeros$total) / sum(primeros$cap)) == 54,
  round(100 * sum(siguientes$total) / sum(siguientes$cap)) == 91
)


# Botes destacados: el primero en salir, el más vacío y el más lleno
pct_ocupacion <- function(total, cap) {
  paste0(round(total / cap * 100), "\u00a0%")
}
destacados <- botes |>
  mutate(
    ocup = total / cap,
    papel = case_when(
      ocup == min(ocup) ~ "el más vacío",
      ocup == max(ocup) ~ "el más lleno",
      row_number() == 1 ~ "el primero"
    )
  ) |>
  filter(!is.na(papel)) |>
  mutate(etiqueta = paste0(pct_ocupacion(total, cap), "\n", papel))

# El mar y el barco -------------------------------------------------------
hundimiento <- 140 # 2:20, hora del hundimiento
fondo_mar <- -9

# Olas: una línea ondulada en la superficie
olas <- tibble(x = seq(34, 172, by = 0.25)) |> mutate(y = 0.2 * sin(x / 1.6))

# Pequeño casco bajo cada columna
cascos <- botes |>
  select(boat, x) |>
  mutate(
    casco = map(x, \(cx) {
      tibble(px = cx + c(-1.4, 1.4, 0.9, -0.9), py = c(0.5, 0.5, -0.5, -0.5))
    })
  ) |>
  select(boat, casco) |>
  unnest(casco)

# Silueta del barco hundiéndose, dibujada con polígonos e inclinada
gira <- function(df, angulo, cx, cy) {
  a <- angulo * pi / 180
  mutate(
    df,
    x2 = cx + x * cos(a) - y * sin(a),
    y2 = cy + x * sin(a) + y * cos(a)
  )
}
# Proa a la izquierda (se hunde primero), popa a la derecha. Casco negro con
# franja blanca, superestructura blanca y cuatro chimeneas color ante con remate negro
chimenea <- function(i) {
  cx <- -5.8 + (i - 1) * 3.6
  base <- tibble(x = cx + c(-0.85, 0.85, 1.75, 0.05), y = c(3.2, 3.2, 8.6, 8.6))
  remate <- tibble(
    x = cx + c(1.55, 1.75, 0.05, -0.15) - 0.05,
    y = c(7.6, 8.6, 8.6, 7.6)
  )
  bind_rows(
    mutate(base, pieza = paste0("chimenea", i), color = "#D9A44A"),
    mutate(remate, pieza = paste0("remate", i), color = "#15181D")
  )
}
barco <- bind_rows(
  tibble(
    pieza = "casco",
    color = "#15181D",
    x = c(-17, -15.5, 14.5, 16, 15.2, 13.5, -14.2),
    y = c(1.6, 1.2, 1.2, 1.6, -2.4, -3.6, -3.6)
  ),
  tibble(
    pieza = "franja",
    color = "#E9EDF2",
    x = c(-16.6, 15.6, 15.5, -16.3),
    y = c(1.4, 1.4, 0.9, 0.9)
  ),
  tibble(
    pieza = "cubierta1",
    color = "#E9EDF2",
    x = c(-11, 11, 11, -11),
    y = c(1.6, 1.6, 2.5, 2.5)
  ),
  tibble(
    pieza = "cubierta2",
    color = "#E9EDF2",
    x = c(-9, 9, 9, -9),
    y = c(2.5, 2.5, 3.2, 3.2)
  ),
  map_dfr(1:4, chimenea),
  tibble(
    pieza = "mastil1",
    color = "#8C9BAE",
    x = c(-13.2, -12.95, -12.95, -13.2),
    y = c(1.6, 1.6, 6.5, 6.5)
  ),
  tibble(
    pieza = "mastil2",
    color = "#8C9BAE",
    x = c(12.6, 12.85, 12.85, 12.6),
    y = c(1.6, 1.6, 6.5, 6.5)
  )
) |>
  gira(angulo = 22, cx = hundimiento + 14, cy = 1.5)

# Eje de capacidad a la izquierda: solo las tres capacidades de los botes del Titanic.
# La altura coincide con la rayita que marca la capacidad en cada columna
altura_cap <- function(cap) (ceiling(cap / 2) - 1) * paso + 1.95
eje_cap <- tibble(cap = c(40, 47, 65)) |> mutate(y = altura_cap(cap))

# Eje de tiempo dentro del mar
marcas_hora <- tibble(minuto = seq(45, 135, by = 15)) |>
  mutate(lab = sprintf("%d:%02d", minuto %/% 60, minuto %% 60))

# Textos ------------------------------------------------------------------
titulo <- "Los primeros botes del Titanic salieron medio vacíos"
subtitulo <- glue(
  "Según las estimaciones del informe británico de 1912, los primeros {nrow(primeros)} botes que se arriaron hasta ",
  "la 1:10 iban al {ocupacion(primeros)} de su capacidad."
)
capacidades <- glue(
  "**Tres tipos de bote.** El Titanic llevaba catorce botes salvavidas de 65 plazas, dos de emergencia ",
  "de 40 y cuatro plegables de 47. Dos botes ",
  "no llegaron a arriarse con normalidad."
)

nota <- glue(
  "Cada figura representa una plaza y cada columna, un bote según su hora de arriado. ",
  "Las figuras oscuras indican plazas vacías; la raya horizontal, capacidad; ",
  "los porcentajes bajo el agua, ocupación. ",
  "Las cifras son estimaciones históricas. «Mujeres» incluye tripulantes femeninas.<br>",
  "Fuente: Mersey (1912), vía paquete vcd · #30DayChartChallenge · ",
  "Día 02: Pictogram · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
# Cada persona es una cabeza (punto) y un cuerpo (segmento con extremos redondos)
grafico <- ggplot() +
  # mar
  annotate(
    "rect",
    xmin = -Inf,
    xmax = Inf,
    ymin = fondo_mar,
    ymax = 0,
    fill = mar
  ) +
  # barco hundiéndose, con la parte bajo el agua oscurecida por una capa de mar
  geom_polygon(
    data = barco,
    aes(x2, y2, group = pieza, fill = color),
    colour = "#3A4A60",
    linewidth = 0.2
  ) +
  scale_fill_identity() +
  annotate(
    "rect",
    xmin = -Inf,
    xmax = Inf,
    ymin = fondo_mar,
    ymax = 0,
    fill = mar,
    alpha = 0.75
  ) +
  geom_path(data = olas, aes(x, y), colour = "#5E7FA3", linewidth = 0.5) +
  annotate(
    "text",
    x = hundimiento + 14,
    y = 15,
    label = "2:20\nSe hunde el Titanic",
    colour = texto,
    size = 3.6,
    lineheight = 1.1,
    fontface = "bold"
  ) +
  # explicación de las capacidades en el cielo, encima del barco
  geom_textbox(
    data = tibble(x = 172, y = 47, lab = capacidades),
    aes(x, y, label = lab),
    hjust = 1,
    vjust = 1,
    halign = 0,
    width = unit(0.36, "npc"),
    size = 3.9,
    lineheight = 1.3,
    colour = suave,
    family = fuente_texto,
    fill = NA,
    box.colour = NA,
    box.padding = unit(0, "pt")
  ) +
  # eje de tiempo en el agua
  geom_text(
    data = marcas_hora,
    aes(minuto, -2.1, label = lab),
    colour = suave,
    size = 3.2
  ) +
  geom_segment(
    data = marcas_hora,
    aes(x = minuto, xend = minuto, y = -0.9, yend = -1.4),
    colour = suave,
    linewidth = 0.3
  ) +
  # ocupación de los botes más llamativos, bajo su casco
  geom_text(
    data = destacados,
    aes(x, -3.6, label = etiqueta),
    vjust = 1,
    size = 3,
    lineheight = 1.1,
    colour = texto
  ) +
  # eje de capacidad
  annotate(
    "segment",
    x = 40.5,
    xend = 40.5,
    y = 0.6,
    yend = max(eje_cap$y),
    colour = suave,
    linewidth = 0.3
  ) +
  geom_segment(
    data = eje_cap,
    aes(x = 40, xend = 40.5, y = y, yend = y),
    colour = suave,
    linewidth = 0.3
  ) +
  geom_text(
    data = eje_cap,
    aes(x = 39.6, y = y, label = cap),
    hjust = 1,
    size = 3.2,
    colour = suave
  ) +
  annotate(
    "text",
    x = 40.5,
    y = max(eje_cap$y) + 2.2,
    label = "Plazas",
    hjust = 0.5,
    size = 3.2,
    colour = suave
  ) +
  # botes
  geom_polygon(data = cascos, aes(px, py, group = boat), fill = "#8C9BAE") +
  geom_segment(
    data = plazas,
    aes(
      x = px,
      xend = px,
      y = nivel + 0.0,
      yend = nivel + 0.42,
      colour = ocupante
    ),
    linewidth = 1.6,
    lineend = "round",
    show.legend = FALSE
  ) +
  geom_point(
    data = plazas,
    aes(px, nivel + 0.78, colour = ocupante),
    size = 1.2
  ) +
  # capacidad de cada bote
  geom_segment(
    data = botes,
    aes(
      x = x - 1.2,
      xend = x + 1.2,
      y = altura_cap(cap),
      yend = altura_cap(cap)
    ),
    colour = texto,
    linewidth = 0.4
  ) +
  scale_colour_manual(
    values = c(colores, "Vacía" = vacio),
    name = NULL,
    breaks = c(names(colores), "Vacía"),
    labels = c(names(colores), "Plazas vacías"),
    guide = guide_legend(override.aes = list(size = 4))
  ) +
  coord_fixed(
    ratio = 1.95,
    xlim = c(34, 172),
    ylim = c(fondo_mar, 48),
    expand = FALSE,
    clip = "off"
  ) +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_size = 13, base_family = fuente_texto) +
  theme(
    plot.background = element_rect(fill = cielo, colour = NA),
    plot.margin = margin(25, 25, 20, 25),
    plot.title = element_textbox_simple(
      family = fuente_titulo,
      size = 30,
      colour = texto,
      lineheight = 1.1,
      margin = margin(b = 10)
    ),
    plot.subtitle = element_textbox_simple(
      size = 14,
      colour = suave,
      lineheight = 1.25,
      margin = margin(b = 10)
    ),
    plot.caption = element_textbox_simple(
      size = 9,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 10)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    legend.position = "top",
    legend.direction = "horizontal",
    legend.text = element_text(size = 11, colour = texto),
    legend.margin = margin(t = 10, b = 10)
  )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5 que funciona bien en LinkedIn
ggsave(
  "2026/02-pictogram/grafico.png",
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = cielo
)
