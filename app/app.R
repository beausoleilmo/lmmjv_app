### 
## NO SECRETS OR TOKEN Should be in the script 
### 

# Set libraries -----------------------------------------------------------
# Don't forget to add them in the Dockerfile
library(shiny, quietly = TRUE)
library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(readxl, quietly = TRUE)
library(readr, quietly = TRUE)
# library(writexl)
library(glue, quietly = TRUE)
# library(ggplot2)
# library(munsell) # Needed for shinylive... dependency from ggplot2


# Workaround for Chromium Issue 468227
# Need this to properly download the csv file
# this bug and workaround is only for shinylive, you do not need it in your regular app
# Replaces : shiny::downloadButton()
downloadButton_fix <- function(...) {
  tag <- shiny::downloadButton(...)
  tag$attribs$download <- NULL
  tag
}

# Required column names
# Check if required columns exist
required_cols <- c("category", "New_taches_Monday", "hr")

# Bold text 
# text_with_bold <- glue("<strong>{required_cols[1]}</strong>, <strong>{required_cols[2]}</strong> et <strong>{required_cols[3]}</strong>.")

# UI Logic
ui <- shiny::fluidPage(
  
  # Page title 
  shiny::titlePanel("Habitat - hR: sommaire heures clockify et tâches Monday"),
  
  # Page layout
  shiny::sidebarLayout(
    
    # Left side 
    shiny::sidebarPanel(
      width = 3,
      
      # ******************************************************************
      # Section : Utilisation
      tags$h4("Utilisation"), # Apply an HTML tag to text 
      p("Cette application faire un sommaire d'heures."),
      h4("Prérequis"),
      p("Le fichier d'entré doit avoir les colonnes : "),
      # Add the columns names automagically 
      tags$ul(
        tags$li( tags$strong( glue("{required_cols[1]}") ) ),
        tags$li( tags$strong( glue("{required_cols[2]}") ) ),
        tags$li( tags$strong( glue("{required_cols[3]}") ) )
      ),
      
      # Add horizontal line
      HTML("<hr style=\"border: 1px solid	#C8C8C8; width: 100%;\">"),
      
      
      # ******************************************************************
      # Section : importation 
      tags$h4("Importation"), # Apply an HTML tag to text 
      shiny::fileInput(inputId = "upload", # Will be used in the server 
                       label = "Téléverser un fichier CSV ou Excel", 
                       accept = c(".csv", ".xlsx", ".xls")),
      
      # shiny::hr(), # HTML tag from htmltools via shiny
      
      # Add horizontal line
      HTML("<hr style=\"border: 1px solid	#C8C8C8; width: 100%;\">"),
      
      # ******************************************************************
      # Section : autres paramètres
      tags$h4("Paramètres de modulation"), # Apply an HTML tag to text 
      shiny::numericInput(inputId = "price", label = "Prix ($) :", value = 0),
      
      # ******************************************************************
      # Section : exportation 
      tags$h4("Paramètres d'exportation"), # Apply an HTML tag to text 
      ## Selection of Export type 
      shiny::radioButtons("file_type", "Sélectionner le format d'exportation:",
                          choices = c("CSV" = ".csv"#, 
                                      # "Excel" = ".xlsx"
                          )
      ),
      # Download button 
      downloadButton_fix(
        outputId = "download_data", 
        label = "Télécharger le sommaire")
    ), # End sidebarPanel 
    
    # Main page 
    mainPanel(
      # Make 2 tabs 
      tabsetPanel(
        tabPanel(title = "Sommaire", tableOutput("summary_table")),
        # tabPanel(title = "Graph sommaire", plotOutput("ggplot_summ")),
        # tabPanel(title = "Données brutes", tableOutput("raw_data"))
      )
    )
  )
)

# Server Logic
server <- function(input, output) {
  
  # 1. Reactive expression to read the uploaded file
  uploaded_data <- shiny::reactive({
    # From the input by the user 
    req(input$upload)
    
    # Get file extention 
    ext <- tools::file_ext(input$upload$name)
    
    # Read CONDITIONNALY from the input file extention
    df <- switch(EXPR = ext,
                 csv = {
                   # Check if the file is likely a CSV2 (semicolon-separated) or a standard CSV
                   # You might need to adjust this logic based on expected user files
                   if (any(grepl(";", readLines(input$upload$datapath, n = 5)))) {
                     read.csv2(input$upload$datapath)
                   } else {
                     read.csv(input$upload$datapath)
                   }
                 },
                 xlsx = read_excel(input$upload$datapath),
                 xls = read_excel(input$upload$datapath),
                 validate("Fichier invalide; S.V.P., le fichier doit être .csv ou .xlsx")
    )
    
    # Validation 
    if (!all(required_cols %in% colnames(df))) {
      validate(paste("Error: File must contain columns:", paste(required_cols, collapse = ", ")))
    }
    # Return the data frame read 
    return(df)
  }) # End reactive 
  
  # 2. Reactive expression to process the summary
  summary_df <- shiny::reactive({
    # From the imported dataset 
    req(uploaded_data(),input$price)
    
    # Summarize the data 
    uploaded_data()  |> 
      group_by(category,
               New_taches_Monday) |> 
      summarise(.groups = 'drop',
                across(hr, 
                       list(min = min, 
                            q25 = ~quantile(., 0.25),
                            median = median,
                            q75 = ~quantile(., 0.75), 
                            max = max, 
                            mean = mean, 
                            sd  = sd, 
                            sum = sum, 
                            nb = ~n())
                )
      ) |> 
      mutate(prix = hr_sum*input$price)
  })
  
  # 3. Output the tables
  # output$raw_data <- renderTable({
  #   uploaded_data() # Show first 10 rows with head(uploaded_data(), 10))
  # })
  
  output$summary_table <- shiny::renderTable({
    summary_df()
  })
  
  # Render plot 
  # output$ggplot_summ = renderPlot({
  #   summary_df() |>
  #     filter(!is.na(category)) |> 
  #     ggplot() + 
  #     geom_point(
  #       mapping = aes(
  #         x = New_taches_Monday, 
  #                              y = hr_sum)
  #       ) +
  #     facet_grid(.~category, scales = 'free_x') + 
  #     theme(axis.text.x = element_text(vjust = 0.25, hjust = 1,
  #                                      angle = 90)) +
  #     theme_minimal()
  # })
  
  # 4. Handle Download
  output$download_data <- shiny::downloadHandler(
    filename = function() {
      sprintf("somm_hrs_gr-%s%s",Sys.Date(), input$file_type)
    },
    content = function(file) {
      if (input$file_type == ".csv") {
        readr::write_excel_csv(
          x = summary_df(), 
          file = file)
      } #else {
      #writexl::write_xlsx(summary_df(), file)
      #}
    }
  )
}

# Run 
shinyApp(ui, server)
