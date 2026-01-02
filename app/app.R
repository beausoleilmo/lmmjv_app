### 
## NO SECRETS OR TOKEN Should be in the script 
### 

# BUILDING Shinylive 
# shinylive::export('~/Github_proj/lmmjvR/', destdir = '~/Desktop//lmmjvR_site')
# shinylive::export('~/Github_proj/lmmjvR/', destdir = '~/Desktop//lmmjvR_site', assets_version = '0.10.6')
# see the use of another asset version 
# https://github.com/posit-dev/r-shinylive/issues/167
# Test locally
# httpuv::runStaticServer("~/Desktop//lmmjvR_site")
 
# Set libraries -----------------------------------------------------------
# Don't forget to add them in the Dockerfile
library(shiny)
library(dplyr)
library(readxl)
library(readr)
# library(writexl)
library(glue)
# library(ggplot2)
# library(munsell) # Needed for shinylive... dependency from ggplot2


# Required column names
cols = c("category",
         "New_taches_Monday", 
         "hr")

# Bold text 
text_with_bold <- glue("Cette application prend un fichier 
                d'heures avec les colonnes <strong>{cols[1]}</strong>, 
                <strong>{cols[2]}</strong> et <strong>{cols[3]}</strong>. 
                Le sommaire des heures est calculé dans l'onglet 'Sommaire'.
                l'onglet 'Graph sommaire' fait un graphique avec les données synthétisées et 
                l'onglet 'Données brutes' permet de visualiser les données.
                ")
# UI Logic
ui <- shiny::fluidPage(
  
  # Page title 
  shiny::titlePanel("Habitat - hR: sommaire heures clockify et tâches Monday"),
  
  # Page layout
  shiny::sidebarLayout(
    
    # Left side 
    shiny::sidebarPanel(
      width = 3,
      
      tags$h4("Utilisation :"), # Apply an HTML tag to text 
      
      # Add a paragraph of text
      p(
      # Use the HTML() function to tell Shiny to render the raw HTML string
        HTML(text_with_bold)
        ),

      shiny::hr(), # HTML tag from htmltools via shiny
      
      tags$h4("Importation :"), # Apply an HTML tag to text 
      # Section : importation 
      shiny::fileInput(inputId = "upload", # Will be used in the server 
                label = "Téléverser un fichier CSV ou Excel", 
                accept = c(".csv", ".xlsx", ".xls")),
      
      shiny::hr(), # HTML tag from htmltools via shiny
      
      # Section : autres paramètres
      tags$h4("Paramètres de modulation"), # Apply an HTML tag to text 
      shiny::numericInput(inputId = "price", label = "Prix ($) :", value = 0),
      
      # Section : exportation 
      tags$h4("Paramètres d'exportation"), # Apply an HTML tag to text 
      ## Selection of Export type 
      shiny::radioButtons("file_type", "Sélectionner le format d'exportation:",
                   choices = c("CSV" = ".csv"#, 
                               # "Excel" = ".xlsx"
                   )
      ),
      # Download button 
      shiny::downloadButton(outputId = "download_data", 
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
                 csv = read.csv(input$upload$datapath),
                 xlsx = read_excel(input$upload$datapath),
                 xls = read_excel(input$upload$datapath),
                 validate("Fichier invalide; S.V.P., le fichier doit être .csv ou .xlsx")
    )
    
    # Check if required columns exist
    required_cols <- c("category", "New_taches_Monday", "hr")
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
        readr::write_excel_csv(x = summary_df(), 
                               file = file)
      } #else {
        #writexl::write_xlsx(summary_df(), file)
      #}
    }
  )
}

# Run 
shinyApp(ui, server)
