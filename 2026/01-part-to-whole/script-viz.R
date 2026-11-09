# Día 01 - Part-to-Whole
# #30DayChartChallenge
# Diagrama ternario del consumo de cerveza, licor y vino por país

# Paquetes ----------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(glue)
library(fivethirtyeight)
library(countrycode)
library(rcartocolor)
library(ggrepel)
library(ggflags)   # no está en CRAN: remotes::install_github("jimjam-slam/ggflags")
library(ragg)


# Colores y tipografía ----------------------------------------------------
# Subregiones de Europa con colores de CARTO Safe, apta para daltonismo
safe   <- carto_pal(12, "Safe")
paleta <- c(
    "Europa del Norte"  = safe[5],   # índigo
    "Europa Occidental" = safe[7],   # turquesa
    "Europa del Sur"    = safe[9],   # granate
    "Europa del Este"   = safe[8]    # oliva
)

# Tinte suave de cada bebida para el fondo del triángulo
bebida_fondo <- c(cerveza = "#FBF0D0", vino = "#F5DEE3", licor = "#E4EAF1")
color_vino   <- "#8C1C3A"
destacado    <- "grey30"

# Tipografía con serifa para el título, al estilo de un medio.
# Georgia viene con Windows y macOS; si no está, se usa la serifa por defecto
fuente_titulo <- if ("Georgia" %in% systemfonts::system_fonts()$family) "Georgia" else "serif"

# Datos -------------------------------------------------------------------
# Fuente: OMS, Global Information System on Alcohol and Health, 2010,
drinks |> view()

# Preparación -------------------------------------------------------------
# Europa según las regiones de la ONU (ver explorar.R)
europa <- drinks |>
    mutate(
        region    = countrycode(country, "country.name", "un.region.name",
                                custom_match = c(Micronesia = "Oceania")),
        subregion = countrycode(country, "country.name", "un.regionsub.name",
                                custom_match = c(Micronesia = "Micronesia"))
    ) |>
    filter(region == "Europe") |>
    mutate(
        nombre = countrycode(country, "country.name", "cldr.name.es"),
        zona = recode(subregion,
                      "Northern Europe" = "Europa del Norte", "Western Europe" = "Europa Occidental",
                      "Southern Europe" = "Europa del Sur",   "Eastern Europe" = "Europa del Este"),
        zona = factor(zona, levels = names(paleta))
    )

# Proporción de cada bebida sobre el total de raciones de cada país.
# Los países con consumo cero no se pueden situar en el triángulo.
paises <- europa |>
    mutate(total = beer_servings + spirit_servings + wine_servings) |>
    filter(total > 0) |>
    mutate(
        cerveza = beer_servings / total,
        licor   = spirit_servings / total,
        vino    = wine_servings / total,
        dominante = case_when(
            cerveza >= licor & cerveza >= vino ~ "cerveza",
            licor >= vino ~ "licor",
            TRUE ~ "vino"
        )
    )


# Coordenadas del triángulo
# Esquinas: cerveza abajo a la izquierda, vino abajo a la derecha, licor arriba
h <- sqrt(3) / 2
paises <- paises |> mutate(x = vino + licor / 2, y = licor * h)

# Cifras para el texto, calculadas a partir de los datos
n_bebida <- count(paises, dominante) |> deframe()

pct <- function(x) paste0(round(x * 100), " %")   # espacio que no se parte entre número y %
esp <- filter(paises, country == "Spain")

# Une una lista de nombres con comas y una y final
enumera_y <- function(x) {
    if (length(x) <= 1) return(x)
    paste(paste(head(x, -1), collapse = ", "), "y", tail(x, 1))
}

# Rejilla y ejes del triángulo --------------------------------------------
niveles <- c(0.2, 0.4, 0.6, 0.8)
rejilla <- bind_rows(
    # cerveza constante, paralela al lado vino-licor
    tibble(x = 1 - niveles, y = 0, xend = (1 - niveles) / 2, yend = (1 - niveles) * h),
    # licor constante, horizontal
    tibble(x = niveles / 2, y = niveles * h, xend = 1 - niveles / 2, yend = niveles * h),
    # vino constante, paralela al lado cerveza-licor
    tibble(x = niveles, y = 0, xend = niveles + (1 - niveles) / 2, yend = (1 - niveles) * h)
)

