# Día 05 - Experimental
# #30DayChartChallenge
# Caras de Chernoff con forma de dragón: las 10 familias de dragones de D&D,
# de cría a anciano, según sus seis características

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(tidytuesdayR)

# Colores y tipografía ----------------------------------------------------
fondo <- "#ffffff" # pergamino
texto <- "#2B2118"
suave <- "#6B5D4D"
marfil <- "#F6EEDC"
ojo <- "#F4C542"

# Cada familia se pinta con el color que le da nombre. El color identifica al dragón
# y siempre va acompañado de su nombre, así que no se necesita distinguirlo para leer.
familias <- tribble(
  ~category        , ~familia         , ~relleno  , ~grupo       ,
  "Red Dragons"    , "Red Dragons"    , "#B5483C" , "Cromáticos" ,
  "Blue Dragons"   , "Blue Dragons"   , "#3F6EA6" , "Cromáticos" ,
  "Green Dragons"  , "Green Dragons"  , "#4F8A58" , "Cromáticos" ,
  "Black Dragons"  , "Black Dragons"  , "#34343A" , "Cromáticos" ,
  "White Dragons"  , "White Dragons"  , "#F4F4F2" , "Cromáticos" ,
  "Brass Dragons"  , "Brass Dragons"  , "#C9A24A" , "Metálicos"  ,
  "Copper Dragons" , "Copper Dragons" , "#B4703F" , "Metálicos"  ,
  "Gold Dragons"   , "Gold Dragons"   , "#DDB13A" , "Metálicos"  ,
  "Silver Dragons" , "Silver Dragons" , "#AEB6BF" , "Metálicos"  ,
  "Bronze Dragons" , "Bronze Dragons" , "#8F6236" , "Metálicos"
) |>
  mutate(relleno = scales::alpha(relleno, 0.7)) # 30 % de transparencia

