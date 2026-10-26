# Cerca il Pj installato accanto al modulo chiamante, senza incorporarne una copia.
mzCPConnect <- function() {
    if ('Pj' %in% loadedNamespaces()) {
        namespace <- getNamespace('Pj')
    } else {
        libraries <- .libPaths()
        bases <- strsplit(Sys.getenv('JAMOVI_MODULES_PATH'),.Platform$path.sep,fixed=TRUE)[[1]]
        candidates <- unique(c(libraries,file.path(dirname(dirname(libraries)),'Pj','R'),
                               file.path(bases[nzchar(bases)],'Pj','R')))
        candidates <- candidates[file.exists(file.path(candidates,'Pj','DESCRIPTION'))]
        if(!length(candidates))stop('Install Pj 1.3.0 or newer and restart jamovi.',call.=FALSE)
        namespace <- loadNamespace('Pj',lib.loc=candidates[1])
    }
    if(!all(c('mzPjServiceInfo','mzPjRunPython') %in% getNamespaceExports(namespace)))
        stop('The installed Pj has no service API. Update Pj and restart jamovi.',call.=FALSE)
    info <- getExportedValue('Pj','mzPjServiceInfo')()
    if(utils::compareVersion(info$module_version,'1.3.0')<0L || !identical(info$api_version,1L))
        stop('This comparison requires Pj 1.3.0 or newer with service API version 1.',call.=FALSE)
    list(info=info,run=getExportedValue('Pj','mzPjRunPython'))
}
