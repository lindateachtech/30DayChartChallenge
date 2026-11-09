# Crea la carpeta de un día a partir de r/plantilla
# Ejemplo: nuevo_dia(1, "Part-to-Whole")
#          nuevo_dia(3, "Mosaic", edicion = "2027")

nuevo_dia <- function(dia, tema, edicion = "2026") {
  slug <- tolower(iconv(tema, to = "ASCII//TRANSLIT"))
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  carpeta <- file.path(edicion, sprintf("%02d-%s", dia, slug))

  if (dir.exists(carpeta)) stop("Ya existe: ", carpeta)
  dir.create(carpeta, recursive = TRUE)

  for (f in list.files("plantillas/dia", full.names = TRUE)) {
    txt <- readLines(f, encoding = "UTF-8")
    txt <- gsub("{{DIA}}", sprintf("%02d", dia), txt, fixed = TRUE)
    txt <- gsub("{{TEMA}}", tema, txt, fixed = TRUE)
    txt <- gsub("{{CARPETA}}", carpeta, txt, fixed = TRUE)
    writeLines(txt, file.path(carpeta, basename(f)), useBytes = TRUE)
  }

  message("Creada ", carpeta)
  invisible(carpeta)
}
