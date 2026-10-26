# Verifica il chiamante compilato con Pj sorella e confronti statistici indipendenti in R.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L) stop('Pass the installed ClinicoPathPj R library directory.')
.libPaths(c(normalizePath(args[1],winslash='/'),.libPaths()))
library(ClinicoPathPj)
jmvcore:::initProtoBuf()
baseLibraries <- .libPaths()
stage <- tempfile('cpj-comparison-check-')
dir.create(stage)
fixture <- read.csv(system.file('pj-service','pj_diagnostic_teaching.csv',package='ClinicoPathPj',mustWork=TRUE),stringsAsFactors=FALSE)
fixture$Reference <- factor(fixture$Reference)
run <- function(mode='jamovi',direction='high',criterion='errors',cutoff='',dataset=fixture,positive='Positive') {
    obj <- ClinicoPathPj:::pjDiagnosticClass$new(
        options=ClinicoPathPj:::pjDiagnosticOptions$new(marker='Measurement',reference='Reference',positive=positive,
            python=mode,direction=direction,criterion=criterion,cutoff=cutoff),data=dataset)
    obj$run()
    obj
}
for(mode in c('jamovi','system'))for(direction in c('high','low'))for(criterion in c('errors','youden')) {
    obj <- run(mode,direction,criterion,cutoff='0.5')
    message <- obj$results$status$content
    if(grepl('failed',message,fixed=TRUE)) stop(message)
    actual <- obj$results$counts$asDF$n
    pred <- if(direction=='high')fixture$Measurement>=0.5 else fixture$Measurement<=0.5
    truth <- fixture$Reference=='Positive'
    expected <- c(sum(pred&truth),sum(pred&!truth),sum(!pred&truth),sum(!pred&!truth))
    stopifnot(identical(as.integer(actual),as.integer(expected)))
    metrics <- obj$results$metrics$asDF
    nums <- c(expected[1],expected[4],expected[1],expected[4],expected[1]+expected[4])
    dens <- c(sum(truth),sum(!truth),sum(pred),sum(!pred),length(truth))
    for(i in seq_along(nums))if(dens[i]) {
        ci <- binom.test(nums[i],dens[i])$conf.int
        stopifnot(abs(metrics$estimate[i]-nums[i]/dens[i])<1e-12,
                  max(abs(c(metrics$lower[i],metrics$upper[i])-ci))<1e-9)
    }
    automatic <- run(mode,direction,criterion)
    if(grepl('failed',automatic$results$status$content,fixed=TRUE))stop(automatic$results$status$content)
    candidates <- c(min(fixture$Measurement)-1,unique(fixture$Measurement),max(fixture$Measurement)+1)
    losses <- vapply(candidates,function(cut) {
        pred <- if(direction=='high') fixture$Measurement>=cut else fixture$Measurement<=cut
        fp <- sum(pred&!truth); fn <- sum(!pred&truth)
        if(criterion=='errors')fp+fn else fp/sum(!truth)+fn/sum(truth)-1
    },numeric(1))
    counts <- automatic$results$counts$asDF$n
    loss <- if(criterion=='errors')counts[2]+counts[3] else counts[2]/sum(!truth)+counts[3]/sum(truth)-1
    stopifnot(abs(loss-min(losses))<1e-12)
    # La stessa opzione che arriva dal browser deve modificare i risultati nativi al nuovo run.
    changed <- run(mode,direction,criterion,cutoff='0.2')
    stopifnot(!identical(changed$results$counts$asDF$n,actual))
    html <- obj$results$explorer$content
    stopifnot(grepl("window.setOption('cutoff',String(current))",html,fixed=TRUE))
    writeLines(paste0('<!doctype html><meta charset="utf-8">',html),
        file.path(stage,paste0('diagnostic_',mode,'_',direction,'_',criterion,'.html')),useBytes=TRUE)
    cat(mode,direction,criterion,'counts/exact CI/automatic optimum/option rerun PASSED\n')
}
for(mode in c('jamovi','system')) {
    invalid <- run(mode,cutoff='not a number')
    stopifnot(grepl('failed',invalid$results$status$content,fixed=TRUE))
    extreme <- run(mode,cutoff='100')
    stopifnot(!grepl('failed',extreme$results$status$content,fixed=TRUE),is.na(extreme$results$metrics$asDF$estimate[3]))
    missing <- fixture
    missing$Measurement[1] <- NA_real_
    missing$Reference[2] <- NA
    excluded <- run(mode,dataset=missing)
    stopifnot(sum(excluded$results$counts$asDF$n)==nrow(fixture)-2L)
    recovery <- run(mode)
    stopifnot(!grepl('failed',recovery$results$status$content,fixed=TRUE))
}
stopifnot(identical(baseLibraries,.libPaths()))
writeLines('PASSED current host: both interpreters, native counts, exact intervals, both directions/criteria, automatic optimum, applied option rerun, missing/undefined/error/recovery.',file.path(stage,'BACKEND_PASSED.txt'))

cat('Reports written to: ',stage,'\n',sep='')

cat('Reports written to: ',stage,'\n',sep='')
