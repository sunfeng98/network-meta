network.rjags <- function(network){

  response <- network$response
  
  code <- paste0("model\n{")
  code2 <- if(response == "binomial"){
    model.binomial(network)
  } else if(response == "normal"){
    model.normal(network)
  } else if(response == "multinomial"){
    model.multinomial(network)
  }
  code <- paste0(code, code2, "\n}")
}

############################################## Functions for normal and binomial
################################################################################

model.normal <- function(network){
  
  with(network, {
  
  code <- paste0(
    "\n\tfor (i in 1:", nstudy, ") {",
    "\n\t\tw[i,1] <- 0",
    "\n\t\tdelta[i,1] <- 0")
  
  code <- paste0(code, baseline.risk.rjags(baseline.risk, ntreat, hy.prior.Eta))
  
  code <- paste0(code, 
    "\n\t\tfor(k in 1:na[i]){",
    "\n\t\t\ttau[i,k] <- 1/pow(se[i,k],2)",
    "\n\t\t\tr[i,k] ~ dnorm(theta[i,k], tau[i,k])") 

  if(type == "fixed"){
    code <- paste0(code, "\n\t\t\ttheta[i,k] <- Eta[i] + d[t[i,k]] - d[t[i,1]]")
  } else{
    code <- paste0(code, "\n\t\t\ttheta[i,k] <- Eta[i] + delta[i,k]")
  }

  if(dic == TRUE){
    code <- paste0(code, "\n\t\t\tdev[i,k] <- (r[i,k]-theta[i,k])*(r[i,k]-theta[i,k])*tau[i,k]")
  }
  code <- paste0(code, "\n\t\t}")

  if(dic == TRUE){
    code <- paste0(code, "\n\t\tresdev[i] <- sum(dev[i,1:na[i]])")
  }

  if(type == "random"){
    code <- paste0(code, "\n\t\tfor(k in 2:na[i]){",
      "\n\t\t\tdelta[i,k] ~ dnorm(md[i,k],precd[i,k])",
      "\n\t\t\tmd[i,k] <- d[t[i,k]] - d[t[i,1]] + sw[i,k]")
    
    if(baseline != "none"){
      code <- paste0(code, " + (b_bl[t[i,k]] - b_bl[t[i,1]]) * (Eta[i] - mx_bl)")
    }
    
    if(!is.null(covariate)){
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, " + (beta", i, "[t[i,k]]- beta", i, "[t[i,1]]) * (x", i, "[i]-mx", i, ")")
      }
    }
    
    code <- paste0(code, "\n\t\t\tprecd[i,k] <- prec *2*(k-1)/k",
      "\n\t\t\tw[i,k] <- (delta[i,k] - d[t[i,k]] + d[t[i,1]])")
    
    if(baseline != "none"){
      code <- paste0(code, " - (b_bl[t[i,k]] - b_bl[t[i,1]]) * (Eta[i] - mx_bl)")
    }
    
    if(!is.null(covariate)){
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, " - (beta", i, "[t[i,k]]- beta", i, "[t[i,1]]) * (x", i, "[i]-mx", i, ")")
      }
    }
    
    code <- paste0(code, 
      "\n\t\t\tsw[i,k] <- sum(w[i,1:(k-1)])/(k-1)",
      "\n\t\t}",
      "\n\t}")
    
  } else if(type == "fixed"){
    code <- paste0(code, "\n\t}")
  }

  if(dic == TRUE){
    code <- paste0(code, "\n\ttotresdev <- sum(resdev[])")
  }
  code <- paste0(code, "\n\td[1] <- 0",
    "\n\tfor(k in 2:", ntreat, "){",
    "\n\t\td[k] ~ dnorm(mean.d,prec.d)",
    "\n\t}")

  if(baseline != "none"){
    code <- paste0(code, baseline.rjags(baseline, ntreat, hy.prior.bl))
  }
  if(!is.null(covariate)){
    code <- paste0(code, covariate.rjags(covariate, covariate.model, ntreat, hy.prior.cov))
  }
  if(type == "random"){
    code <- paste0(code, hy.prior.rjags(hy.prior, 0), rank.rjags(rank.preference, ntreat))
  } else if(type == "fixed"){
    code <- paste0(code, rank.rjags(rank.preference, ntreat))
  }
  return(code)
  })
}

