#' Add correlated data to existing data.table
#'
#' @param dtOld Data table that is the new columns will be appended to.
#' @param idname Character name of id field, defaults to "id".
#' @param mu A vector of means. The length of mu must be nvars.
#' @param sigma Standard deviation of variables. If standard deviation differs
#' for each variable, enter as a vector with the same length as the mean vector
#' mu. If the standard deviation is constant across variables, as single value
#' can be entered.
#' @param corMatrix Correlation matrix can be entered directly. It must be
#' symmetrical and positive semi-definite. It is not a required field; if a
#' matrix is not provided, then a structure and correlation coefficient rho must
#' be specified.
#' @param rho Correlation coefficient, -1 <= rho <= 1. Use if corMatrix is not
#' provided.
#' @param corstr Correlation structure of the variance-covariance matrix
#' defined by sigma and rho. Options include "ind" for an independence
#' structure, "cs" for a compound symmetry structure, and "ar1" for an
#' autoregressive structure.
#' @param cnames Explicit column names. A single string with names separated
#' by commas. If no string is provided, the default names will be V#, where #
#' represents the column.
#' @return The original data table with the additional correlated columns
#' @examples
#' def <- defData(varname = "xUni", dist = "uniform", formula = "10;20", id = "myID")
#' def <- defData(def,
#'   varname = "xNorm", formula = "xUni * 2", dist = "normal",
#'   variance = 8
#' )
#'
#' dt <- genData(250, def)
#'
#' mu <- c(3, 8, 15)
#' sigma <- c(1, 2, 3)
#'
#' dtAdd <- addCorData(dt, "myID",
#'   mu = mu, sigma = sigma,
#'   rho = .7, corstr = "cs"
#' )
#' dtAdd
#'
#' round(var(dtAdd[, .(V1, V2, V3)]), 3)
#' round(cor(dtAdd[, .(V1, V2, V3)]), 2)
#'
#' dtAdd <- addCorData(dt, "myID",
#'   mu = mu, sigma = sigma,
#'   rho = .7, corstr = "ar1"
#' )
#' round(cor(dtAdd[, .(V1, V2, V3)]), 2)
#'
#' corMat <- matrix(c(1, .2, .8, .2, 1, .6, .8, .6, 1), nrow = 3)
#'
#' dtAdd <- addCorData(dt, "myID",
#'   mu = mu, sigma = sigma,
#'   corMatrix = corMat
#' )
#' round(cor(dtAdd[, .(V1, V2, V3)]), 2)
#' @concept correlated
#' @export
addCorData <- function(dtOld, idname, mu, sigma, corMatrix = NULL,
                       rho, corstr = "ind", cnames = NULL) {
  # dtName must contain id for now
  dtTemp <- copy(dtOld)
  data.table::setkeyv(dtTemp, idname)

  n <- nrow(dtTemp)

  dtNew <- simstudy::genCorData(
    n = n, mu = mu, sigma = sigma,
    corMatrix = corMatrix, rho = rho,
    corstr = corstr, cnames = cnames,
    idname = idname
  )

  data.table::setkeyv(dtNew, idname)

  dtTemp <- mergeData(dtTemp, dtNew, idname)

  return(dtTemp[])
}

