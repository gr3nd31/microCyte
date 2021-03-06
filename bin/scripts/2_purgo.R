#!/usr/bin/Rscript

args = commandArgs(trailingOnly=TRUE)

# This opens the various packages required for this spell
suppressPackageStartupMessages(library(imager))
suppressPackageStartupMessages(library(magick))
suppressPackageStartupMessages(library(ggplot2))

# This first spell will convert all the tifs to png using the magick functions,
# which is required as an input for the imager functions
abra <- function(){
  if(!"PNGS" %in% list.files()){
    dir.create("PNGS")
  }
  fAll <- list.files(pattern = ".tif")
  if(!"originals" %in% list.files()){
    dir.create("originals")
    file.copy(fAll, "originals")
  }
  for (a in fAll){
    imageName <- substr(a, 0, nchar(a)-4)
    imageItem <- image_read(a)
    image_write(imageItem, path = paste0("PNGS/", imageName, ".png"), format = "png")
    image_write(imageItem, path = paste0(imageName, ".tif"), format = "tif")
  }
}

# This function opens the png files and extracts the grayscaled pixel information,
# 
kadabra <- function(sampleNumber=10000){
  first <- TRUE
  if (!"QC" %in% list.files()){
    dir.create("QC")
  }
  setwd("PNGS")
  fAll <- list.files(pattern = ".png")
  for (a in fAll){
    interim <- load.image(a)
    imageName <- substr(a, 0, nchar(a)-4)
    interim <- as.data.frame(grayscale(interim))
    names(interim)[3] <- imageName
    if (first == TRUE){
      dato <<- interim[,1:3]
      first <- FALSE
    } else {
      dato <<- cbind(dato, interim[,3])
      names(dato)[ncol(dato)] <<- imageName
    }
  }
  setwd("../")
  dato <<- dato[sample(1:nrow(dato), sampleNumber),]
  write.csv(dato, file = "QC/sampledPixels.csv", row.names = F)
}