model.binomial <- function(network)
{
  with(network, {

  code <- baseline.risk.rjags(network)
    
  code <- paste0(code, 
    "\n\tfor (i in 1:", nstudy, ") {",
    "\n\t\tw[i,1] <- 0",
    "\n\t\tdelta[i,1] <- 0",
    "\n\t\tfor(k in 1:na[i]){",
    "\n\t\t\tr[i,k] ~ dbin(p[i,k],n[i,k])")

  if(type == "fixed"){
    code <- paste0(code, "\n\t\t\tlogit(p[i,k]) <- Eta[i] + d[t[i,k]] - d[t[i,1]]")
  } else if(type == "random"){
    code <- paste0(code, "\n\t\t\tlogit(p[i,k]) <- Eta[i] + delta[i,k]")
  }

  if(dic == TRUE){
    code <- paste0(code,
      "\n\t\t\trhat[i,k] <- p[i,k] * n[i,k]",
      "\n\t\t\tdev[i,k] <- 2 * (r[i,k] * (log(r[i,k])-log(rhat[i,k])) + (n[i,k]-r[i,k])*(log(n[i,k]-r[i,k]) - log(n[i,k]-rhat[i,k])))",
      "\n\t\t}",
      "\n\t\tresdev[i] <- sum(dev[i,1:na[i]])")
  } else{
    code <- paste0(code, "\n\t\t}")
  }

  if(type == "random"){
    code <- paste0(code,
      "\n\t\tfor(k in 2:na[i]){",
      "\n\t\t\tdelta[i,k] ~ dnorm(md[i,k],precd[i,k])",
      "\n\t\t\tmd[i,k] <- d[t[i,k]] - d[t[i,1]] + sw[i,k]")
    
    if(baseline != "none"){
      code <- paste0(code, " + (b_bl[t[i,k]] - b_bl[t[i,1]]) * (Eta[i] - mx_bl)")
    }
    if(!is.null(covariate)){
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, " + (beta", i, "[t[i,k]]- beta", i, "[t[i,1]]) * (x", i, "[i]-mx", i, ")")
      }
    }
      
    code <- paste0(code, 
      "\n\t\t\tprecd[i,k] <- prec *2*(k-1)/k",
      "\n\t\t\tw[i,k] <- (delta[i,k] - d[t[i,k]] + d[t[i,1]])")
    
    if(baseline != "none"){
      code <- paste0(code, " - (b_bl[t[i,k]] - b_bl[t[i,1]]) * (Eta[i] - mx_bl)")
    }
    if(!is.null(covariate)){
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, " - (beta", i, "[t[i,k]]- beta", i, "[t[i,1]]) * (x", i, "[i]-mx", i, ")")
      }
    } 
      
    code <- paste0(code,   
      "\n\t\t\tsw[i,k] <- sum(w[i,1:(k-1)])/(k-1)",
      "\n\t\t}",
      "\n\t}")
    
  } else if (type == "fixed"){
    code <- paste0(code, "\n\t}")
  }
  if(dic == TRUE){
    code <- paste0(code, "\n\ttotresdev <- sum(resdev[])")
  }

  code <- paste0(code,
    "\n\td[1] <- 0",
    "\n\tfor(k in 2:", ntreat, "){",
    "\n\t\td[k] ~ dnorm(mean.d,prec.d)",
    "\n\t}")

  if(baseline != "none"){
    code <- paste0(code, baseline.rjags(baseline, ntreat, hy.prior.bl))
  }

  if(!is.null(covariate)){
    code <- paste0(code, covariate.rjags(covariate, covariate.model, ntreat, hy.prior.cov))
  }

  if(type == "random"){
    code <- paste0(code, hy.prior.rjags(hy.prior, 0), rank.rjags(rank.preference, ntreat))
  } else if(type == "fixed"){
    code <- paste0(code, rank.rjags(rank.preference, ntreat))
  }
  return(code)
  })
}

baseline.risk.rjags <- function(network){
  
  with(network, {
    code <- paste0("\n\tfor (i in 1:", nstudy, ") {")
    if(baseline.risk == "independent"){
      code <- paste0(code, 
                     "\n\t\tEta[i] ~ dnorm(mean.Eta, prec.Eta)")
    } else if(baseline.risk == "exchangeable"){
      code <- paste0(code, 
                     "\n\t\tEta[i] ~ dnorm(E, precE)")
                     
    }
    code <- paste0(code, "\n\t}")
    
    if(baseline.risk == "exchangeable"){
      code <- paste0(code,
                     "\n\tE ~ dnorm(mean.Eta, prec.Eta)",
                     hy.prior.Eta.rjags(hy.prior.Eta, 0))
    }
    return(code)  
  })
}


