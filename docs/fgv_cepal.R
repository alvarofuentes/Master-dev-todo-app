# Implementación FGV (CEPAL) con flujo persona-nivel y salida tidy
# - Estima parámetros (beta_0..beta_3, sigma) desde la misma base.
# - Permite usar parámetros de referencia (Cuadro 4) como fallback opcional.
# - Calcula SE, CV, DEFF, IC95% y banderas de calidad.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(rlang)
  library(purrr)
})

# -----------------------------------------------------------------------------
# 1) Parámetros de referencia (Cuadro 4) - uso opcional/fallback
# -----------------------------------------------------------------------------
parametros_fgv_referencia <- tibble::tibble(
  indicador = c("Pobreza", "Pobreza_extrema", "Desocupacion", "Ocupacion", "Ingreso"),
  beta_0 = c(-5.631, -4.278, -3.764, -5.786, -7.323),
  beta_1 = c(-4.945, -5.545, -5.417, -4.586, 0.00011),
  beta_2 = c(-0.0001566, -0.0006567, -0.0007759, -0.00009845, 0.33113),
  beta_3 = c(0.0002079, 0.0009745, 0.0007812, 0.00009626, -0.06806),
  sigma = c(1.345, 1.224, 0.979, 1.176, 0.7564),
  fuente = "Cuadro4_CEPAL"
)

# -----------------------------------------------------------------------------
# 2) Helper: normalización y n efectivo (no-missing)
# -----------------------------------------------------------------------------
preparar_datos_persona <- function(data,
                                   indicador_var,
                                   desagregaciones = c("sexo", "edad", "area")) {
  req_cols <- c("id_hogar", "id_pers", indicador_var, desagregaciones)
  faltantes <- setdiff(req_cols, names(data))
  if (length(faltantes) > 0) {
    stop(sprintf("Faltan columnas requeridas: %s", paste(faltantes, collapse = ", ")))
  }

  data %>%
    dplyr::select(dplyr::all_of(req_cols)) %>%
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(c(indicador_var, desagregaciones)))))
}

# -----------------------------------------------------------------------------
# 3) Cálculo de estimación y n por dominio (tidy)
# -----------------------------------------------------------------------------
calcular_indicadores_dominios <- function(data,
                                          indicador_var,
                                          desagregaciones = c("sexo", "edad", "area")) {
  data_valid <- preparar_datos_persona(data, indicador_var, desagregaciones)

  data_valid %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(desagregaciones))) %>%
    dplyr::summarise(
      estimacion = mean(.data[[indicador_var]], na.rm = TRUE),
      n = dplyr::n(),
      .groups = "drop"
    )
}

# -----------------------------------------------------------------------------
# 4) Bootstrap para SE empírico por dominio (sin variables de diseño)
# -----------------------------------------------------------------------------
estimar_se_bootstrap_dominios <- function(data,
                                          indicador_var,
                                          desagregaciones = c("sexo", "edad", "area"),
                                          B = 200,
                                          seed = 123) {
  data_valid <- preparar_datos_persona(data, indicador_var, desagregaciones)

  base_dom <- calcular_indicadores_dominios(data_valid, indicador_var, desagregaciones) %>%
    dplyr::mutate(domain_id = dplyr::row_number())

  # mapa dominio -> llaves
  key_cols <- desagregaciones

  set.seed(seed)
  n_total <- nrow(data_valid)

  reps <- vector("list", B)
  for (b in seq_len(B)) {
    idx <- sample.int(n_total, size = n_total, replace = TRUE)
    rep_b <- data_valid[idx, , drop = FALSE] %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) %>%
      dplyr::summarise(theta_rep = mean(.data[[indicador_var]], na.rm = TRUE), .groups = "drop")
    reps[[b]] <- rep_b %>% dplyr::mutate(rep = b)
  }

  reps_long <- dplyr::bind_rows(reps)

  base_dom %>%
    dplyr::left_join(reps_long, by = key_cols) %>%
    dplyr::group_by(domain_id, dplyr::across(dplyr::all_of(key_cols)), estimacion, n) %>%
    dplyr::summarise(se_empirico = stats::sd(theta_rep, na.rm = TRUE), .groups = "drop")
}