borde <- tibble(x = c(0, 1, 0.5, 0), y = c(0, 0, h, 0))

marcas <- bind_rows(
    tibble(eje = "cerveza", x = 1 - niveles + 0.02, y = -0.035, lab = pct(niveles), ang = -60),
    tibble(eje = "licor",   x = niveles / 2 - 0.035, y = niveles * h, lab = pct(niveles), ang = 0),
    tibble(eje = "vino",    x = niveles + (1 - niveles) / 2 + 0.02, y = (1 - niveles) * h + 0.035,
           lab = pct(niveles), ang = 60)
)

# Zonas del triángulo según qué bebida gana. Las líneas que van del centro
# a la mitad de cada lado separan las tres zonas
centro <- c(0.5, h / 3)
zonas_bebida <- bind_rows(
    tibble(bebida = "cerveza", x = c(0, 0.5, centro[1], 0.25), y = c(0, 0, centro[2], h / 2)),
    tibble(bebida = "vino",    x = c(1, 0.75, centro[1], 0.5), y = c(0, h / 2, centro[2], 0)),
    tibble(bebida = "licor",   x = c(0.5, 0.25, centro[1], 0.75), y = c(h, h / 2, centro[2], h / 2))
) |>
    mutate(relleno = bebida_fondo[bebida])

# Iconos de las esquinas: Twemoji (CC BY 4.0), guardados en la carpeta iconos
icono <- function(bebida) {
    glue("<img src='{file.path('2026/01-part-to-whole/iconos', paste0(bebida, '.png'))}' width='30'/>")
}
iconos <- tibble(
    x   = c(-0.075, 1.075, 0.5),
    y   = c(0.03, 0.03, h + 0.085),
    lab = map_chr(c("cerveza", "vino", "licor"), icono)
)

# Líneas de lectura para España: desde el punto hasta cada lado
lectura <- tibble(
    x    = esp$x, y = esp$y,
    xend = c(esp$x + esp$y / (2 * h),          # cerveza, baja hasta el lado inferior
             esp$licor / 2,                    # licor, horizontal hasta el lado izquierdo
             esp$vino + (1 - esp$vino) / 2),   # vino, sube hasta el lado derecho
    yend = c(0, esp$y, (1 - esp$vino) * h)
)

# Valor de España donde cada línea toca su lado
lectura_lab <- tibble(
    eje = c("cerveza", "licor", "vino"),
    x   = c(lectura$xend[1] + 0.02, lectura$xend[2] - 0.035, lectura$xend[3] + 0.02),
    y   = c(-0.035, lectura$yend[2], lectura$yend[3] + 0.035),
    lab = pct(c(esp$cerveza, esp$licor, esp$vino)),
    ang = c(-60, 0, 60)
)

# Quitamos las marcas grises que tienen el mismo valor que España en ese eje
marcas <- anti_join(marcas, lectura_lab, by = c("eje", "lab"))

# Nombre de cada eje a lo largo de su lado
ejes <- tibble(
    x   = c(0.5, 0.17, 0.83),
    y   = c(-0.075, 0.5 * h + 0.05, 0.5 * h + 0.05),
    lab = c("% de cerveza", "% de licor", "% de vino"),
    ang = c(0, 60, -60)
)

# Países con nombre en el gráfico. El resto lleva etiqueta vacía para que
# ggrepel también aparte los nombres de sus puntos
paises <- paises |>
    mutate(etiqueta = if_else(country %in% c(
        "Italy", "France", "Portugal", "Switzerland", "Denmark", "Greece",
        "Bosnia-Herzegovina", "Belarus", "Moldova", "Russian Federation", "Ukraine",
        "Iceland", "Poland", "Czech Republic", "Germany", "Ireland", "United Kingdom"
    ), nombre, ""))

# Leyenda dibujada dentro del gráfico, en el hueco de arriba a la derecha
leyenda <- tibble(zona = factor(names(paleta), levels = names(paleta))) |>
    mutate(x = 0.80, y = h - 0.02 - (row_number() - 1) * 0.05, lab = zona)