# Tipografías de Google Fonts (licencia OFL) guardadas en la carpeta fuentes
systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = "2026/05-experimental/fuentes/UncialAntiqua-Regular.ttf"
)
systemfonts::register_font(
  "Texto",
  plain = "2026/05-experimental/fuentes/FiraSans-Regular.ttf",
  bold = "2026/05-experimental/fuentes/FiraSans-SemiBold.ttf",
  italic = "2026/05-experimental/fuentes/FiraSans-Italic.ttf"
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: D&D System Reference Document 5.2 vía TidyTuesday (2025-05-27)
monstruos <- tidytuesdayR::tt_load("2025-05-27")$monsters

# Preparación -------------------------------------------------------------
edades <- c(
  "Wyrmling" = "Cría",
  "Young" = "Joven",
  "Adult" = "Adulto",
  "Ancient" = "Anciano"
)

dragones <- monstruos |>
  inner_join(familias, by = "category") |>
  mutate(
    edad_en = str_extract(name, "Wyrmling|Young|Adult|Ancient"),
    edad = factor(edades[edad_en], levels = edades)
  ) |>
  filter(edad %in% c("Cría", "Anciano")) |>
  mutate(
    # rasgos del glifo, escalados entre los 20 dragones
    ancho = scales::rescale(str, to = c(0.50, 1.00)), # Fuerza
    alto = scales::rescale(con, to = c(0.60, 1.10)), # Constitución
    ojos = scales::rescale(int, to = c(0.05, 0.17)), # Inteligencia
    cuernos = scales::rescale(wis, to = c(0.15, 0.65)), # Sabiduría
    sonrisa = scales::rescale(cha, to = c(-0.05, 0.20)), # Carisma
    puas = case_when(dex <= 10 ~ 1, dex <= 12 ~ 2, TRUE ~ 3) # Destreza
  ) |>
  arrange(match(category, familias$category), edad)

stopifnot(nrow(dragones) == 20)

# Glifo de cabeza de dragón -----------------------------------------------
# Devuelve los polígonos de una cabeza centrada en (cx, cy) con escala u.
cabeza_dragon <- function(
  ancho,
  alto,
  ojos,
  cuernos,
  sonrisa,
  puas,
  cx,
  cy,
  u,
  relleno,
  id
) {
  borde_x <- function(y) {
    # media anchura de la cabeza a la altura y
    base <- ancho * sqrt(pmax(0, 1 - (y / alto)^2))
    if_else(y < 0, base * (1 - 0.45 * (-y / alto)), base)
  }
  pieza <- function(x, y, parte, color, orden) {
    tibble(
      x = cx + u * x,
      y = cy + u * y,
      parte = parte,
      color = color,
      orden = orden,
      id = id,
      grupo = paste(id, parte)
    )
  }
  out <- list()

  # púas laterales (Destreza), detrás de la cabeza
  for (lado in c(-1, 1)) {
    ys <- seq(0.35 * alto, -0.15 * alto, length.out = 3)[seq_len(puas)]
    for (k in seq_along(ys)) {
      y0 <- ys[k]
      xe <- borde_x(y0) - 0.03
      out[[length(out) + 1]] <- pieza(
        lado * c(xe, xe + 0.30, xe),
        c(y0 + 0.09, y0 + 0.06, y0 - 0.09),
        paste0("pua", lado, k),
        colorspace::darken(relleno, 0.25),
        1
      )
    }
  }
  # cuernos (Sabiduría), detrás de la cabeza
  for (lado in c(-1, 1)) {
    p1 <- c(0.62 * ancho, 0.62 * alto)
    p2 <- c(0.30 * ancho, 0.90 * alto)
    tip <- c(0.62 * ancho + 0.45 * cuernos, 0.90 * alto + cuernos)
    m1 <- (p1 + tip) / 2 + c(0.08, -0.02)
    m2 <- (p2 + tip) / 2 + c(-0.04, 0.03)
    xs <- c(p1[1], m1[1], tip[1], m2[1], p2[1])
    ys <- c(p1[2], m1[2], tip[2], m2[2], p2[2])
    out[[length(out) + 1]] <- pieza(
      lado * xs,
      ys,
      paste0("cuerno", lado),
      marfil,
      2
    )
  }
  # cabeza (ancho por Fuerza, alto por Constitución)
  t <- seq(0, 2 * pi, length.out = 90)
  yh <- alto * sin(t)
  xh <- sign(cos(t)) * borde_x(yh)
  out[[length(out) + 1]] <- pieza(xh, yh, "cabeza", relleno, 3)
  # ojos (Inteligencia) con pupila de reptil
  te <- seq(0, 2 * pi, length.out = 40)
  for (lado in c(-1, 1)) {
    ex <- lado * 0.38 * ancho
    ey <- 0.18 * alto
    out[[length(out) + 1]] <- pieza(
      ex + ojos * cos(te),
      ey + 0.72 * ojos * sin(te),
      paste0("ojo", lado),
      ojo,
      4
    )
    out[[length(out) + 1]] <- pieza(
      ex + 0.22 * ojos * cos(te),
      ey + 0.66 * ojos * sin(te),
      paste0("pupila", lado),
      texto,
      5
    )
  }
  # fosas nasales
  for (lado in c(-1, 1)) {
    out[[length(out) + 1]] <- pieza(
      lado * 0.12 * ancho + 0.035 * cos(te),
      -0.30 * alto + 0.022 * sin(te),
      paste0("nariz", lado),
      texto,
      5
    )
  }
  # colmillos y boca (Carisma: cuanto más carisma, más sonrisa)
  mw <- borde_x(-0.62 * alto) * 0.72
  boca_y <- function(x) -0.62 * alto - sonrisa * (1 - (x / mw)^2)
  for (lado in c(-1, 1)) {
    fx <- lado * 0.55 * mw
    fy <- boca_y(fx)
    out[[length(out) + 1]] <- pieza(
      c(fx - 0.05, fx + 0.05, fx),
      c(fy, fy, fy - 0.13),
      paste0("colmillo", lado),
      "white",
      6
    )
  }
  xm <- seq(-mw, mw, length.out = 30)
  lineas <- list(pieza(xm, boca_y(xm), "boca", NA, 7))
  # cejas inclinadas sobre los ojos, para darle cara de pocos amigos
  for (lado in c(-1, 1)) {
    ey <- 0.18 * alto
    lineas[[length(lineas) + 1]] <- pieza(
      lado * c(0.16 * ancho, 0.62 * ancho),
      c(ey + 0.85 * ojos + 0.03, ey + 1.1 * ojos + 0.14),
      paste0("ceja", lado),
      NA,
      7
    )
  }
  list(poligonos = bind_rows(out), boca = bind_rows(lineas))
}

# Composición -------------------------------------------------------------
# Lienzo de 1080 x 1350 px, una unidad del gráfico es un píxel.
u <- 54
filas <- tribble(
  ~familia         , ~x_centro , ~base ,
  "Red Dragons"    ,       195 ,  1145 ,
  "Blue Dragons"   ,       540 ,  1145 ,
  "Green Dragons"  ,       885 ,  1145 ,
  "Black Dragons"  ,       195 ,   920 ,
  "White Dragons"  ,       885 ,   920 ,
  "Brass Dragons"  ,       195 ,   695 ,
  "Copper Dragons" ,       885 ,   695 ,
  "Gold Dragons"   ,       195 ,   450 ,
  "Silver Dragons" ,       540 ,   450 ,
  "Bronze Dragons" ,       885 ,   450
)

# El anciano detrás y la cría delante, a su izquierda y un poco solapada,
# las dos apoyadas en la misma base
solape <- -15

dragones <- dragones |>
  left_join(filas, by = "familia") |>
  group_by(familia) |>
  mutate(
    mitad = (ancho + 0.32) * u,
    m_cria = mitad[edad == "Cría"],
    m_anc = mitad[edad == "Anciano"],
    x_anc = x_centro + (m_cria - solape) / 2,
    cx = if_else(edad == "Anciano", x_anc, x_anc - m_anc - m_cria + solape),
    cy = base + u * alto,
    capa = if_else(edad == "Anciano", 1, 2)
  ) |>
  ungroup()

glifos <- pmap(
  dragones,
  \(ancho, alto, ojos, cuernos, sonrisa, puas, cx, cy, relleno, name, ...) {
    cabeza_dragon(
      ancho,
      alto,
      ojos,
      cuernos,
      sonrisa,
      puas,
      cx,
      cy,
      u,
      relleno,
      name
    )
  }
)
# se dibuja primero el anciano entero y después la cría encima
poligonos <- map_dfr(glifos, "poligonos") |>
  left_join(select(dragones, id = name, capa), by = "id") |>
  arrange(capa, orden)
bocas <- map_dfr(glifos, "boca")

etiquetas_familia <- filas |> mutate(label = familia)

# Cabeza de referencia para la leyenda: valores medios de los 20 dragones
media <- dragones |>
  summarise(across(c(ancho, alto, ojos, cuernos, sonrisa), mean))
ref_x <- 300
ref_y <- 190
ref_u <- 62
ref <- cabeza_dragon(
  media$ancho,
  media$alto,
  media$ojos,
  media$cuernos,
  media$sonrisa,
  2,
  ref_x,
  ref_y,
  ref_u,
  "#C9B48F",
  "ref"
)
ref_pol <- ref$poligonos |> arrange(orden)

claves <- tribble(
  ~x  , ~y  , ~xend , ~yend , ~label                                 , ~hjust ,
   40 , 295 ,   262 ,   262 , "**Sabiduría**<br>cuernos más largos"  ,      0 ,
   40 , 215 ,   280 ,   200 , "**Inteligencia**<br>ojos más grandes" ,      0 ,
   40 , 135 ,   243 ,   190 , "**Destreza**<br>más púas"             ,      0 ,
  440 , 295 ,   340 ,   235 , "**Constitución**<br>cabeza más alta"  ,      0 ,
  440 , 215 ,   348 ,   185 , "**Fuerza**<br>cabeza más ancha"       ,      0 ,
  440 , 135 ,   312 ,   152 , "**Carisma**<br>sonrisa más amplia"    ,      0
) |>
  mutate(x_ini = if_else(x < ref_x, x + 150, x - 6))

# Datos para los textos, calculados de la tabla
anciano <- filter(dragones, edad == "Anciano")
mas_listo <- anciano |> slice_max(int, n = 1, with_ties = TRUE)
menos_listo <- anciano |> slice_min(int, n = 1)
mas_carisma <- anciano |> slice_max(cha, n = 1)

# Textos ------------------------------------------------------------------
titulo <- "Así crecen los dragones"
subtitulo <- glue(
  "Las 10 familias de dragones de Dungeons & Dragons. Cada cabeza es una cara de Chernoff. ",
  "Sus seis características mueven los cuernos, ",
  "los ojos, las púas, el tamaño (alto y ancho) y la sonrisa."
)
lectura <- glue(
  "**Cómo se lee.** Cada familia tiene dos cabezas, la cría delante y el anciano detrás. ",
  "Con la edad ganan fuerza y constitución, así que la cabeza crece como una matrioska.<br><br>",
  "**{menos_listo$familia}, la familia menos lista.** Su anciano tiene Inteligencia {menos_listo$int}, de ahí sus ojos diminutos. ",
  "Las más listas son {paste(mas_listo$familia, collapse = ' y ')}, con {mas_listo$int[1]}.<br><br>",
  "**{mas_carisma$familia}, la sonrisa más grande.** Su anciano llega a Carisma {mas_carisma$cha}."
)
nota <- glue(
  "Datos D&D System Reference Document 5.2 vía TidyTuesday · #30DayChartChallenge Día 05 Experimental · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot() +
  # cabezas
  geom_polygon(
    data = poligonos,
    aes(x, y, group = grupo, fill = color),
    colour = texto,
    linewidth = 0.3
  ) +
  geom_path(
    data = bocas,
    aes(x, y, group = grupo),
    colour = texto,
    linewidth = 0.45,
    lineend = "round"
  ) +
  # nombre de cada familia
  geom_text(
    data = etiquetas_familia,
    aes(x_centro, base - 20, label = label),
    family = "Titulo",
    size = 5,
    colour = texto
  ) +
  # grupos
  annotate(
    "text",
    x = 540,
    y = 1080,
    label = "DRAGONES CROMÁTICOS · MALVADOS",
    size = 3.3,
    colour = suave,
    fontface = "bold"
  ) +
  annotate(
    "text",
    x = 540,
    y = 630,
    label = "DRAGONES METÁLICOS · BONDADOSOS",
    size = 3.3,
    colour = suave,
    fontface = "bold"
  ) +
  # título en el centro
  geom_textbox(
    data = tibble(x = 540, y = 925, label = titulo),
    aes(x, y, label = label),
    family = "Titulo",
    size = 10,
    colour = texto,
    halign = 0.5,
    hjust = 0.5,
    vjust = 0.5,
    width = unit(2.9, "in"),
    fill = NA,
    box.colour = NA,
    lineheight = 1
  ) +
  geom_textbox(
    data = tibble(x = 540, y = 760, label = subtitulo),
    aes(x, y, label = label),
    size = 3.4,
    colour = suave,
    halign = 0.5,
    hjust = 0.5,
    vjust = 0.5,
    lineheight = 1.25,
    width = unit(2.8, "in"),
    fill = NA,
    box.colour = NA
  ) +
  # leyenda inferior
  annotate(
    "segment",
    x = 40,
    xend = 1040,
    y = 375,
    yend = 375,
    colour = suave,
    linewidth = 0.4
  ) +
  annotate(
    "text",
    x = 40,
    y = 350,
    label = "Los dragones explicados",
    hjust = 0,
    family = "Titulo",
    size = 5.2,
    colour = texto
  ) +
  geom_polygon(
    data = ref_pol,
    aes(x, y, group = grupo, fill = color),
    colour = texto,
    linewidth = 0.35
  ) +
  geom_path(
    data = ref$boca,
    aes(x, y, group = grupo),
    colour = texto,
    linewidth = 0.6
  ) +
  geom_segment(
    data = claves,
    aes(x = x_ini, y = y, xend = xend, yend = yend),
    colour = suave,
    linewidth = 0.3
  ) +
  geom_richtext(
    data = claves,
    aes(x, y, label = label, hjust = hjust),
    size = 3.1,
    colour = texto,
    lineheight = 1.1,
    fill = NA,
    label.colour = NA,
    family = "Texto"
  ) +
  geom_textbox(
    data = tibble(x = 640, y = 215, label = lectura),
    aes(x, y, label = label),
    hjust = 0,
    vjust = 0.5,
    size = 3.1,
    colour = texto,
    lineheight = 1.25,
    width = unit(3.0, "in"),
    fill = NA,
    box.colour = NA
  ) +
  geom_textbox(
    data = tibble(x = 40, y = 52, label = nota),
    aes(x, y, label = label),
    hjust = 0,
    vjust = 0.5,
    size = 2.6,
    colour = suave,
    lineheight = 1.3,
    width = unit(7.4, "in"),
    fill = NA,
    box.colour = NA
  ) +
  scale_fill_identity() +
  coord_equal(
    xlim = c(0, 1080),
    ylim = c(0, 1350),
    expand = FALSE,
    clip = "off"
  ) +
  theme_void(base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(0, 0, 0, 0)
  )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5 que funciona bien en LinkedIn
ggsave(
  "2026/05-experimental/grafico.png",
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = fondo
)