baseline.rjags <- function(baseline, ntreat, hy.prior.bl){

  code <- "\n\tb_bl[1] <- 0"
  if(baseline == "common"){
    code <- paste0(code,
                   "\n\tfor(k in 2:", ntreat, "){",
                   "\n\t\tb_bl[k] <- B",
                   "\n\t}",
                   "\n\tB ~ dnorm(mean.bl, prec.bl)")
  } else if(baseline == "independent"){
    code <- paste0(code,
                   "\n\tfor(k in 2:", ntreat, "){",
                   "\n\t\tb_bl[k] ~ dnorm(mean.bl, prec.bl)",
                   "\n\t}")
  } else if(baseline == "exchangeable"){
    code <- paste0(code,
                   "\n\tfor(k in 2:", ntreat, "){",
                   "\n\t\tb_bl[k] ~ dnorm(B, precB)",
                   "\n\t}",
                   "\n\tB ~ dnorm(mean.bl, prec.bl)",
                   hy.prior.bl.rjags(hy.prior.bl, 0))
  }
  return(code)
}

covariate.rjags <- function(covariate, covariate.model, ntreat, hy.prior.cov){

  code <- ""
  for(i in 1:dim(covariate)[2]){
    code <- paste0(code, "\n\tbeta", i, "[1] <- 0")
  }

  code <- paste0(code, "\n\tfor(k in 2:", ntreat, "){")
  if(covariate.model == "independent"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, "\n\t\tbeta", i, "[k] ~ dnorm(mean.cov,prec.cov)")
    }
    code <- paste0(code, "\n\t}")
  } else if(covariate.model == "common"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, "\n\t\tbeta", i, "[k] <- ", paste0("C", i))
    }
    code <- paste0(code, "\n\t}")
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, "\n\t", paste0("C",i), " ~ dnorm(mean.cov, prec.cov)")
    }
  } else if(covariate.model == "exchangeable"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, "\n\t\tbeta", i, "[k] ~ dnorm(", paste0("C", i), ",", paste0("precC", i), ")")
    }
    code <- paste0(code, "\n\t}")
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, "\n\t", paste0("C",i), " ~ dnorm(mean.cov, prec.cov)")
    }
    code <- paste0(code, hy.prior.cov.rjags(hy.prior.cov, covariate, 0))
  }
  return(code)
}


################################################## Functions for multinomial distribution
#########################################################################################

model.multinomial.complete <- function(network){

  with(network, {
    
  code <- paste0(
    "\n\tfor (i in 1:",nstudy,") {",
    "\n\t\tfor (k in 1:na[i]) {",
    "\n\t\t\tr[i,k,1:", ncat, "] ~ dmulti(p[i,k,], n[i,k])",
    "\n\t\t\tfor(m in 1:", ncat, ") {",
    "\n\t\t\t\tp[i,k,m] <- theta[i,k,m]/sum(theta[i,k,])",
    "\n\t\t\t\tlog(theta[i,k,m]) <- Eta[i,m] + delta[i,k,m]")

  if(dic == TRUE){
    code <- paste0(code,
              "\n\t\t\t\trhat[i,k,m] <- p[i,k,m]*n[i,k]",
              "\n\t\t\t\tdv[i,k,m] <- 2*r[i,k,m]*log(r[i,k,m]/rhat[i,k,m])",
              "\n\t\t\t}",
              "\n\t\t\tdev[i,k] <- sum(dv[i,k,])",
              "\n\t\t}",
              "\n\t\tresdev[i] <- sum(dev[i,na[i]])",
              "\n\t}",
              "\n\ttotresdev <- sum(resdev[])")
  }else{
    code <- paste0(code,
              "\n\t\t\t}",
              "\n\t\t}",
              "\n\t}")
  }
  return(code)
  })
}

