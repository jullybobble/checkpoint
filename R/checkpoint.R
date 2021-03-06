#' Configures R session to use packages as they existed on CRAN at time of snapshot.
#'
#' Together, the checkpoint package and the checkpoint server act as a CRAN time machine.  The \code{checkpoint()} function installs the packages referenced in the specified project to a local library exactly as they existed at the specified point in time.  Only those packages are available to your session, thereby avoiding any package updates that came later and may have altered your results.  In this way, anyone using the checkpoint \code{checkpoint()} function can ensure the reproducibility of your scripts or projects at any time.
#'
#' @section Details:
#'
#' \code{checkpoint()} creates a local library into which it installs a copy of the packages required by your project as they existed on CRAN on the specified snapshot date.  Your R session is updated to use only these packages.
#'
#' To automatically determine all packages used in your project, the function scans all R code (\code{.R}, \code{.Rmd}, and \code{.Rpres} files) for \code{library()} and \code{requires()} statements.
#'
#' Specifically, the function will:
#'
#' \itemize{
#' \item{Create a new local snapshot library to install packages.  This library folder is at \code{~/.checkpoint}}
#' \item{Update the options for your CRAN mirror and point to an MRAN snapshot using \code{options(repos)}}
#' \item{Scan your project folder for all required packages and install them from the snapshot using \code{\link[utils]{install.packages}}}
#' }
#'
#' @section Resetting the checkpoint:
#' To reset the checkpoint, simply restart your R session.
#'
#' @param snapshotDate Date of snapshot to use in \code{YYYY-MM-DD} format,e.g. \code{"2014-09-17"}.  Specify a date on or after \code{"2014-09-17"}.  MRAN takes one snapshot per day.
#'
#' @param project A project path.  This is the path to the root of the project that references the packages to be installed from the MRAN snapshot for the date specified for \code{snapshotDate}.  Defaults to current working directory using \code{\link{getwd}()}.
#'
#'
#' @param verbose If TRUE, displays progress messages.
#'
#'
#' @return NULL.  See the \code{Details} section for side effects.
#'
#' @export
#'
#' @example /inst/examples/example_checkpoint.R
#'

checkpoint <- function(snapshotDate, project = getwd(), verbose=TRUE) {

  createFolders(snapshotDate)
  snapshoturl <- getSnapshotUrl(snapshotDate=snapshotDate)

  # set repos
  setMranMirror(snapshotUrl = snapshoturl)

  # Set lib path
  setLibPaths(snapshotDate)

  mssg(verbose, "Scanning for loaded pkgs")

  # Scan for packages used
  mssg(verbose, "Scanning for packages used in this project")
  exclude.packages = c("checkpoint", # this very package
                       c("base", "compiler", "datasets", "graphics", "grDevices", "grid",
                         "methods", "parallel", "splines", "stats", "stats4", "tcltk",
                         "tools", "utils"))  # all base priority packages, not on CRAN or MRAN
  packages.to.install = setdiff(projectScanPackages(project), exclude.packages)

  # install missing packages

  if(length(packages.to.install) > 0) {
    mssg(verbose, "Installing packages used in this project ")
    utils::install.packages(pkgs = packages.to.install, verbose=FALSE, quiet=TRUE)
  } else {
    mssg(verbose, "No packages found to install")
  }

  # detach and reload checkpointed pkgs already loaded
  search.path = search()
  lapply(
    unlist(
      lapply(
        packages.to.install,
        grep,
        x = search.path)),
    function(x) {
      detach(x, unload = TRUE, force = TRUE)
      library(search.path[x], character.only = TRUE)})

  NULL}

setMranMirror <- function(snapshotDate, snapshotUrl = checkpoint:::getSnapShotUrl(snapshotDate)){
  options(repos = snapshotUrl)}

setLibPaths <- function(snapshotDate, libPath=checkpointPath(snapshotDate, "lib")){
  assign(".lib.loc", libPath, envir = environment(.libPaths))}

mranUrl <- function()"http://mran.revolutionanalytics.com/snapshot/"

getSnapshotUrl <- function(snapshotDate, url = mranUrl()){
  mran.root = url(url)
  on.exit(close(mran.root))
  tryCatch(
    suppressWarnings(readLines(mran.root)),
    error =
      function(e) {
        stop(sprintf("Unable to reach MRAN: %s", e$message))})
  snapshot.url = paste(gsub("/$", "", url), snapshotDate, sep = "/")
  con = url(snapshot.url)
  on.exit(close(con), add = TRUE)
  tryCatch(
    suppressWarnings(readLines(con)),
    error =
      function(e) {
        stop("Unable to find snapshot on MRAN")})
  snapshot.url}


mssg <- function(x, ...) if(x) message(...)
