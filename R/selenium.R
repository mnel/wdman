#' Start Selenium Server
#'
#' Start Selenium Server
#' @param port Port to run on
#' @param version what version of Selenium Server to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("seleniumserver")
#' @param chromever what version of Chrome driver to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("chromedriver"), A value of NULL
#'     excludes adding the chrome browser to Selenium Server.
#' @param geckover what version of Gecko driver to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("geckodriver"), A value of NULL
#'     excludes adding the firefox browser to Selenium Server.
#' @param phantomver what version of PhantomJS to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("phantomjs"), A value of NULL
#'     excludes adding the PhantomJS headless browser to Selenium Server.
#' @param iedrver what version of IEDriverServer to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("iedriverserver"), A value of NULL
#'     excludes adding the internet explorer browser to Selenium Server.
#'     NOTE this functionality is Windows OS only.
#' @param verbose If TRUE, include status messages (if any)
#' @return Returns a list with named elements process, output, error
#'     and stop. process is the output from calling \code{\link{spawn_process}}
#'     output, error and stop are functions calling
#'     \code{\link{process_read}}, \code{\link{process_read}} with "stderr"
#'     pipe and \code{\link{process_kill}}  respectively  on process.
#' @export
#'
#' @examples
#' \dontrun{
#' selServ <- selenium()
#' selServ$output()
#' selServ$stop()
#' }

selenium <- function(port = 4567L,
                     version = "latest",
                     chromever = "latest",
                     geckover = "latest",
                     iedrver = NULL,
                     phantomver = "latest",
                     verbose = TRUE){
  assert_that(is_integer(port))
  assert_that(is_string(version))
  assert_that(is_string_or_null(chromever))
  assert_that(is_string_or_null(geckover))
  assert_that(is_string_or_null(phantomver))
  assert_that(is_logical(verbose))
  javapath <- Sys.which("java")
  if(identical(javapath, "")){
    stop("PATH to JAVA not found. Please check JAVA is installed.")
  }
  syml <- system.file("yaml", "seleniumserver.yml", package = "wdman")
  if(verbose) message("checking Selenium Server versions:")
  process_yaml(syml, verbose)
  selplat <- "generic"
  selver <- binman::list_versions("seleniumserver")[[selplat]]
  selver <- if(identical(version, "latest")){
    as.character(max(binman::sem_ver(selver)))
  }else{
    mtch <- match(version, selver)
    if(is.na(mtch) || is.null(mtch)){
      stop("version requested doesnt match versions available = ",
           paste(selver, collpase = ","))
    }
    selver[mtch]
  }
  seldir <- normalizePath(
    file.path(app_dir("seleniumserver"), selplat, selver)
  )
  selpath <- list.files(seldir,
                        pattern = "selenium-server-standalone",
                        full.names = TRUE)
  if(file.access(selpath, 1) < 0){
    Sys.chmod(selpath, '0755')
  }
  jvmargs <- c()
  selargs <- c()
  if(!is.null(chromever)){
    chromecheck <- chrome_check(verbose)
    cver <- chrome_ver(chromecheck[["platform"]], chromever)
    jvmargs[["chrome"]] <- sprintf(
      "-Dwebdriver.chrome.driver=%s",
      cver[["path"]]
    )
  }
  if(!is.null(geckover)){
    geckocheck <- gecko_check(verbose)
    gver <- gecko_ver(geckocheck[["platform"]], geckover)
    jvmargs[["gecko"]] <- sprintf(
      "-Dwebdriver.gecko.driver=%s",
      gver[["path"]]
    )
  }
  if(!is.null(phantomver)){
    phantomcheck <- phantom_check(verbose)
    pver <- phantom_ver(phantomcheck[["platform"]], phantomver)
    jvmargs[["phantom"]] <- sprintf(
      "-Dphantomjs.binary.path=%s",
      pver[["path"]]
    )
  }
  if(!is.null(iedrver)){
    iecheck <- ie_check(verbose)
    iever <- ie_ver(iecheck[["platform"]], iedrver)
    jvmargs[["internetexplorer"]] <- sprintf(
      "-Dwebdriver.ie.driver=%s",
      iever[["path"]]
    )
  }
  # should be the last JVM argument
  jvmargs[["jar"]] <- "-jar"
  jvmargs[["selpath"]] <- selpath
  # Selenium JAR arguments
  selargs[["portswitch"]] <- "-port"
  selargs[["port"]] <- port

  seleniumdrv <- subprocess::spawn_process(
    javapath, arguments = c(jvmargs, selargs)
  )
  if(!is.na(subprocess::process_return_code(seleniumdrv))){
    stop("Selenium server couldn't be started",
         subprocess::process_read(seleniumdrv, "stderr"))
  }
  startlog <- selenium_start_log(seleniumdrv)
  if(length(startlog) >0){
    if(any(grepl("Address already in use", startlog))){
      subprocess::process_kill(seleniumdrv)
      stop("Selenium server signals port = ", port, " is already in use.")
    }
  }
  log <- data.frame(type = "stderr", message = startlog,
                    stringsAsFactors = FALSE)
  selenium_read <- function(pipe = "stdout", timeout = 0L){
    msg <- subprocess::process_read(seleniumdrv, pipe = pipe,
                                    timeout = timeout)
    if(length(msg) > 0){
      log <<- rbind.data.frame(log, data.frame(type = pipe,
                                               message = msg,
                                               stringsAsFactors = FALSE))
    }
    msg
  }
  list(
    process = seleniumdrv,
    output = function(timeout = 0L){selenium_read(timeout = timeout)},
    error = function(timeout = 0L){selenium_read("stderr",
                                                 timeout = timeout)},
    stop = function(){subprocess::process_kill(seleniumdrv)},
    log = function(){selenium_read(); selenium_read("stderr"); log}
  )
}


selenium_start_log <- function(handle, poll = 3000L){
  startlog <- c()
  progress <- 0L
  while(progress < poll){
    begin <- Sys.time()
    errchk <- tryCatch(
      subprocess::process_read(handle, "stderr",
                               timeout = min(500L, poll)),
      error = function(e){
        e
      }
    )
    end <- Sys.time()
    progress <- progress + min(as.numeric(end-begin), 500L, poll)
    startlog <- c(startlog, errchk)
    selup <- any(grepl("Selenium Server is up and running", errchk))
    nocontent <- identical(errchk, character(0))
    if(selup || nocontent){break}
  }
  startlog
}