# -----------------------------------------------------------------------------
# 5) Estimación de parámetros FGV desde los microdatos
# -----------------------------------------------------------------------------
ajustar_parametros_fgv <- function(data,
                                   indicador_var,
                                   tipo_indicador = "Pobreza",
                                   desagregaciones = c("sexo", "edad", "area"),
                                   modelo = c("LC", "LE"),
                                   B = 200,
                                   seed = 123,
                                   min_dominios = 15) {
  modelo <- match.arg(modelo)

  dom_se <- estimar_se_bootstrap_dominios(
    data = data,
    indicador_var = indicador_var,
    desagregaciones = desagregaciones,
    B = B,
    seed = seed
  ) %>%
    dplyr::filter(is.finite(se_empirico), se_empirico > 0, estimacion > 0)

  if (nrow(dom_se) < min_dominios) {
    stop(sprintf("Dominios válidos insuficientes (%s). Requiere al menos %s.", nrow(dom_se), min_dominios))
  }

  # y = log(SE^2 / theta^2) = Xb + error
  fit_data <- dom_se %>%
    dplyr::mutate(y = log((se_empirico^2) / (estimacion^2)))

  if (modelo == "LC") {
    fit <- stats::lm(y ~ n + estimacion + I(n * estimacion), data = fit_data)
  } else {
    fit <- stats::lm(y ~ n + estimacion + I(n / estimacion), data = fit_data)
  }

  coefs <- stats::coef(fit)
  sigma <- stats::sigma(fit)

  # Mapear siempre a beta_0..beta_3
  if (modelo == "LC") {
    beta_3_name <- "I(n * estimacion)"
  } else {
    beta_3_name <- "I(n/estimacion)"
    if (!beta_3_name %in% names(coefs)) {
      beta_3_name <- "I(n / estimacion)"
    }
  }

  tibble::tibble(
    indicador = tipo_indicador,
    beta_0 = unname(coefs["(Intercept)"]),
    beta_1 = unname(coefs["n"]),
    beta_2 = unname(coefs["estimacion"]),
    beta_3 = unname(coefs[beta_3_name]),
    sigma = sigma,
    modelo = modelo,
    fuente = "estimado_desde_microdatos"
  )
}

# -----------------------------------------------------------------------------
# 6) Función principal: cálculo SE/CV/DEFF/IC/banderas
#    - LE activo por defecto para Ingreso
# -----------------------------------------------------------------------------
calcular_error_fgv <- function(estimacion,
                               n,
                               tipo_indicador,
                               parametros_fgv,
                               nivel_confianza = 0.95,
                               modelo_ingreso = c("LE", "LC")) {
  modelo_ingreso <- match.arg(modelo_ingreso)

  if (!is.numeric(estimacion) || length(estimacion) != 1 || is.na(estimacion)) {
    stop("'estimacion' debe ser numérica, escalar y no NA.")
  }
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n <= 0 || n %% 1 != 0) {
    stop("'n' debe ser entero positivo.")
  }

  fila <- parametros_fgv %>% dplyr::filter(.data$indicador == tipo_indicador)
  if (nrow(fila) != 1) {
    stop("Debe existir exactamente una fila de parámetros para 'tipo_indicador'.")
  }

  beta_0 <- fila$beta_0[[1]]
  beta_1 <- fila$beta_1[[1]]
  beta_2 <- fila$beta_2[[1]]
  beta_3 <- fila$beta_3[[1]]
  sigma <- fila$sigma[[1]]

  delta <- exp((sigma^2) / 2)

  if (tipo_indicador == "Ingreso" && modelo_ingreso == "LE") {
    if (estimacion <= 0) stop("Para LE en Ingreso, 'estimacion' debe ser > 0.")
    predictor <- beta_0 + beta_1 * n + beta_2 * estimacion + beta_3 * (n / estimacion)
  } else {
    predictor <- beta_0 + beta_1 * n + beta_2 * estimacion + beta_3 * n * estimacion
  }

  se <- sqrt(exp(predictor) * delta * estimacion^2)
  cv <- ifelse(estimacion == 0, NA_real_, se / estimacion)

  if (tipo_indicador == "Ingreso") {
    deff <- NA_real_
  } else {
    if (estimacion < 0 || estimacion > 1) {
      stop("Para proporciones, 'estimacion' debe estar entre 0 y 1.")
    }
    var_mas <- (estimacion * (1 - estimacion)) / n
    deff <- ifelse(var_mas == 0, NA_real_, (se^2) / var_mas)
  }

  alfa <- 1 - nivel_confianza
  z <- stats::qnorm(1 - alfa / 2)
  ic_inf <- estimacion - z * se
  ic_sup <- estimacion + z * se

  bandera_calidad <- dplyr::case_when(
    is.na(cv) ~ "No evaluable",
    cv < 0.15 ~ "Alta precisión",
    cv < 0.30 ~ "Precisión moderada",
    TRUE ~ "Baja precisión"
  )

  tibble::tibble(
    indicador = tipo_indicador,
    estimacion = estimacion,
    n = n,
    se_predicho = se,
    cv = cv,
    deff = deff,
    ic_inf = ic_inf,
    ic_sup = ic_sup,
    bandera_calidad = bandera_calidad
  )
}

