# Día 06 - RSF Data Day
# #30DayChartChallenge
# Bump chart: puesto de Sudamérica y España en la Clasificación Mundial de la
# Libertad de Prensa de Reporteros Sin Fronteras, de 2013 a 2026

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(pressfreedom.data)

carpeta <- file.path("2026", "06-rsf-data-day")

# Colores y tipografía ----------------------------------------------------
fondo <- "#FAFAF8"
texto <- "#1F2328"
suave <- "#6E7781"
gris <- "#D3D6DA" # líneas sin destacar
gris_texto <- "#8C939B" # sus etiquetas, con más contraste

# Paul Tol muted (khroma), apta para daltonismo. Solo los tonos con buen contraste
# sobre fondo claro, uno por país destacado.
muted <- khroma::colour("muted")(9)
destacados <- c(
  "España" = muted[[1]], # rosa
  "Ecuador" = muted[[2]], # índigo
  "Brasil" = muted[[9]], # púrpura
  "Perú" = muted[[7]], # verde azulado
  "Argentina" = muted[[6]] # vino
)

# Tipografías de Google Fonts (licencia OFL) guardadas en la carpeta fuentes
systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/06-rsf-data-day/fuentes", "BebasNeue-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("2026/06-rsf-data-day/fuentes", "Barlow-Regular.ttf"),
  bold = file.path("2026/06-rsf-data-day/fuentes", "Barlow-SemiBold.ttf")
)
systemfonts::register_font(
  "Etiqueta",
  plain = file.path(
    "2026/06-rsf-data-day/fuentes",
    "BarlowCondensed-Medium.ttf"
  ),
  bold = file.path(
    "2026/06-rsf-data-day/fuentes",
    "BarlowCondensed-SemiBold.ttf"
  )
)
update_geom_defaults("text", list(family = "Etiqueta"))

# Datos -------------------------------------------------------------------
# Fuente: Reporteros Sin Fronteras vía el paquete pressfreedom.data
rsf <- pressfreedom.data::rwb_standardized

paises <- tribble(
  ~iso  , ~pais     ,
  "ESP" , "España"  , "ARG" , "Argentina" , "BOL" , "Bolivia"  ,
  "BRA" , "Brasil"  , "CHL" , "Chile"     , "COL" , "Colombia" ,
  "ECU" , "Ecuador" , "PRY" , "Paraguay"  , "PER" , "Perú"     ,
  "URY" , "Uruguay" , "VEN" , "Venezuela"
)

# Preparación -------------------------------------------------------------
region <- rsf |>
  filter(year_n >= 2013) |>
  inner_join(paises, by = "iso") |>
  group_by(year_n) |>
  mutate(puesto = rank(rank)) |> # puesto entre los 11, a partir del mundial
  ungroup() |>
  mutate(
    destacado = pais %in% names(destacados),
    color = coalesce(destacados[pais], gris),
    color_texto = coalesce(destacados[pais], gris_texto)
  )

stopifnot(all(count(region, year_n)$n == 11))

inicio <- filter(region, year_n == min(year_n))
final <- filter(region, year_n == max(year_n))

# Valores para el subtítulo, calculados de la tabla
pos <- function(p, a) region$puesto[region$pais == p & region$year_n == a]
esp_lider <- region |>
  filter(pais == "España", puesto == 1) |>
  pull(year_n) |>
  min()

ordinal <- function(x) paste0(x, "º")

# Textos ------------------------------------------------------------------
col <- function(p) glue("<span style='color:{destacados[[p]]}'>**{p}**</span>")
titulo <- "Libertad de prensa en<br>Sudamérica y España"
subtitulo <- glue(
  "Evolución de los 11 países en la Clasificación Mundial de la Libertad de Prensa de RSF. ",
  "{col('España')} adelanta a Uruguay y lidera desde {esp_lider}, ",
  "{col('Brasil')} sube del {ordinal(pos('Brasil', 2013))} al {ordinal(pos('Brasil', 2026))} puesto ",
  "y {col('Perú')} cae del {ordinal(pos('Perú', 2013))} al {ordinal(pos('Perú', 2026))}. ",
  "{col('Argentina')} y {col('Ecuador')} dan un salto en 2022 y después vuelven a bajar."
)
nota <- glue(
  "Los números de los extremos son el puesto mundial entre unos 180 países. En 2022 RSF cambió su metodología, ",
  "así que parte del salto de ese año se debe al método.<br>",
  "Datos Reporteros Sin Fronteras vía pressfreedom.data · #30DayChartChallenge Día 06 RSF Data Day · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot(region, aes(year_n, puesto, group = pais)) +
  # cambio de metodología
  annotate(
    "segment",
    x = 2021.5,
    xend = 2021.5,
    y = 0.45,
    yend = 11.5,
    colour = suave,
    linewidth = 0.35,
    linetype = "dashed"
  ) +
  annotate(
    "text",
    x = 2021.55,
    y = 0.25,
    label = "Nueva metodología",
    hjust = 0,
    size = 3.1,
    colour = suave
  ) +
  # países sin destacar
  geom_line(data = filter(region, !destacado), colour = gris, linewidth = 1.2) +
  geom_point(data = filter(region, !destacado), colour = gris, size = 2.2) +
  # países destacados, con su puesto dentro del círculo
  geom_line(
    data = filter(region, destacado),
    aes(colour = color),
    linewidth = 2.4
  ) +
  geom_point(
    data = filter(region, destacado),
    aes(colour = color),
    size = 6.8,
    shape = 21,
    fill = "white",
    stroke = 1.3
  ) +
  geom_text(
    data = filter(region, destacado),
    aes(label = puesto, colour = color),
    size = 3.1,
    fontface = "bold"
  ) +
  # etiquetas de los extremos: país y puesto mundial
  geom_text(
    data = inicio,
    aes(
      x = year_n - 0.45,
      label = glue("{pais}  {ordinal(rank)}"),
      colour = color_texto
    ),
    hjust = 1,
    size = 3.9,
    fontface = "bold"
  ) +
  geom_text(
    data = final,
    aes(
      x = year_n + 0.45,
      label = glue("{ordinal(rank)}  {pais}"),
      colour = color_texto
    ),
    hjust = 0,
    size = 3.9,
    fontface = "bold"
  ) +
  scale_colour_identity() +
  scale_y_reverse(expand = expansion(add = c(0.5, 0.5))) +
  scale_x_continuous(
    breaks = 2013:2026,
    labels = \(x) paste0("'", x %% 100),
    position = "top",
    expand = expansion(add = c(3.6, 3.6))
  ) +
  coord_cartesian(clip = "off") +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_size = 13, base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 24, 20, 24),
    axis.text.x.top = element_text(
      family = "Etiqueta",
      size = 11,
      colour = suave,
      margin = margin(b = 6)
    ),
    plot.title = element_textbox_simple(
      family = "Titulo",
      size = 44,
      colour = texto,
      lineheight = 0.95,
      margin = margin(b = 10)
    ),
    plot.subtitle = element_textbox_simple(
      size = 13.5,
      colour = suave,
      lineheight = 1.3,
      margin = margin(b = 22)
    ),
    plot.caption = element_textbox_simple(
      size = 9.5,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 16)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

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
