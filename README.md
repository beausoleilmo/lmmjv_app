# Read and summarize data

This app will take in a CSV or Excel file and summarize it. You'll have the option to download it after. 

## Building Shinylive (WebAssembly)


```
# Folder ouput 
dir.create("lmmjvR_site", showWarnings = FALSE)

shinylive::export('./app/', destdir = 'lmmjvR_site')
shinylive::export('./app/', destdir = 'lmmjvR_site', assets_version = '0.10.6')

# see the use of another asset version 
# https://github.com/posit-dev/r-shinylive/issues/167

# Test locally
httpuv::runStaticServer("./lmmjvR_site")

```


## Building Docker image 

### Open docker app (or simply the deamon) 
```
docker desktop start

# Robust way to open it up
# open -a Docker; until docker info 2> /dev/null; do sleep 1; done 
```

### Building the app 

NOTE : This will take some time (400s)

```
cd ~/Github_proj/lmmjvR
docker build -t hr_sum --platform linux/amd64 .
```

## Run the app 
```
docker run -p 8080:3838 hr_sum
```

## Then open browser (port 8080)
```
http://localhost:8080 
```

## To stop the deamon 
If needed. 

```
docker desktop stop
```