model.multinomial.incomplete <- function(network)
{
  with(network, {

  npattern = length(miss.patterns[[1]]) # number of missing patterns
  nobs = integer(npattern)
  for(i in seq(npattern)){
    nobs[i] <- length(unique(miss.patterns[[1]][[i]][[1]]))  # number of studies in ith pattern
  }

  code <- ""
  for(i in seq(npattern)){
    code <- paste0(code, "\n\tfor (i in 1:", nobs[i],") {")
    if (i==1){
      code <- paste0(code, "\n\t\tfor (k in 1:na[i]){")
    }else{
      code <- paste0(code, "\n\t\tfor (k in 1:na[i+", cumsum(nobs)[i-1], "]){")
    }

    nprobs <- length(miss.patterns[[1]][[i]][[2]]) # number of observed columns
    code <- paste0(code, "\n\t\t\tr",i,"[i,k,1:", nprobs, "] ~ dmulti(p",i,"[i,k,], n",i,"[i,k])")

    if(nprobs > 1){
      for (k in seq(nprobs-1)) {
        pos <- seq(ncat)[as.logical(miss.patterns[[2]][miss.patterns[[1]][[i]][[2]][k],])]
        if (i==1) {
          code <- paste0(code, "\n\t\t\tp",i,"[i,k,", k, "] <- p[i,k,",pos,"]")
        } else{
          code <- paste0(code, "\n\t\t\tp",i,"[i,k,", k, "] <- p[i+", cumsum(nobs)[i-1],",k,",pos,"]")
        }
      }
    }
    code <- paste0(code,
      "\n\t\t\tp",i,"[i,k,", nprobs,"] <- 1 - sum(p",i,"[i,k,1:",nprobs-1,"])")

    if(dic == TRUE){
      code <- paste0(code,
        "\n\t\t\tfor (m in 1:", nprobs, ") {",
        "\n\t\t\t\trhat", i, "[i,k,m] <- p", i, "[i,k,m] * n", i, "[i,k]",
        "\n\t\t\t\tdv", i, "[i,k,m] <- 2*r", i, "[i,k,m] * log(r", i, "[i,k,m]/rhat", i, "[i,k,m])",
        "\n\t\t\t}",
        "\n\t\t\tdev", i, "[i,k] <- sum(dv", i, "[i,k,])",
        "\n\t\t}")

      if (i==1){
        code <- paste0(code, "\n\t\tresdev", i, "[i] <- sum(dev", i, "[i,na[i]])")
      } else{
        code <- paste0(code, "\n\t\tresdev", i, "[i] <- sum(dev", i, "[i,na[i+", cumsum(nobs)[i-1], "]])")
      }
      code <- paste0(code,
        "\n\t}",
        "\n\ttotresdev", i, " <- sum(resdev", i, "[])")
    } else{
      code <- paste0(code, "\n\t\t} \n\t}")
    }
  }

  if(dic == TRUE){
    code <- paste0(code, "\n\ttotresdev <- ")
    code.2 <- paste0("totresdev", 1)
    for(i in 2:npattern){
      code.2 <- paste(code.2, paste0("totresdev", i), sep = "+")
    }
    code <- paste0(code, code.2)
  }

  code <- paste0(code,
    "\n\tfor (i in 1:",nstudy,") {",
    "\n\t\tfor (k in 1:na[i]) {",
    "\n\t\t\tfor(m in 1:", ncat, ") {",
    "\n\t\t\t\tp[i,k,m] <- theta[i,k,m]/sum(theta[i,k,])",
    "\n\t\t\t\tlog(theta[i,k,m]) <- Eta[i,m] + delta[i,k,m]",
    "\n\t\t\t}",
    "\n\t\t}",
    "\n\t}")
  return(code)
  })
}