alakazam <- function(df = "QC/sampledPixels.csv", 
                     color="green", 
                     sampleNumber=10000, 
                     corrCut = 1, 
                     overlapper = "CH3",
                     overlappee = "CH4", 
                     amplification = 2, 
                     breck = 10, 
                     pool = 4){
  dato <- read.csv(df)
  
  overlapper_file <- list.files(pattern = overlapper)[1]
  overlapper <- substr(overlapper_file, 1, nchar(list.files(pattern = overlapper)[1])-4)
  overlappee_file <- list.files(pattern = overlappee)[1]
  overlappee <- substr(overlappee_file, 1, nchar(list.files(pattern = overlappee)[1])-4)
  
  ticky <- match(paste0("X",overlapper), names(dato))
  ricky <- match(paste0("X",overlappee) , names(dato))
  print(ticky)
  print(ricky)
  
  dato <- split(dato, cut(dato[,ticky], breaks = breck))
  for (i in dato[1:4]){
    if (exists("distro")){
      distro <- rbind(distro,
                      head(i[order(i[,ricky]),], n = pool))
    } else {
      distro <- head(i[order(i[,ricky]),], n = pool)
    }
  }
  dato <- read.csv(df)
  lineEQ <- suppressMessages(lm(as.double(unlist(distro[paste0("X",overlappee)]))~as.double(unlist(distro[paste0("X",overlapper)])), data=distro))
  lineCO <- as.numeric(lineEQ$coefficients[2])
  lineIN <- as.numeric(lineEQ$coefficients[1])
  linePV <- summary(lineEQ[[4]][8])
  
  draft <- ggplot(data = dato, 
                  aes(x=as.double(unlist(dato[paste0("X", overlapper)])), 
                      y=as.double(unlist(dato[paste0("X", overlappee)]))))+
    geom_point()+
    theme_classic()+
    ylab(overlappee)+
    xlab(overlapper)+
    geom_abline(intercept = lineIN, slope = lineCO, color = "red", linetype = "dashed", size = 1.5)+
    ggtitle(paste0("Initial correlation: ", round(lineCO, 2), "x + ", round(lineIN, 2), ", p-val = ", linePV))
  suppressMessages(ggsave(paste0("QC/InitialCorr_", overlappee, "x", overlapper, ".png")))

  interim_ee <- as.data.frame(grayscale(load.image(paste0("PNGS/", overlappee, ".png"))))
  interim_er <- as.data.frame(grayscale(load.image(paste0("PNGS/", overlapper, ".png"))))
  names(interim_ee)[3] <- overlappee
  interim <- cbind(interim_ee, interim_er[,3])
  names(interim)[4] <- overlapper
  
  #where the magic hapens
  interim[paste0(overlappee, "_corrected")] <- amplification*(interim[overlappee]-(interim[overlapper]*lineCO))
  interim[paste0(overlappee, "_corrected")] <- interim[paste0(overlappee, "_corrected")]+abs(min(interim[paste0(overlappee, "_corrected")]))
  
  dato <- interim[sample(1:nrow(interim), 10000),]
  write.csv(dato, file = "QC/corrPixels.csv", row.names = F)
  draft <- ggplot(data = dato, 
                  aes(x=as.double(unlist(dato[overlapper])), 
                      y=as.double(unlist(dato[paste0(overlappee, "_corrected")]))))+
    geom_point()+
    theme_classic()+
    ylab(paste0("corrected ", overlappee))+
    xlab(overlapper)+
    geom_abline(intercept = lineIN, slope = lineCO, color = "red", linetype = "dashed", size = 1.5)+
    ggtitle(paste0("Initial correlation: ", round(lineCO, 2), "x + ", round(lineIN, 2), ", p-val = ", linePV))
  suppressMessages(ggsave(paste0("QC/AdjustedCorr_", overlappee, "x", overlapper, ".png")))
  if (color=="green"){
    g <- interim[,1:2]
    g$x <- abs(g$x-(max(g$x)+1))
    g$cc <- 2
    g$value <- interim[,5]
    r <- g
    r$cc <- 1
    r$value <- 0
    b <- g
    b$cc <- 3
    b$value <- 0
  } else if (color == "red"){
    r <- interim[,1:2]
    r$x <- abs(r$x-(max(r$x)+1))
    r$cc <- 1
    r$value <- interim[,5]
    g <- r
    g$cc <- 2
    g$value <- 0
    b <- r
    b$cc <- 3
    b$value <- 0
  } else {
    b <- interim[,1:2]
    b$x <- abs(b$x-(max(b$x)+1))
    b$cc <- 3
    b$value <- interim[,5]
    r <- b
    r$cc <- 1
    r$value <- 0
    g <- b
    g$cc <- 2
    g$value <- 0
  }
  newDat <- rbind(r, g, b)
  newPlot <- suppressWarnings(as.cimg(newDat))
  newPlot <- cimg2magick(newPlot, rotate = T)
  #save.image(newPlot, paste0("PNGS/", overlappee, "_adj.png"))
  image_write(newPlot, path = paste0("PNGS/", overlappee, ".png"), format = "png")
  image_write(newPlot, path = paste0(overlappee, ".tif"), format = "tif")
}

# # test if there is at least one argument and uses the first one: if not, it defaults to the "name" argument
# if (length(args)==0) {
#   runType <- "none"
# } else if (length(args)>0) {
#   runType <- args[1]
# }

 setwd("../../files/")
 dirz <- list.files()
 for (ab in dirz){
   if(!grepl("ijm", ab)){
     setwd(ab)
     filz <- list.files()
     for(bc in filz){
       setwd(bc)
       abra()
       kadabra()
       if(runType == "auto"){
         #alakazam()
       } else if (runType == "manual"){
         alakazam(overlapper = args[2], overlappee = args[3])
       } else if (runType == "full"){
         alakazam(overlapper = "CH1", overlappee = "CH2", color = "red")
         alakazam(overlapper = "CH2", overlappee = "CH3", color = "blue")
         alakazam(overlapper = "CH3", overlappee = "CH4", color = "green")
       }
       setwd("../")
     }
     setwd("../")
   }
 }