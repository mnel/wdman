% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/chrome.R
\name{chrome}
\alias{chrome}
\title{Start chrome driver}
\usage{
chrome(port = 4567L, version = "latest", path = "wd/hub", check = TRUE,
  verbose = TRUE, retcommand = FALSE, ...)
}
\arguments{
\item{port}{Port to run on}

\item{version}{what version of chromedriver to run. Default = "latest"
which runs the most recent version. To see other version currently
sourced run binman::list_versions("chromedriver")}

\item{path}{base URL path prefix for commands, e.g. wd/hub}

\item{check}{If TRUE check the versions of chromedriver available. If
new versions are available they will be downloaded.}

\item{verbose}{If TRUE, include status messages (if any)}

\item{retcommand}{If TRUE return only the command that would be passed
to \code{\link{spawn_process}}}

\item{...}{pass additional options to the driver}
}
\value{
Returns a list with named elements process, output, error, stop
    and log. process is the output from calling \code{\link{spawn_process}}
    output, error and stop are functions calling
    \code{\link{process_read}}, \code{\link{process_read}} with "stderr"
    pipe and \code{\link{process_kill}}  respectively  on process.
    log is a function which returns the contents of the log file.
}
\description{
Start chrome driver
}
\examples{
\dontrun{
cDrv <- chrome()
cDrv$output()
cDrv$stop()
}
}