model.randomeffects.twoarms <- function(network){

  with(network, {
  
  code <- paste0(
    "\n\tfor(i in 1:", nstudy, "){",
    "\n\t\tfor(m in 1:", ncat, "){",
    "\n\t\t\tdelta[i,1,m] <- 0",
    "\n\t\t}",
    "\n\t\tfor(k in 2:na[i]){",
    "\n\t\t\tdelta[i,k,1] <- 0")

  if(type == "random"){
    code <- paste0(code,
      "\n\t\t\tdelta[i,k,2:", ncat, "] ~ dmnorm(md[i,k,], prec[,])",
      "\n\t\t\tfor(j in 1:", ncat -1 ,"){",
      "\n\t\t\t\tmd[i,k,j] <- d[t[i,k],j] - d[t[i,1],j]")
  } else if(type == "fixed"){
    code <- paste0(code,
      "\n\t\t\tdelta[i,k,2:", ncat, "] <- md[i,k,]",
      "\n\t\t\tfor(j in 1:", ncat -1 ,"){",
      "\n\t\t\t\tmd[i,k,j] <- d[t[i,k],j] - d[t[i,1],j]")
  }

  if(baseline != "none"){
    code <- paste0(code, " + (b_bl[t[i,k],j] - b_bl[t[i,1],j]) * (Eta[i,j+1] - mx_bl[j])")
  }
  if(!is.null(covariate)){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, " + (beta", i, "[t[i,k],j] - beta", i, "[t[i,1],j]) * (x", i, "[i]-mx", i, ")")
    }
  }
  code <- paste0(code,
    "\n\t\t\t}",
    "\n\t\t}",
    "\n\t}")

  if(type == "random"){
    code <- paste0(code, hy.prior.rjags(hy.prior, ncat))
  }
  return(code)
  })
}

model.randomeffects.threearms <- function(network){

  with(network, {
    
  if(type == "random"){
  code <- paste0(
    "\n\tfor(i in 1:", nstudy, "){",
    "\n\t\tfor(m in 1:", ncat, "){",
    "\n\t\t\tw[i,1,m] <- 0",
    "\n\t\t\tdelta[i,1,m] <- 0",
    "\n\t\t}",
    "\n\t\tfor(k in 2:na[i]){",
    "\n\t\t\tm[i,k,2:", ncat, "] ~ dmnorm(md[i,k,] / sqrt(2*(k-1)/k), prec[,])",
    "\n\t\t\tdelta[i,k,1] <- 0",
    "\n\t\t\tdelta[i,k,2:", ncat, "] <- m[i,k,2:", ncat, "] * sqrt(2*(k-1)/k)",
    "\n\t\t}",
    "\n\t}",
    "\n\tfor(i in 1:", nstudy, "){",
    "\n\t\tfor(k in 2:na[i]){",
    "\n\t\t\tfor(j in 1:", ncat-1, "){",
    "\n\t\t\t\tmd[i,k,j] <- d[t[i,k],j] - d[t[i,1],j] + sw[i,k,j]")

  if(baseline != "none"){
    code <- paste0(code, " + (b_bl[t[i,k],j] - b_bl[t[i,1],j]) * (Eta[i,j+1] - mx_bl[j])")
  }
  if(!is.null(covariate)){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, " + (beta", i, "[t[i,k],j] - beta", i, "[t[i,1],j]) * (x", i, "[i]-mx", i, ")")
    }
  }
  code <- paste0(code, "\n\t\t\t\tw[i,k,j] <- delta[i,k,j] - d[t[i,k],j] + d[t[i,1],j]")

  if(baseline != "none"){
    code <- paste0(code, " - (b_bl[t[i,k],j] - b_bl[t[i,1],j]) * (Eta[i,j+1] - mx_bl[j])")
  }
  if(!is.null(covariate)){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code, " - (beta", i, "[t[i,k],j] - beta", i, "[t[i,1],j]) * (x", i, "[i]-mx", i, ")")
    }
  }
  code <- paste0(code,
    "\n\t\t\t\tsw[i,k,j] <- sum(w[i,1:(k-1),j])/(k-1)",
    "\n\t\t\t}",
    "\n\t\t}",
    "\n\t}")

  code <- paste0(code, hy.prior.rjags(hy.prior, ncat))
  } else if(type == "fixed"){
    code <- paste0(
      "\n\tfor(i in 1:", nstudy, "){",
      "\n\t\tfor(m in 1:", ncat, "){",
      "\n\t\t\tw[i,1,m] <- 0",
      "\n\t\t\tdelta[i,1,m] <- 0",
      "\n\t\t}",
      "\n\t\tfor(k in 2:na[i]){",
      "\n\t\t\tdelta[i,k,1] <- 0",
      "\n\t\t\tdelta[i,k,2:", ncat, "] <- md[i,k,]",
      "\n\t\t}",
      "\n\t}",
      "\n\tfor(i in 1:", nstudy, "){",
      "\n\t\tfor(k in 2:na[i]){",
      "\n\t\t\tfor(j in 1:", ncat-1, "){",
      "\n\t\t\t\tmd[i,k,j] <- d[t[i,k],j] - d[t[i,1],j]")

    if(baseline != "none"){
      code <- paste0(code, " + (b_bl[t[i,k],j] - b_bl[t[i,1],j]) * (Eta[i,j+1] - mx_bl[j])")
    }
    if(!is.null(covariate)){
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, " + (beta", i, "[t[i,k],j] - beta", i, "[t[i,1],j]) * (x", i, "[i]-mx", i, ")")
      }
    }

    code <- paste0(code,
      "\n\t\t\t}",
      "\n\t\t}",
      "\n\t}")
  }
  return(code)
  })
}