# Textos ------------------------------------------------------------------
titulo <- "Dime dónde vives y te diré qué bebes"
subtitulo <- glue(
    "La cerveza es la bebida principal en {n_bebida['cerveza']} de {nrow(paises)} países europeos, ",
    "España incluida. El <span style='color:{color_vino}'>**vino**</span> manda en {n_bebida['vino']}, ",
    "sobre todo en el sur y el oeste, y el licor en {n_bebida['licor']}, todos en el este y los Balcanes."
)
nota <- glue(
    "Países de Europa según las subregiones de la ONU. El tamaño del punto indica el total de raciones ",
    "por persona. ",
    "Iconos de Twemoji (CC BY 4.0). ",
    "Datos OMS 2010 vía FiveThirtyEight · #30DayChartChallenge Día 01 Part-to-Whole · Linda Cabrera Orellana"
)

# Gráfico -----------------------------------------------------------------
grafico <- ggplot() +
    # fondo según la bebida que gana y rejilla suave encima
    geom_polygon(data = zonas_bebida, aes(x, y, group = bebida, fill = relleno), colour = NA) +
    geom_segment(data = rejilla, aes(x, y, xend = xend, yend = yend),
                 colour = "white", linewidth = 0.6) +
    geom_path(data = borde, aes(x, y), colour = "grey40", linewidth = 0.4) +
    geom_text(data = marcas, aes(x, y, label = lab, angle = ang),
              size = 2.8, colour = "grey55") +
    geom_text(data = ejes, aes(x, y, label = lab, angle = ang), size = 3, colour = "grey45") +
    # iconos y nombres de las esquinas
    geom_richtext(data = iconos, aes(x, y, label = lab),
                  fill = NA, label.colour = NA, label.padding = unit(0, "pt")) +
    # países
    geom_point(data = paises, aes(x, y, size = total, colour = zona), alpha = 0.6, stroke = 0) +
    geom_segment(data = lectura, aes(x, y, xend = xend, yend = yend),
                 colour = destacado, linetype = "22", linewidth = 0.45) +
    geom_text(data = lectura_lab, aes(x, y, label = lab, angle = ang),
              size = 2.8, colour = destacado, fontface = "bold") +
    geom_flag(data = esp, aes(x, y, country = "es"), size = 10) +
    geom_text_repel(data = paises, aes(x, y, label = etiqueta),
                    size = 3.1, colour = "grey30", seed = 1,
                    bg.colour = "white", bg.r = 0.15,
                    box.padding = 0.4, point.padding = 0.2, min.segment.length = 0.2,
                    segment.colour = "grey60", segment.size = 0.3, max.overlaps = Inf) +
    # leyenda
    scale_colour_manual(values = paleta, name = NULL,
                        guide = guide_legend(override.aes = list(size = 4, alpha = 1))) +
    scale_fill_identity() +   # los rellenos ya son códigos de color
    scale_size_area(max_size = 10, guide = "none") +
    coord_equal(xlim = c(-0.12, 1.12), ylim = c(-0.1, h + 0.13), clip = "off") +
    labs(title = titulo, subtitle = subtitulo, caption = nota) +
    theme_void(base_size = 13) +
    theme(
        plot.background = element_rect(fill = "white", colour = NA),
        plot.margin = margin(25, 30, 20, 30),
        plot.title = element_text(family = fuente_titulo, face = "bold", size = 29,
                                      colour = "grey10", margin = margin(b = 15)),
        plot.subtitle = element_textbox_simple(size = 14, colour = "grey30",
                                               lineheight = 1.25, margin = margin(t= 5, b = 15)),
        plot.caption = element_textbox_simple(size = 9, colour = "grey50",
                                              lineheight = 1.3, margin = margin(t = 5)),
        plot.title.position = "plot",
        plot.caption.position = "plot",
        legend.position = "top",
        legend.direction = "horizontal",
        legend.text = element_text(size = 11, colour = "grey30"),
        legend.margin = margin(t = 5)
    )

grafico

# Guardar -----------------------------------------------------------------
# 1080 x 1350 px, formato vertical 4:5 que funciona bien en LinkedIn.
# Se usa ragg para que encuentre las fuentes del sistema (como Georgia) en cualquier ordenador
#ggsave("2026/01-part-to-whole/grafico.png", grafico, device = agg_png,
#       width = 9, height = 10, dpi = 135, bg = "white")

