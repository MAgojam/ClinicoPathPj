# Confronto locale: ponte processx e analisi originale, senza passare dal servizio Pj.
.mzCPComparePython <- function() {
    if(!identical(Sys.info()[['sysname']],'Windows')) return(.cpjPython())
    home <- Sys.getenv('PYTHONHOME')
    candidates <- c(if(nzchar(home))file.path(home,'python.exe'),
                    file.path(dirname(normalizePath(R.home(),winslash='/',mustWork=TRUE)),'python','python.exe'))
    candidates <- candidates[file.exists(candidates)]
    if(!length(candidates))stop('The comparison could not locate jamovi Python on Windows.',call.=FALSE)
    path <- normalizePath(candidates[1],winslash='/',mustWork=TRUE)
    list(path=path,env=c(PYTHONHOME=dirname(path),PYTHONPATH=''))
}

cpDiagnosticClass <- R6::R6Class('cpDiagnosticClass',inherit=cpDiagnosticBase,
    private=list(.run=function() {
        started <- proc.time()[['elapsed']]
        on.exit(self$results$timing$setContent(paste0('<p><strong>ClinicoPathPj bridge &middot; processx</strong> &middot; backend elapsed: ',
            sprintf('%.3f',proc.time()[['elapsed']]-started),' s.</p><p style="font-size:12px;color:#64748b">',
            'Includes Python startup, imports, calculation, JSON and native result mapping. Excludes browser drawing. ',
            'Use the same data, cutoff and jamovi Python in both comparison entries. Different graphical workloads: not a transport-only benchmark.</p>')),add=TRUE)
        .cpjRun(self,'pydotdecision',options=c('marker','reference','positive','direction','criterion','cutoff','logScale'),
            numeric='marker',required=c(marker='Numeric test measurement',reference='Binary reference classification'),
            events=c(positive='reference'),checkpoint=function()private$.checkpoint(flush=FALSE),
            pythonOverride=.mzCPComparePython())
    }))