model.multinomial.prior <- function(network){

  with(network, {
  
      
  code <- if(baseline.risk == "independent"){
    paste0(
      "\n\tfor(i in 1:", nstudy, "){",
      "\n\t\tEta[i,1] <- 0",
      "\n\t\tEta[i,2:", ncat, "] ~ dmnorm(mean.Eta[], prec.Eta[,])",
      "\n\t}")
  } else if(baseline.risk == "exchangeable"){
    paste0(
      "\n\tfor(i in 1:", nstudy, "){",
      "\n\t\tEta[i,1] <- 0",
      "\n\t\tEta[i,2:", ncat, "] ~ dmnorm(E, precE)",
      "\n\t}",
      "\n\tE ~ dmnorm(mean.Eta[], prec.Eta[,])",
      hy.prior.Eta.rjags(hy.prior.Eta, ncat))
  }
  
  code <- paste0(code, "\n\tfor(k in 1:", ncat-1, "){",
    "\n\t\td[1,k] <- 0",
    "\n\t}",
    "\n\tfor(j in 2:", ntreat, "){",
    "\n\t\td[j,1:", ncat-1, "] ~  dmnorm(mean.d[], prec.d[,])",
    "\n\t}")

  if(baseline == "common"){
    code <- paste0(code,
      "\n\tfor(k in 1:", ncat -1, "){",
      "\n\t\tb_bl[1,k] <- 0",
      "\n\t}",
      "\n\tfor(j in 2:", ntreat, "){",
      "\n\t\tb_bl[j,1:", ncat - 1, "] <- B",
      "\n\t}",
      "\n\tB ~ dmnorm(mean.bl[], prec.bl[,])")
  } else if(baseline == "independent"){
    code <- paste0(code,
      "\n\tfor(k in 1:", ncat -1, "){",
      "\n\t\tb_bl[1,k] <- 0",
      "\n\t}",
      "\n\tfor(j in 2:", ntreat, "){",
      "\n\t\tb_bl[j,1:", ncat - 1, "] ~ dmnorm(mean.bl[], prec.bl[,])",
      "\n\t}")
  } else if(baseline == "exchangeable"){
    code <- paste0(code,
      "\n\tfor(k in 1:", ncat -1, "){",
      "\n\t\tb_bl[1,k] <- 0",
      "\n\t}",
      "\n\tfor(j in 2:", ntreat, "){",
      "\n\t\tb_bl[j,1:", ncat -1, "] ~ dmnorm(B, precB)",
      "\n\t}",
      "\n\tB ~ dmnorm(mean.bl[], prec.bl[,])",
      hy.prior.bl.rjags(hy.prior.bl, ncat))
  }


  if(!is.null(covariate)){
    if(covariate.model == "independent"){
      code <- paste0(code, "\n\tfor(k in 1:", ncat -1, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[1,k] <- 0")
      }
      code <- paste0(code,
                     "\n\t}",
                     "\n\tfor(j in 2:", ntreat, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[j,1:", ncat - 1, "] ~ dmnorm(mean.cov[], prec.cov[,])")
      }
      code <- paste0(code, "\n\t}")
    } else if(covariate.model == "common"){
      code <- paste0(code, "\n\tfor(k in 1:", ncat -1, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[1,k] <- 0")
      }
      code <- paste0(code,
                     "\n\t}",
                     "\n\tfor(j in 2:", ntreat, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[j,1:", ncat - 1, "] <- ", paste0("C", i))
      }
      code <- paste0(code, "\n\t}")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t", paste0("C", i), " ~ dmnorm(mean.cov[], prec.cov[,])")
      }
    } else if(covariate.model == "exchangeable"){
      code <- paste0(code, "\n\tfor(k in 1:", ncat -1, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[1,k] <- 0")
      }
      code <- paste0(code,
                     "\n\t}",
                     "\n\tfor(j in 2:", ntreat, "){")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t\tbeta", i, "[j,1:", ncat - 1, "] ~ dmnorm(", paste0("C", i), ",", paste0("precC", i), ")")
      }
      code <- paste0(code, "\n\t}")
      for(i in 1:dim(covariate)[2]){
        code <- paste0(code, "\n\t", paste0("C", i), " ~ dmnorm(mean.cov[], prec.cov[,])")
      }
      code <- paste0(code, hy.prior.cov.rjags(hy.prior.cov, covariate, ncat))
    }
  }
  return(code)
  
  })
}

