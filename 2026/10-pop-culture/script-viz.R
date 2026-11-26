# Día 10 - Pop Culture
# #30DayChartChallenge
# Dendrograma circular de los 151 Pokémon de la primera generación según sus estadísticas

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(dendextend)
library(ggtext)
library(glue)
library(ragg)
library(tidytuesdayR)
library(ggimage)

carpeta <- file.path("2026", "10-pop-culture")

# Colores y tipografía ----------------------------------------------------
fondo <- "#0B1026"
texto <- "#E8EAF2"
suave <- "#8B91AD"

systemfonts::clear_registry()
systemfonts::register_font(
  "Titulo",
  plain = file.path("2026/10-pop-culture/fuentes", "JuliusSansOne-Regular.ttf")
)
systemfonts::register_font(
  "Texto",
  plain = file.path(
    "2026/10-pop-culture/fuentes",
    "PT_Sans-Narrow-Web-Regular.ttf"
  ),
  bold = file.path("2026/10-pop-culture/fuentes", "PT_Sans-Narrow-Web-Bold.ttf")
)
update_geom_defaults("text", list(family = "Texto"))

# Datos -------------------------------------------------------------------
# Fuente: paquete pokemon vía TidyTuesday (2025-04-01)
pokemon <- tidytuesdayR::tt_load("2025-04-01")$pokemon_df

favoritos <- c(
  "mew",
  "bulbasaur",
  "eevee",
  "squirtle",
  "pikachu",
  "mewtwo",
  "charmander",
  "abra",
  "ditto",
  "jigglypuff",
  "koffing",
  "bellsprout",
  "golbat",
  "oddish",
  "chansey",
  "persian"
)

estadisticas <- c(
  "hp",
  "attack",
  "defense",
  "special_attack",
  "special_defense",
  "speed"
)

primera <- pokemon |>
  filter(generation_id == 1) |>
  mutate(nombre = str_to_title(pokemon))

stopifnot(nrow(primera) == 151)

# Agrupamiento ------------------------------------------------------------
# Estandarizo con los 151 para que la escala sea la de toda la generación y agrupo solo los favoritos
# Distancia euclídea y método de Ward
matriz <- scale(primera[, estadisticas])
rownames(matriz) <- primera$nombre
es_favorito <- primera$pokemon %in% favoritos
primera <- primera[es_favorito, ]
matriz <- matriz[es_favorito, ]
stopifnot(nrow(primera) == 16)
distancias <- dist(matriz)
arbol <- hclust(distancias, method = "ward.D2")

k <- 5
grupo <- stats::cutree(arbol, k)

# Nombre de cada grupo según su perfil medio de estadísticas
perfil <- primera |>
  mutate(grupo = grupo) |>
  group_by(grupo) |>
  summarise(n = n(), across(all_of(estadisticas), mean))

nombres_grupo <- c(
  "1" = "Básicos equilibrados",
  "2" = "Vida sin defensa",
  "3" = "Veloces",
  "4" = "Pura vida",
  "5" = "Legendarios"
)

# Paul Tol light (khroma), apta para daltonismo y luminosa sobre fondo oscuro
colores <- khroma::colour("light")(k)
names(colores) <- nombres_grupo

# Gemelos estadísticos: las dos parejas más cercanas sin Pokémon repetidos
cercanas <- as.matrix(distancias)
cercanas[upper.tri(cercanas, diag = TRUE)] <- NA
orden <- order(cercanas, na.last = NA)
pares <- arrayInd(orden, dim(cercanas))
gemelos <- tibble(
  a = rownames(cercanas)[pares[, 1]],
  b = rownames(cercanas)[pares[, 2]],
  d = cercanas[orden]
)
gemelos <- gemelos[1, ] |>
  bind_rows(filter(
    gemelos,
    !a %in% c(gemelos$a[1], gemelos$b[1]),
    !b %in% c(gemelos$a[1], gemelos$b[1])
  )[1, ])

# Geometría del dendrograma -----------------------------------------------
# Ramas y nombres del color de su grupo. Las ramas que unen grupos van en gris.
dend <- as.dendrogram(arbol)
grupo_hojas <- grupo[labels(dend)]
aparicion <- match(grupo_hojas, unique(grupo_hojas)) # grupos numerados en el orden del árbol
dend <- dend |>
  set("branches_col", suave) |>
  branches_attr_by_clusters(
    clusters = aparicion,
    values = unname(colores[unique(grupo_hojas)]),
    attr = "col"
  )