#' Create multivariate (correlated) data - for general distributions
#'
#' @param dt Data table that will be updated.
#' @param defs Field definition table created by function `defDataAdd`.
#' @param rho Correlation coefficient, -1 <= rho <= 1. Use if corMatrix is not
#' provided.
#' @param tau Correlation based on Kendall's tau. If tau is specified, then it
#' is used as the correlation even if rho is specified. If tau is NULL, then the
#' specified value of rho is used, or rho defaults to 0.
#' @param corstr Correlation structure of the variance-covariance matrix defined
#' by sigma and rho. Options include "cs" for a compound symmetry structure
#' and "ar1" for an autoregressive structure. Defaults to "cs".
#' @param corMatrix Correlation matrix can be entered directly. It must be
#' symmetrical and positive semi-definite. It is not a required field; if a
#' matrix is not provided, then a structure and correlation coefficient rho must
#' be specified.
#' @param envir Environment the data definitions are evaluated in.
#'  Defaults to [base::parent.frame].
#' @return data.table with added column(s) of correlated data
#' @examples
#' defC <- defData(
#'   varname = "nInds", formula = 50, dist = "noZeroPoisson",
#'   id = "idClust"
#' )
#'
#' dc <- genData(10, defC)
#' #### Normal only
#'
#' dc <- addCorData(dc,
#'   mu = c(0, 0, 0, 0), sigma = c(2, 2, 2, 2), rho = .2,
#'   corstr = "cs", cnames = c("a", "b", "c", "d"),
#'   idname = "idClust"
#' )
#'
#' di <- genCluster(dc, "idClust", "nInds", "id")
#'
#' defI <- defDataAdd(
#'   varname = "A", formula = "-1 + a", variance = 3,
#'   dist = "normal"
#' )
#' defI <- defDataAdd(defI,
#'   varname = "B", formula = "4.5 + b", variance = .5,
#'   dist = "normal"
#' )
#' defI <- defDataAdd(defI,
#'   varname = "C", formula = "5*c", variance = 3,
#'   dist = "normal"
#' )
#' defI <- defDataAdd(defI,
#'   varname = "D", formula = "1.6 + d", variance = 1,
#'   dist = "normal"
#' )
#'
#' #### Generate new data
#'
#' di <- addCorFlex(di, defI, rho = 0.4, corstr = "cs")
#'
#' # Check correlations by cluster
#'
#' for (i in 1:nrow(dc)) {
#'   print(cor(di[idClust == i, list(A, B, C, D)]))
#' }
#'
#' # Check global correlations - should not be as correlated
#' cor(di[, list(A, B, C, D)])
#' @concept correlated
#' @md
#' @export
addCorFlex <- function(dt, defs, rho = 0, tau = NULL, corstr = "cs",
                       corMatrix = NULL, envir = parent.frame()) {

  # "Declare" vars to avoid R CMD warning

  X <- NULL
  Unew <- NULL
  param1 <- NULL
  param2 <- NULL
  id <- NULL
  period <- NULL
  dist <- NULL
  formula <- NULL
  link <- NULL
  variance <- NULL

  #### Check args

  ## Other checks? ##

  # check that names are not already used

  ###

  if (!all(defs[, dist] %in% c("normal", "gamma", "binary", "poisson", "negBinomial"))) {
    stop("Only implemented for the following distributions: binary, normal, poisson, gamma, and negative binomial")
  }

  ####

  dtCopy <- copy(dt)
  n <- nrow(dtCopy)

  corDefs <- copy(defs)
  nvars <- nrow(corDefs)

  ### Start generating data (first, using copula)

  ### Convert tau to rho

  if (!is.null(tau)) {
    rho <- sin(tau * pi / 2)
  }

  ###

  dx <- .genQuantU(nvars, n, rho, corstr, corMatrix)

  dFinal <- dx[period == 0, list(id)]

  for (i in 1:nvars) {
    dTemp <- dx[period == (i - 1)]
    dTemp <- dTemp[dtCopy]

    iDist <- corDefs[i, dist]
    iFormula <- corDefs[i, formula]
    iLink <- corDefs[i, link]

    if (iDist == "binary") {
      params <- .getBinaryMean(dTemp,
        formula = iFormula,
        size = 1,
        link = iLink,
        envir = envir
      )

      V <- dTemp[, stats::qbinom(Unew, 1, params[[1]])]
    } else if (iDist == "poisson") {
      param1 <- .getPoissonMean(
        dtSim = dTemp,
        formula = iFormula,
        link = iLink,
        envir = envir
      )

      V <- dTemp[, stats::qpois(Unew, param1)]
    } else if (iDist == "gamma") {
      mn <- .getGammaMean(
        dtSim = dTemp,
        formula = iFormula,
        link = iLink,
        envir = envir
      )

      ### Gamma parameters need to be transformed

      sr <- gammaGetShapeRate(mn, corDefs[i, variance])
      param1 <- sr[[1]]
      param2 <- sr[[2]]

      V <- dTemp[, stats::qgamma(Unew, param1, param2)]
    } else if (iDist == "negBinomial") {
      mn <- .getNBmean(dTemp, formula = iFormula, link = iLink, envir = envir)

      ### NB parameters need to be transformed

      sp <- negbinomGetSizeProb(mn, corDefs[i, variance])
      param1 <- sp[[1]]
      param2 <- sp[[2]]

      V <- dTemp[, stats::qnbinom(Unew, param1, param2)]
    } else if (iDist == "normal") {
      param1 <- .getNormalMean(dtSim = dTemp, formula = iFormula, envir = envir)
      param2 <- sqrt(corDefs[i, variance])

      V <- dTemp[, stats::qnorm(Unew, param1, param2)]
    }

    dFinal <- cbind(dFinal, V)
    setnames(dFinal, "V", corDefs$varname[i])
  }

  dFinal <- dtCopy[dFinal]

  return(dFinal[])
}