model.multinomial <- function(network){
  
  with(network, {
    
  code <- ""
  if(is.null(miss.matrix)){
    code <- paste0(code, model.multinomial.complete(network))
  } else{
    code <- paste0(code, model.multinomial.incomplete(network))
  }
  if(max(na) == 2){
    code <- paste0(code, model.randomeffects.twoarms(network))
  } else{
    code <- paste0(code, model.randomeffects.threearms(network))
  }
  code <- paste0(code, model.multinomial.prior(network), rank.rjags.multinomial(network))
  return(code)
  })
}

###################################### Function used for all the distribution
#############################################################################


hy.prior.Eta.rjags <- function(hy.prior.Eta, ncat){
  
  code <- ""
  distr <- hy.prior.Eta[[1]]
  if(distr == "dunif"){
    code <- paste0(code,
                   "\n\tprecE <- pow(sdE, -2)",
                   "\n\tsdE ~ dunif(hy.prior.Eta.1, hy.prior.Eta.2)")
  } else if(distr == "dgamma"){
    code <- paste0(code,
                   "\n\tprecE ~ dgamma(hy.prior.Eta.1, hy.prior.Eta.2)",
                   "\n\tsdE <- pow(precE, -0.5)")
  } else if(distr == "dhnorm"){
    code <- paste0(code,
                   "\n\tprecE <- pow(sdE, -2)",
                   "\n\tsdE ~ dnorm(hy.prior.Eta.1, hy.prior.Eta.2)T(0,)")
  } else if (distr == "dwish"){
    code <- paste0(code,
                   "\n\tprecE[1:", ncat-1, ",1:", ncat-1, "] ~ dwish(hy.prior.Eta.1, hy.prior.Eta.2)",
                   "\n\tsigmaE[1:", ncat-1, ",1:", ncat-1, "] <- inverse(precE[,])")
  }
  return(code)
}



hy.prior.bl.rjags <- function(hy.prior.bl, ncat){

  code <- ""
  distr <- hy.prior.bl[[1]]
  if(distr == "dunif"){
    code <- paste0(code,
                   "\n\tprecB <- pow(sdB, -2)",
                   "\n\tsdB ~ dunif(hy.prior.bl.1, hy.prior.bl.2)")
  } else if(distr == "dgamma"){
    code <- paste0(code,
                   "\n\tprecB ~ dgamma(hy.prior.bl.1, hy.prior.bl.2)",
                   "\n\tsdB <- pow(precB, -0.5)")
  } else if(distr == "dhnorm"){
    code <- paste0(code,
                   "\n\tprecB <- pow(sdB, -2)",
                   "\n\tsdB ~ dnorm(hy.prior.bl.1, hy.prior.bl.2)T(0,)")
  } else if (distr == "dwish"){
    code <- paste0(code,
                   "\n\tprecB[1:", ncat-1, ",1:", ncat-1, "] ~ dwish(hy.prior.bl.1, hy.prior.bl.2)",
                   "\n\tsigmaB[1:", ncat-1, ",1:", ncat-1, "] <- inverse(precB[,])")
  }
  return(code)
}