dend_gg <- as.ggdend(dend)
ramas <- dend_gg$segments
altura_max <- max(ramas$y, ramas$yend)
n <- nrow(primera)

hojas <- dend_gg$labels |>
  mutate(
    grupo_n = grupo[as.character(label)],
    color = colores[nombres_grupo[as.character(grupo_n)]],
    gemelo = as.character(label) %in% c(gemelos$a, gemelos$b)
  )

# Leyenda de grupos, en el orden en que aparecen en el árbol
leyenda <- perfil |>
  mutate(
    nombre = nombres_grupo[as.character(grupo)],
    label = glue(
      "<span style='color:{colores[nombre]}'>**{nombre}**</span> {n}"
    )
  ) |>
  arrange(match(grupo, unique(grupo_hojas)))

# Columna reservada para las imágenes, centrada en cada fila
hueco_imagen <- -1.4
imagenes <- hojas |>
  left_join(select(primera, label = nombre, pokemon), by = "label") |>
  transmute(y = x, x = hueco_imagen, pokemon)

pareja <- function(i) glue("{gemelos$a[i]} y {gemelos$b[i]}")

# Textos ------------------------------------------------------------------
titulo <- "Mis Pokémon favoritos de Kanto"
subtitulo <- "Dendrograma de 16 Pokémon de la primera generación según sus seis estadísticas base."
nota <- "Datos paquete pokemon vía TidyTuesday · #30DayChartChallenge Día 10 Pop Culture · Linda Cabrera Orellana"

# Gráfico -----------------------------------------------------------------
# Dendrograma horizontal: las hojas a la izquierda y la raíz a la derecha
grafico <- ggplot() +
  # brillo suave bajo las ramas
  geom_segment(
    data = ramas,
    aes(x = y, xend = yend, y = x, yend = xend, colour = col),
    linewidth = 3,
    alpha = 0.15,
    lineend = "round"
  ) +
  geom_segment(
    data = ramas,
    aes(x = y, xend = yend, y = x, yend = xend, colour = col),
    linewidth = 1.1,
    lineend = "round"
  ) +
  geom_point(
    data = hojas,
    aes(0, x, colour = if_else(gemelo, "white", color)),
    size = 2.6
  ) +
  geom_text(
    data = hojas,
    aes(
      -2.6,
      x,
      label = label,
      colour = if_else(gemelo, "white", color),
      fontface = if_else(gemelo, "bold", "plain")
    ),
    hjust = 1,
    size = 7.5
  ) +
  geom_pokemon(
    data = imagenes,
    aes(x = x, y = y, image = pokemon),
    size = 0.045
  ) +
  geom_richtext(
    aes(
      x = altura_max,
      y = n - 2.5,
      label = paste(leyenda$label, collapse = "<br>")
    ),
    family = "Texto",
    size = 5.2,
    colour = suave,
    lineheight = 1.4,
    hjust = 1,
    vjust = 0.5,
    fill = NA,
    label.colour = NA
  ) +
  scale_colour_identity() +
  scale_x_continuous(limits = c(-6, altura_max), expand = c(0, 0)) +
  scale_y_reverse(limits = c(n + 0.5, 0.5), expand = c(0, 0)) +
  coord_cartesian(clip = "off") +
  labs(title = titulo, subtitle = subtitulo, caption = nota) +
  theme_void(base_family = "Texto") +
  theme(
    plot.background = element_rect(fill = fondo, colour = NA),
    plot.margin = margin(30, 30, 20, 30),
    plot.title = element_text(
      family = "Titulo",
      size = 26,
      colour = texto,
      margin = margin(b = 8)
    ),
    plot.subtitle = element_text(
      size = 15,
      colour = suave,
      margin = margin(b = 25)
    ),
    plot.caption = element_textbox_simple(
      size = 10.5,
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
  file.path(carpeta, "grafico.png"),
  grafico,
  device = agg_png,
  width = 8.5,
  height = 10,
  dpi = 135,
  bg = fondo
)
