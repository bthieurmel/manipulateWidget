#' Dynamically show/hide controls in the UI
#'
#' @param .display expression that evaluates to a named list of boolean
#' @param desc subset of controls$inputs containing only shared inputs and inputs
#'   for the current module
#' @param session shiny session
#' @param env module environment
#'
#' @noRd
showHideControls <- function(.display, desc, session, env) {
  displayBool <- eval(.display, envir = env)
  if (length(displayBool) > 0) {
    for (n in names(displayBool)) {
      inputDesc <- subset(desc, name == n)
      if (nrow(inputDesc) == 1) {
        shiny::updateCheckboxInput(
          session,
          inputId = paste0(inputDesc$inputId, "_visible"),
          value = displayBool[[n]])
      }
    }
  }
}

#' Dynamically set input parameters like choices, minimal or maximal values, etc.
#'
#' @param .updateInputs expression that evaluate to a named list of lists
#' @inheritParams showHideControls
#'
#' @return data.frame 'desc' with updated column params
#' @noRd
updateControls <- function(.updateInputs, desc, session, env) {
  newParams <- eval(.updateInputs, envir = env)

  for (n in names(newParams)) {
    inputDesc <- subset(desc, name == n)
    updateInputFun <- switch(
      inputDesc$type,
      slider = shiny::updateSliderInput,
      text = shiny::updateTextInput,
      numeric = shiny::updateNumericInput,
      password = shiny::updateTextInput,
      select = shiny::updateSelectInput,
      checkbox = shiny::updateCheckboxInput,
      radio = shiny::updateRadioButtons,
      date = shiny::updateDateInput,
      dateRange = shiny::updateDateRangeInput,
      checkboxGroup = shiny::updateCheckboxGroupInput
    )

    # For each parameter, check if its value has changed in order to avoid
    # useless updates of inputs that can be annoying for users. If it has
    # changed, update the corresponding parameter.
    for (p in names(newParams[[n]])) {
      if (identical(newParams[[n]][[p]], desc$params[[1]][[p]])) {
        next
      }
      args <- newParams[[n]][p]
      args$session <- session
      args$inputId <- inputDesc$inputId

      # Special case: update value of select input when choices are modified
      if (p == "choices" & inputDesc$type == "select") {
        actualSelection <- get(n, envir = env)
        if (inputDesc$multiple) {
          args$selected <- intersect(actualSelection, newParams[[n]][[p]])
        } else {
          if (actualSelection %in% newParams[[n]][[p]]) {
            args$selected <- actualSelection
          }
        }
      }
      do.call(updateInputFun, args)

      desc$params[desc$inputId == inputDesc$inputId][[1]][[p]] <-  newParams[[n]][[p]]
    }
  }

  desc
}

#' Function called when user clicks on the "Done" button. It stops the shiny
#' gadget and returns the final htmlwidget
#'
#' @param .expr Expression that generates a htmlwidget
#' @param controls Object created with function preprocessControls
#'
#' @return a htmlwidget
#' @noRd
onDone <- function(.expr, controls) {
  widgets <- lapply(controls$env$ind, function(e) {
    assign(".initial", TRUE, envir = e)
    assign(".session", NULL, envir = e)
    eval(.expr, envir = e)
  })

  shiny::stopApp(mwReturn(widgets))
}

#' Function that takes a list of widgets and returns the first one if there is
#' only one or a combinedWidget with all widgets combined.
#'
#' @param widgets list of htmlwidgets
#'
#' @return a htmlwidget
#' @noRd
mwReturn <- function(widgets) {
  if (length(widgets) == 1) {
    return(widgets[[1]])
  } else {
    return(combineWidgets(list = widgets))
  }
}