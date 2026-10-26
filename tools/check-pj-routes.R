# Confronto dei due percorsi completi sugli stessi dati e sulle stesse opzioni.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L) stop('Pass the installed ClinicoPathPj R library directory.')
.libPaths(c(normalizePath(args[1],winslash='/'),.libPaths()))
library(ClinicoPathPj)
jmvcore:::initProtoBuf()
stage <- tempfile('cpj-routes-')
dir.create(stage)
fixture <- read.csv(system.file('pj-service','pj_diagnostic_teaching.csv',package='ClinicoPathPj',mustWork=TRUE))
fixture$Reference <- factor(fixture$Reference)
timings <- list()
for(direction in c('high','low'))for(criterion in c('errors','youden'))for(cutoff in c('','0','4')) {
    results <- list()
    for(route in c('cp','pj')) {
        cls <- getFromNamespace(if(route=='cp')'cpDiagnosticClass' else 'pjDiagnosticClass','ClinicoPathPj')
        opts <- getFromNamespace(if(route=='cp')'cpDiagnosticOptions' else 'pjDiagnosticOptions','ClinicoPathPj')
        args <- list(marker='Measurement',reference='Reference',positive='Positive',direction=direction,criterion=criterion,cutoff=cutoff)
        if(route=='pj')args$python <- 'jamovi'
        obj <- cls$new(options=do.call(opts$new,args),data=fixture)
        start <- proc.time()[['elapsed']]
        obj$run()
        elapsed <- proc.time()[['elapsed']]-start
        if(route=='pj')stopifnot(!grepl('failed',obj$results$status$content,fixed=TRUE))
        stopifnot(grepl('backend elapsed',obj$results$timing$content,fixed=TRUE))
        results[[route]] <- list(counts=obj$results$counts$asDF,metrics=obj$results$metrics$asDF)
        timings[[length(timings)+1L]] <- data.frame(route=route,direction=direction,criterion=criterion,cutoff=if(nzchar(cutoff))cutoff else 'automatic',seconds=elapsed)
        if(direction=='high'&&criterion=='errors'&&cutoff=='4') {
            html <- obj$results$explorer$content
            writeLines(paste0('<!doctype html><meta charset="utf-8">',html),file.path(stage,paste0('comparison_',route,'.html')),useBytes=TRUE)
            stopifnot(identical(as.integer(results[[route]]$counts$n),c(14L,0L,41L,125L)))
        }
    }
    stopifnot(identical(results$cp$counts$n,results$pj$counts$n))
    for(col in c('estimate','lower','upper'))stopifnot(isTRUE(all.equal(results$cp$metrics[[col]],results$pj$metrics[[col]],tolerance=1e-10)))
    cat(direction,criterion,if(nzchar(cutoff))cutoff else 'automatic','both routes counts/exact intervals PASSED\n')
}
write.csv(do.call(rbind,timings),file.path(stage,'FULL_ROUTE_TIMINGS.csv'),row.names=FALSE)
writeLines('PASSED current host embedded Python: original ClinicoPathPj/processx and Pj service/system2 routes, 12 matched configurations with identical native counts and exact intervals. Timings include different complete analysis workloads; browser excluded.',file.path(stage,'COMPARISON_PASSED.txt'))

cat('Reports written to: ',stage,'\n',sep='')

cat('Reports written to: ',stage,'\n',sep='')