# -----------------------------------------------------------------------------
# 7) Salida tidy para múltiples dominios
# -----------------------------------------------------------------------------
estimar_fgv_tidy <- function(data,
                             indicador_var,
                             tipo_indicador = "Pobreza",
                             desagregaciones = c("sexo", "edad", "area"),
                             parametros_fgv = NULL,
                             usar_referencia_si_falla = TRUE,
                             modelo = c("LC", "LE"),
                             B = 200,
                             seed = 123,
                             min_dominios = 15,
                             nivel_confianza = 0.95,
                             modelo_ingreso = c("LE", "LC")) {
  modelo <- match.arg(modelo)
  modelo_ingreso <- match.arg(modelo_ingreso)

  base_dom <- calcular_indicadores_dominios(data, indicador_var, desagregaciones)

  if (is.null(parametros_fgv)) {
    parametros_fgv <- tryCatch(
      ajustar_parametros_fgv(
        data = data,
        indicador_var = indicador_var,
        tipo_indicador = tipo_indicador,
        desagregaciones = desagregaciones,
        modelo = modelo,
        B = B,
        seed = seed,
        min_dominios = min_dominios
      ),
      error = function(e) {
        if (!usar_referencia_si_falla) stop(e)
        parametros_fgv_referencia %>%
          dplyr::filter(.data$indicador == tipo_indicador) %>%
          dplyr::mutate(modelo = ifelse(tipo_indicador == "Ingreso", modelo_ingreso, "LC"))
      }
    )
  }

  resultados <- purrr::pmap_dfr(
    list(base_dom$estimacion, base_dom$n),
    function(estimacion_i, n_i) {
      calcular_error_fgv(
        estimacion = estimacion_i,
        n = n_i,
        tipo_indicador = tipo_indicador,
        parametros_fgv = parametros_fgv,
        nivel_confianza = nivel_confianza,
        modelo_ingreso = modelo_ingreso
      )
    }
  )

  dplyr::bind_cols(base_dom %>% dplyr::select(dplyr::all_of(desagregaciones)), resultados) %>%
    dplyr::mutate(
      indicador_var = indicador_var,
      modelo_usado = dplyr::if_else(tipo_indicador == "Ingreso", modelo_ingreso, "LC")
    )
}

# -----------------------------------------------------------------------------
# 8) Base sintética persona-nivel (variables solicitadas)
# -----------------------------------------------------------------------------
generar_base_sintetica <- function(n_hogares = 300, max_personas_hogar = 6, seed = 2026) {
  set.seed(seed)

  personas_hogar <- sample(1:max_personas_hogar, n_hogares, replace = TRUE)
  id_hogar <- rep(seq_len(n_hogares), times = personas_hogar)
  id_pers <- ave(id_hogar, id_hogar, FUN = seq_along)
  n_personas <- length(id_hogar)

  area_hogar <- sample(c("urbana", "rural"), n_hogares, replace = TRUE, prob = c(0.75, 0.25))
  area <- area_hogar[id_hogar]

  sexo <- sample(c("M", "F"), n_personas, replace = TRUE)
  edad <- pmax(0, round(rnorm(n_personas, mean = 33, sd = 18)))

  p_pobreza <- plogis(-1.25 + 0.55 * (area == "rural") + 0.015 * (20 - pmin(edad, 20)))
  pobreza_dummy <- rbinom(n_personas, 1, p_pobreza)

  dplyr::tibble(
    id_hogar = id_hogar,
    id_pers = as.integer(id_pers),
    pobreza_dummy = pobreza_dummy,
    sexo = sexo,
    edad = edad,
    area = area
  )
}

# -----------------------------------------------------------------------------
# 9) Ejemplo de uso end-to-end (tidy)
# -----------------------------------------------------------------------------
# base <- generar_base_sintetica()
# salida <- estimar_fgv_tidy(
#   data = base,
#   indicador_var = "pobreza_dummy",
#   tipo_indicador = "Pobreza",
#   desagregaciones = c("sexo", "area"),
#   modelo = "LC",
#   B = 80,
#   seed = 99
# )
# print(dplyr::glimpse(salida))