#' Create multivariate (correlated) data - for general distributions
#'
#' @param dtOld The data set that will be augmented. If the data set includes a
#' single record per id, the new data table will be created as a "wide" data set.
#' If the original data set includes multiple records per id, the new data set will 
#' be in "long" format.
#' @param nvars The number of new variables to create for each id. This is only applicable
#' when the data are generated from a data set that includes one record per id.
#' @param idvar String variable name of column represents individual level id for correlated
#' data.
#' @param dist A string indicating "normal", "binary", "poisson" or "gamma".
#' @param rho Correlation coefficient, -1 <= rho <= 1. Use if corMatrix is not provided.
#' @param corstr Correlation structure of the variance-covariance matrix
#' defined by sigma and rho. Options include "cs" for a compound symmetry structure
#' and "ar1" for an autoregressive structure.
#' @param corMatrix Correlation matrix can be entered directly. It must be symmetrical and
#' positive semi-definite. It is not a required field; if a matrix is not provided, then a
#' structure and correlation coefficient rho must be specified.
#' @param param1  A string that represents the column in dtOld that contains the parameter
#' for the mean of the distribution. In the case of the uniform distribution the column
#' specifies the minimum.
#' @param param2 A string that represents the column in dtOld that contains a possible second
#' parameter for the distribution. For the normal distribution, this will be the variance;
#' for the gamma distribution, this will be the dispersion; and for the uniform distribution,
#' this will be the maximum.
#' @param cnames Explicit column names. A single string with names separated
#' by commas. If no string is provided, the default names will be V#, where #
#' represents the column.
#' @param method Two methods are available to generate correlated data. (1) "copula" uses
#' the multivariate Gaussian copula method that is applied to all other distributions; this
#' applies to all available distributions. (2) "ep" uses an algorithm developed by
#' Emrich and Piedmonte (1991).
#' @param ... May include additional arguments that have been deprecated and are
#' no longer used.
#' @details The original data table can come in one of two formats: a single row 
#' per **idvar** (where data are *ungrouped*) or multiple rows per **idvar** (in which 
#' case the data are *grouped* or clustered). The structure of the arguments 
#' depends on the format of the data.
#' 
#' In the case of *ungrouped* data, there are two ways to specify the number of
#' correlated variables and the covariance matrix. In approach (1), 
#' **nvars** needs to be specified along with **rho** and **corstr**.
#' In approach (2), **corMatrix** may be specified by identifying a single square
#' *n* x *n* covariance matrix. The number of new variables generated for each 
#' record will be *n*. If **nvars**, **rho**, 
#' **corstr**, and **corMatrix** are all specified, the data will be 
#' generated based on the information provided in the covariance matrix alone.
#' In both (1) and (2), the data will be returned in a wide format.
#' 
#' In the case of *grouped* data, where there are *G* groups, there are also two 
#' ways to proceed. In both cases,
#' the number of new variables to be generated may vary by group, and will be determined by the
#' number of records in each group, \eqn{n_i, i \in \{1,...,G\}} (i.e., the number of records that share the same 
#' value of *idvar*). **nvars** is not used in grouped data.
#' In approach (1), the arguments **rho** and **corstr** may both be specified 
#' to determine the structure of the covariance 
#' matrix. In approach (2), the argument **corMatrix** may be specified.
#' **corMatrix** can be a single matrix with dimensions \eqn{n \ \text{x} \ n} if 
#' \eqn{n_i = n} for all *i*. However, if the sample sizes of each group vary 
#' (i.e., \eqn{n_i \ne n_j} for some groups *i* and *j*), **corMatrix** must be a list
#' of covariance matrices with a length *G*; each 
#' covariance matrix in the list will have dimensions 
#' \eqn{n_i \ \text{x} \ n_i, \ i \in \{1,...,G\}}. In the case of *grouped* data, the
#' new data will be returned in *long* format (i.e., one new column only).
#' 
#' @return Original data.table with added column(s) of correlated data
#' @references Emrich LJ, Piedmonte MR. A Method for Generating High-Dimensional
#' Multivariate Binary Variates. The American Statistician 1991;45:302-4.
#' @examples
#' # Ungrouped data
#' 
#' cMat <- genCorMat(nvars = 4, rho = .2, corstr = "ar1", nclusters = 1)
#' 
#' def <-
#'   defData(varname = "xbase", formula = 5, variance = .4, dist = "gamma") |>
#'   defData(varname = "lambda", formula = ".5 + .1*xbase", dist = "nonrandom", link = "log") |>
#'   defData(varname = "n", formula = 3, dist = "noZeroPoisson")
#' 
#' dd <- genData(101, def, id = "cid")
#' 
#' ## Specify with nvars, rho, and corstr
#' 
#' addCorGen(
#'   dtOld = dd, idvar = "cid", nvars = 3, rho = .7, corstr = "cs",
#'   dist = "poisson", param1 = "lambda"
#' )
#' 
#' ## Specify with covMatrix
#' 
#' addCorGen(
#'   dtOld = dd, idvar = "cid", corMatrix = cMat,
#'   dist = "poisson", param1 = "lambda"
#' )
#' 
#' # Grouped data
#' 
#' cMats <- genCorMat(nvars = dd$n, rho = .5, corstr = "cs", nclusters = nrow(dd))
#' 
#' dx <- genCluster(dd, "cid", "n", "id")
#' 
#' ## Specify with nvars, rho, and corstr
#' 
#' addCorGen(
#'   dtOld = dx, idvar = "cid", rho = .8, corstr = "ar1", dist = "poisson", param1 = "xbase"
#' )
#' 
#' ## Specify with covMatrix
#' 
#' addCorGen(
#'  dtOld = dx, idvar = "cid", corMatrix = cMats, dist = "poisson", param1 = "xbase"
#' )
#' 
#' @concept correlated
#' @export
#' @md
addCorGen <- function(dtOld, nvars=NULL, idvar = "id", rho=NULL, corstr=NULL, corMatrix = NULL,
                      dist, param1, param2 = NULL, cnames = NULL,
                      method = "copula", ...) {

  ### can deprecate formSpec - no longer relevant
  ### can deprecate periodvar - no longer relevant
  
  # "Declare" vars to avoid R CMD warning

  .id <- NULL
  N <- NULL
  .U <- NULL
  Unew <- NULL
  .XX <- NULL
  X <- NULL
  .param1 <- NULL
  .param2 <- NULL
  seq_ <- NULL
  period <- NULL
  p <- NULL
  corM <- NULL
  seqid <- NULL
  
  ####
  
  .genByID <- function(p, rho, corstr, corMatrix) {

    corM <- .buildCorMat(nvars = length(p), corMatrix, corstr, rho)
    dtM <- .genBinEP(1, p, corM)
    dtM <- dtM[, list(X, seq_ = seqid)]
    dtM[]
    
  }
  
  #### Check args

  assertNotMissing(dtOld = missing(dtOld), 
                   dist = missing(dist), param1 = missing(param1))
  
  assertClass(dtOld = dtOld, class = "data.table")
  
  assertOption(dist = dist, 
    options = c("poisson", "binary", "gamma", "uniform", "negBinomial", "normal"))
  
  if (!is.null(param2)) {
    assertInDataTable(vars = c(idvar, param1, param2), dt = dtOld)
  } else assertInDataTable(vars = c(idvar, param1), dt = dtOld)
  
  assertOption(method = method, options = c("copula", "ep"))

  nparams <- as.numeric(!is.null(param1)) + as.numeric(!is.null(param2))

  if (((nparams > 1) & (dist %in% c("poisson", "binary")))) {
    stop(paste0("Too many parameters (", nparams, ") for ", dist))
  }

  if (((nparams < 2) & (dist %in% c("gamma", "uniform", "normal", "negBinomial")))) {
    stop(paste0("Too few parameters (", nparams, ") for ", dist))
  }

  if (dist != "binary" & method == "ep") {
    stop("Method `ep` applies only to binary data generation")
  }
  

  # wide(ness) is determined by incoming data structure.

  maxN <- dtOld[, .N, by = idvar][, max(N)]
  
  if (maxN == 1) {
    wide <- TRUE
    if ((is.null(nvars) | is.null(rho) | is.null(corstr)) & (is.null(corMatrix))) {
      stop("Either nvars, rho, and corstr all must be provided or corMatrix must be provided.")
    }
    
    if (is.null(corMatrix)) { # that means that we are using nvars/rho/corstr  
      assertAtLeast(nvars = nvars, minVal = 2)
    }
  } else if (maxN > 1) {
    wide <- FALSE
    if ((is.null(rho) | is.null(corstr)) & (is.null(corMatrix))) {
      stop("Either both rho and corstr must be provided or corMatrix must be provided.")
    }
    
  }
  
  ####
  
  if (!is.null(cnames)) {
    nnames <- trimws(unlist(strsplit(cnames, split = ",")))
    lnames <- length(nnames)
    if (!wide) {
      if (lnames > 1) stop(paste("Long format can have only 1 name.", lnames, "have been provided."))
    } else if (wide) {
      if (lnames != nvars) stop(paste0("Number of names (", lnames, ") not equal to specified nvars (", nvars, ")."))
    }
  }

  ####
  
  dtOrig <- copy(dtOld)
  setnames(dtOrig, idvar, ".id")
  dtTemp <- copy(dtOrig)
  
  # check corMatrix
  
  if (!is.null(corMatrix)) {
    if (is.list(corMatrix)) {
      
      # check if corMatrix is a numeric matrix
      
      test <- 
        sapply(corMatrix, function(corMatrix) assertNumericMatrix(corMatrix = corMatrix))
      
      # check if there are the same number of correlation matrices as there are clusters
      
      dn <- dtTemp[, .N, keyby = .id]
      assertLength(corMatrix = corMatrix, length = nrow(dn))
      
      # check if the dimensions of corr matrices match cluster sizes
      
      dn$dim <- sapply(corMatrix, function(x) nrow(x))
      compare_cluster_size <- dn[, sum(N != dim)]
      if (compare_cluster_size != 0) {
        stop("Dimensions of correlation matrices in corMatrix not equal to cluster sizes!")
      }
    
    } else { # not a list
      assertNumericMatrix(corMatrix = corMatrix)
      
      # check if the dimensions of corr matrix matches (equal) cluster size
      
      if (!wide) {
        dn <- dtTemp[, .N, keyby = .id]
        dn[, dim := nrow(corMatrix)]
        compare_cluster_size <- dn[, sum(N != dim)]
        if (compare_cluster_size != 0) {
          stop("Dimensions of corMatrix not equal to cluster sizes!")
        }
      }
    }
  }
  
  if (wide) { # Convert to long form temporarily
    if ( is.null(nvars) ) nvars <- nrow(corMatrix)
    dtTemp <- addPeriods(dtTemp, nPeriods = nvars, idvars = ".id")
  }
  
  dtTemp[, seq_ := 1:.N, keyby = .id]
  # nvars <- dtTemp[.id == 1, .N] # only permits case where number of records per id is the same
  
  counts <- dtTemp[, .N, by = .id][, N]
  same_nvar <- all(counts == counts[1])
  
  if (!wide) {    # multiple record per id
    if (is.null(corMatrix)) {
      if (same_nvar) {
        corMatrix <- genCorMat(nvars = counts[1] , rho = rho, corstr = corstr, nclusters = 1)  
      } else {
        corMatrix <- genCorMat(nvars = counts , rho = rho, corstr = corstr, nclusters = length(counts))  
      }
    }
  } else  {        # single record per id
    if (is.null(corMatrix)) {
      corMatrix <- genCorMat(nvars = nvars , rho = rho, corstr = corstr, nclusters = 1) 
    }
  }

  if (method == "copula") {
    
    if (is.list(corMatrix)) {
      ns <- split(dtTemp[, .N, keyby = .id], by = ".id")
      dtM <- rbindlist(
        lapply(ns, function(x) .genQuantU(x$N, 1, rho, corstr, corMatrix[[x$.id]])) 
      )
      
      dtTemp[, .U := dtM$Unew]
    } else {
      
      nvars <- nrow(corMatrix)
      
      ns <- nrow(dtTemp[, .N, keyby = .id])
      Unew <- c(t(mvnfast::rmvn(n = ns, mu = rep(0, nvars), sigma = corMatrix)))
    
      dtTemp[, .U := stats::pnorm(Unew)]
    }
    
    if (dist == "poisson") {
      setnames(dtTemp, param1, ".param1")
      dtTemp[, .XX := stats::qpois(p = .U, lambda = .param1)]
    } else if (dist == "binary") {
      setnames(dtTemp, param1, ".param1")
      dtTemp[, .XX := stats::qbinom(p = .U, size = 1, prob = .param1)]
    } else if (dist == "negBinomial") {
      setnames(dtTemp, param1, ".param1")
      setnames(dtTemp, param2, ".param2")
      sp <- negbinomGetSizeProb(dtTemp$.param1, dtTemp$.param2)
      dtTemp[, .param1 := sp[[1]]]
      dtTemp[, .param2 := sp[[2]]]
      dtTemp[, .XX := stats::qnbinom(p = .U, size = .param1, prob = .param2)]
    } else if (dist == "uniform") {
      setnames(dtTemp, param1, ".param1")
      setnames(dtTemp, param2, ".param2")
      dtTemp[, .XX := stats::qunif(p = .U, min = .param1, max = .param2)]
    } else if (dist == "gamma") {
      setnames(dtTemp, param1, ".param1")
      setnames(dtTemp, param2, ".param2")
      sr <- gammaGetShapeRate(dtTemp$.param1, dtTemp$.param2)
      dtTemp[, .param1 := sr[[1]]]
      dtTemp[, .param2 := sr[[2]]]
      dtTemp[, .XX := stats::qgamma(p = .U, shape = .param1, rate = .param2)]
    } else if (dist == "normal") {
      setnames(dtTemp, param1, ".param1")
      setnames(dtTemp, param2, ".param2")
      dtTemp[, .XX := stats::qnorm(p = .U, mean = .param1, sd = sqrt(.param2))]
    }
    
    dX <- dtTemp[, list(.id, seq_, .XX)]
  } else if (method == "ep") {
    
    if (is.list(corMatrix)) {
      dX <- dtTemp[, .genByID(p = get(param1), rho, corstr, corMatrix[[.id]]), keyby = .id]
    } else {
      dX <- dtTemp[, .genByID(p = get(param1), rho, corstr, corMatrix), keyby = .id]
    }
    
    setnames(dX, "X", ".XX")
    
  } # end (if ep)

  if (wide) {
    
    setkey(dX, .id, seq_)

    dWide <- dcast(dX, .id ~ seq_, value.var = ".XX")
    setnames(dWide, c(".id", paste0("V", 1:nvars)))
    
    setkey(dWide, ".id")
    setkey(dtOrig, ".id")
    
    dtTemp <- dtOrig[dWide]

    if (!is.null(cnames)) {
      setnames(dtTemp, paste0("V", 1:nvars), nnames)
    }

  } else if (!wide) {
    
    dtTemp <- copy(dtOld)
    setnames(dtTemp, c(idvar), c(".id"))
    dtTemp[, seq_ := 1:.N, keyby = .id]
    
    setkey(dX, .id, seq_)
    setkey(dtTemp, .id, seq_)
    
    dtTemp <- dtTemp[dX]
    
    if (!is.null(cnames)) {
      setnames(dtTemp, ".XX", cnames)
    } else {
      setnames(dtTemp, ".XX", "X")
    }
    
    dtTemp[, seq_ := NULL]
    
  } # end if !wide
  
  setnames(dtTemp, ".id", idvar)
  return(dtTemp[])
}