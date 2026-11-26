# Día 09 - Wealth
# #30DayChartChallenge
# Waffle de proporciones: jugadores y masa salarial de las Grandes Ligas en 2016

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(ragg)
library(Lahman)
library(scico)

carpeta <- file.path("2026", "09-wealth")

# Colores y tipografía ----------------------------------------------------
fondo <- "#FAF8F3"
texto <- "#1F1A17"
suave <- "#6F665E"

systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/09-wealth/fuentes", "AlfaSlabOne-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path("2026/09-wealth/fuentes", "ZillaSlab-Regular.ttf"),
  bold = file.path("2026/09-wealth/fuentes", "ZillaSlab-SemiBold.ttf")
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: Lahman Baseball Database vía el paquete Lahman
temporada <- 2016

sueldos <- Lahman::Salaries |>
  filter(yearID == temporada) |>
  group_by(playerID) |>
  summarise(sueldo = sum(salary)) |>
  arrange(desc(sueldo)) |>
  mutate(puesto = row_number())

# Preparación -------------------------------------------------------------
n <- nrow(sueldos)
niveles <- c(
  "El 1 %",
  "El 9 % siguiente",
  "El 40 % del medio",
  "El 50 % peor pagado"
)

# Lajolla (scico), secuencial y apta para daltonismo: más oscuro cuanto más gana el grupo
colores <- setNames(
  scico::scico(4, palette = "lajolla", begin = 0.15, end = 0.85),
  niveles
)

grupos <- sueldos |>
  mutate(
    grupo = case_when(
      puesto <= ceiling(n * 0.01) ~ niveles[1],
      puesto <= ceiling(n * 0.10) ~ niveles[2],
      puesto <= ceiling(n * 0.50) ~ niveles[3],
      TRUE ~ niveles[4]
    )
  ) |>
  group_by(grupo = factor(grupo, levels = niveles)) |>
  summarise(jugadores = n(), dinero = sum(sueldo)) |>
  mutate(
    p_jugadores = jugadores / sum(jugadores),
    p_dinero = dinero / sum(dinero)
  )

# 100 casillas por el método del mayor resto, para que siempre sumen 100
casillas <- function(p) {
  base <- floor(p * 100)
  extra <- order(p * 100 - base, decreasing = TRUE)[seq_len(100 - sum(base))]
  base[extra] <- base[extra] + 1
  base
}

# Waffles de 20 columnas por 5 filas, uno encima del otro. Se rellenan por columnas de
# izquierda a derecha, del grupo más rico al más pobre, para que los grupos queden alineados.
waffle <- function(n_casillas, y0) {
  tibble(grupo = factor(rep(niveles, n_casillas), levels = niveles)) |>
    mutate(i = row_number() - 1, x = i %/% 5, y = y0 + 4 - i %% 5)
}

celdas <- bind_rows(
  waffle(casillas(grupos$p_jugadores), 16),
  waffle(casillas(grupos$p_dinero), 5.2)
)

# Leyenda bajo cada waffle: arriba cuántos jugadores son y abajo cuánto dinero se llevan
pct <- function(x) paste0(round(100 * x), " %")
miles_millones <- format(round(sum(grupos$dinero) / 1e9, 2), decimal.mark = ",")

leyenda <- bind_rows(
  grupos |>
    mutate(
      x = c(0, 5, 10, 15),
      y = 14.2,
      label = glue("**{grupo}**<br>{jugadores} jugadores")
    ),
  grupos |>
    mutate(
      x = c(0, 5, 10, 15),
      y = 3.4,
      label = glue(
        "**{pct(p_dinero)}** del dinero<br>para {str_to_lower(grupo)}"
      )
    )
)

# Textos ------------------------------------------------------------------
titulo <- "Los sueldos del béisbol en 100 casillas"
subtitulo <- glue(
  "Jugadores y masa salarial de las Grandes Ligas en {temporada}, por grupos de sueldo."
)
nota <- glue(
  "Cada casilla es el 1 % de los jugadores arriba y el 1 % del dinero en sueldos abajo.<br>",
  "Datos Lahman Baseball Database · #30DayChartChallenge Día 09 Wealth · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot(celdas) +
  geom_tile(aes(x, y, fill = grupo), width = 0.88, height = 0.88) +
  annotate(
    "text",
    x = -0.45,
    y = c(20.75, 9.95),
    hjust = 0,
    vjust = 0,
    family = "Titulo",
    size = 5.4,
    colour = texto,
    label = c(
      glue("{n} jugadores"),
      glue("{miles_millones} mil millones de dólares en sueldos")
    )
  ) +
  # leyenda
  geom_tile(
    data = leyenda,
    aes(x, y, fill = grupo),
    width = 0.6,
    height = 0.6
  ) +
  geom_richtext(
    data = leyenda,
    aes(x + 0.55, y + 0.3, label = label),
    hjust = 0,
    vjust = 1,
    family = "Texto",
    size = 3.5,
    colour = texto,
    lineheight = 1.2,
    fill = NA,
    label.colour = NA,
    label.padding = unit(0, "pt")
  ) +
  scale_fill_manual(values = colores, guide = "none") +
  coord_equal(
    xlim = c(-0.6, 19.6),
    ylim = c(1.6, 22.4),
    expand = FALSE,
    clip = "off"
  ) +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 30, 20, 30),
    plot.title = element_text(
      family = "Titulo",
      size = 25,
      colour = texto,
      margin = margin(b = 8)
    ),
    plot.subtitle = element_text(
      size = 14,
      colour = suave,
      margin = margin(b = 18)
    ),
    plot.caption = element_textbox_simple(
      size = 10.5,
      colour = suave,
      lineheight = 1.3,
      margin = margin(t = 14)
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot"
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