hy.prior.cov.rjags <- function(hy.prior.cov, covariate, ncat){

  code <- ""
  distr <- hy.prior.cov[[1]]
  if(distr == "dunif"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code,
        "\n\t", paste0("precC", i), " <- pow(", paste0("sdC", i), ",-2)",
        "\n\t", paste0("sdC", i), " ~ dunif(hy.prior.cov.1, hy.prior.cov.2)")
    }
  } else if(distr == "dgamma"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code,
        "\n\t", paste0("precC", i), " ~ dgamma(hy.prior.cov.1, hy.prior.cov.2)",
        "\n\t", paste0("sdC", i), " <- pow(", paste0("precC", i), ",-0.5)")
    }
  } else if(distr == "dhnorm"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code,
        "\n\t", paste0("precC", i), " <- pow(", paste0("sdC", i), ",-2)",
        "\n\t", paste0("sdC", i), " ~ dnorm(hy.prior.cov.1, hy.prior.cov.2)T(0,)")
    }
  } else if (distr == "dwish"){
    for(i in 1:dim(covariate)[2]){
      code <- paste0(code,
        "\n\t", paste0("precC", i), "[1:", ncat-1, ",1:", ncat-1, "] ~ dwish(hy.prior.cov.1, hy.prior.cov.2)",
        "\n\t", paste0("sigmaC", i), "[1:", ncat-1, ",1:", ncat-1, "] <- inverse(", paste0("precC", i), "[,])")
    }
  }
  return(code)
}

hy.prior.rjags <- function(hy.prior, ncat){

  code <- ""
  distr <- hy.prior[[1]]
  if (distr == "dunif") {
    code <- paste0(code,
      "\n\tsd ~ dunif(hy.prior.1, hy.prior.2)",
      "\n\tprec <- pow(sd,-2)",
      "\n\tlogvar <- log(pow(sd, 2))")
  } else if(distr == "dgamma"){
    code <- paste0(code,
      "\n\tsd <- pow(prec, -0.5)",
      "\n\tprec ~ dgamma(hy.prior.1, hy.prior.2)",
      "\n\tlogvar <- log(pow(sd, 2))")
  } else if(distr == "dhnorm"){
    code <- paste0(code,
      "\n\tsd ~ dnorm(hy.prior.1, hy.prior.2)T(0,)",
      "\n\tprec <- pow(sd, -2)",
      "\n\tlogvar <- log(pow(sd, 2))")
  } else if (distr == "dwish"){
    code <- paste0(code,
      "\n\tprec[1:", ncat-1, ",1:", ncat-1, "] ~ dwish(hy.prior.1, hy.prior.2)",
      "\n\tsigma[1:", ncat-1, ",1:", ncat-1, "] <- inverse(prec[,])")
  }

  if(ncat > 1){
    code <- paste0(code,
         "\n\tfor(i in 1:", ncat-1, "){",
         "\n\t\tfor(j in 1:", ncat-1, "){",
         "\n\t\t\trho[i,j] <- ifelse(i == j, 0, sigma[i,j]/(sqrt(sigma[i,i])* sqrt(sigma[j,j])))",
         "\n\t\t\tsigma_transformed[i,j] <- ifelse(i == j, log(sigma[i,i]), 1/2 * log((1+ rho[i,j])/(1-rho[i,j])))",
         "\n\t\t}",
         "\n\t}")
  }
  return(code)
}


rank.rjags <- function(rank.preference, ntreat){

  code <- paste0(
    "\n\trank_number <- rank(d[])",
    "\n\tfor(k in 1:", ntreat, "){")

  if(rank.preference == "higher"){
    code <- paste0(code, "\n\t\trk[k] <- ", ntreat, " +1- rank_number[k]")
  } else if(rank.preference == "lower"){
    code <- paste0(code, "\n\t\trk[k] <- rank_number[k]")
  }
  code <- paste0(code,
    "\n\t\tfor(h in 1:", ntreat, "){ prob[h,k] <- equals(rk[k],h)}",
    "\n\t}")
  return(code)
}

rank.rjags.multinomial <- function(network){

  with(network, {
    
  code <- paste0(
    "\n\tfor(j in 1:", ncat -1, "){",
    "\n\t\trank_number[1:", ntreat, ",j] <- rank(d[1:", ntreat, ",j])",
    "\n\t\tfor(k in 1:", ntreat, "){")

  if(rank.preference == "higher"){
    code <- paste0(code, "\n\t\t\trk[k,j] <- ", ntreat, " + 1 - rank_number[k,j]")
  } else if (rank.preference == "lower"){
    code <- paste0(code, "\n\t\t\trk[k,j] <- rank_number[k,j]")
  }
  code <- paste0(code,
    "\n\t\t\tfor(h in 1:", ntreat, "){ prob[h,k,j] <- equals(rk[k,j], h)}",
    "\n\t\t}",
    "\n\t}")
  return(code)
  })
}

