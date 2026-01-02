# --- STAGE 1: The Builder ---
# We use this stage to download and prepare the R packages.
FROM rocker/r-ver:4.3.3 AS builder

# 1. Install dev-level system dependencies needed to compile/install R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install R packages using Posit binaries
ENV R_REPOS=https://packagemanager.posit.co/cran/__linux__/jammy/latest
RUN R -e "install.packages(c('shiny', 'readxl', 'readr', 'dplyr', 'glue'), repos='${R_REPOS}')"
# Removed these packages 
# 'writexl', 'ggplot2'

# 3. ADVANCED: Strip debugging symbols from the installed packages to save ~10-20% more space
RUN find /usr/local/lib/R/site-library -name "*.so" -exec strip --strip-debug {} \;


# --- STAGE 2: The Final Runtime ---
# This is the image that actually gets deployed.
FROM rocker/r-ver:4.3.3

# 1. Install ONLY the runtime versions of libraries (no -dev headers)
# We also install Shiny Server here so it sets up the 'shiny' user automatically
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gdebi-core \
    wget \
    ca-certificates \
    libcurl4 \
    libcairo2 \
    libxt6 \
    libssl3 \
    libxml2 \
    && wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb \
    && gdebi -n shiny-server-1.5.21.1012-amd64.deb \
    && rm shiny-server-1.5.21.1012-amd64.deb \
    && apt-get purge -y gdebi-core wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the finished R library from the builder stage
# This brings over the packages but NOT the build-logs or temp files
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# 3. Copy your app files
COPY ./app /srv/shiny-server/

# 4. Final configuration
EXPOSE 3838
RUN chown -R shiny:shiny /srv/shiny-server
CMD ["/usr/bin/shiny-server"]