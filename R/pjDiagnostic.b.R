# Analisi sperimentale ospite: delega a Pj calcoli Python e HTML/D3.
pjDiagnosticClass <- R6::R6Class('pjDiagnosticClass', inherit=pjDiagnosticBase,
    private=list(
    .init=function() {
        # La fase iniziale deve conservare i posti dei risultati durante un ricalcolo valido.
        configured <- length(self$options$marker)==1L && length(self$options$reference)==1L &&
            length(self$options$positive)==1L && !is.na(self$options$positive) && nzchar(self$options$positive)
        for(name in c('explorer','counts','metrics')) self$results[[name]]$setVisible(configured)
    },
    .run=function() {
        started <- proc.time()[['elapsed']]
        on.exit(self$results$timing$setContent(paste0('<p><strong>Pj service &middot; system2</strong> &middot; backend elapsed: ',
            sprintf('%.3f',proc.time()[['elapsed']]-started),' s.</p><p style="font-size:12px;color:#64748b">',
            'Includes service preparation, Python startup, imports, calculation, JSON and native result mapping. Excludes browser drawing. ',
            'Use the same data, cutoff and jamovi Python in both comparison entries. Different graphical workloads: not a transport-only benchmark.</p>')),add=TRUE)
        escape <- function(x) {
            x <- gsub('&','&amp;',x,fixed=TRUE)
            x <- gsub('<','&lt;',x,fixed=TRUE)
            gsub('>','&gt;',x,fixed=TRUE)
        }
        tryCatch({
            marker <- self$options$marker
            reference <- self$options$reference
            positive <- self$options$positive
            if(is.null(marker)||is.null(reference)||is.null(positive)||!nzchar(positive)) {
                for(name in c('explorer','counts','metrics')) self$results[[name]]$setVisible(FALSE)
                self$results$counts$deleteRows()
                self$results$metrics$deleteRows()
                self$results$status$setContent('<p>Select a numeric measurement, a binary reference and its positive level.</p>')
                return()
            }
            if(identical(marker,reference)) stop('Measurement and reference must be different columns.',call.=FALSE)
            values <- self$data[[marker]]
            group <- self$data[[reference]]
            if(!is.numeric(values)) stop('The measurement must be numeric.',call.=FALSE)
            if(any(is.infinite(values))) stop('Infinite measurements are not supported.',call.=FALSE)
            levels <- if(is.factor(group)) levels(group) else unique(as.character(group[!is.na(group)]))
            if(length(levels)!=2L||!positive %in% levels) stop('Select the positive level of a binary reference.',call.=FALSE)
            service <- mzCPConnect()
            config <- list(positive=as.character(positive),direction=self$options$direction,
                           criterion=self$options$criterion,cutoff=self$options$cutoff,marker_label=marker)
            # Identita stabile dell'analisi, senza condividere il DOM fra istanze diverse.
            if(nzchar(as.character(self$analysisId)))
                config$root_id <- paste0('mzpj_cutoff_',gsub('[^A-Za-z0-9_]','_',as.character(self$analysisId)))
            resource <- function(name) {
                path <- system.file('pj-service',name,package='ClinicoPathPj')
                if(!nzchar(path)) stop('A required experimental resource is missing.',call.=FALSE)
                paste(readLines(path,warn=FALSE,encoding='UTF-8'),collapse='\n')
            }
            encode <- function(x) gsub('[\r\n]','',jsonlite::base64_enc(charToRaw(enc2utf8(x))))
            # JSON e template passano come Base64: nessun dato viene interpolato come codice.
            code <- paste0('import json, base64\nCONFIG = json.loads(base64.b64decode("',
                encode(jsonlite::toJSON(config,auto_unbox=TRUE)), '").decode("utf-8"))\n',
                'TEMPLATE = base64.b64decode("',encode(resource('cutoff.html')),'").decode("utf-8")\n',
                resource('diagnostic.py'))
            response <- service$run(code=code,
                data=data.frame(marker=values,reference=as.character(group),stringsAsFactors=FALSE),
                python=self$options$python)
            item <- function(name) {
                found <- Filter(function(x)identical(x$name,name),response$items)
                if(length(found)!=1L) stop('Unexpected Pj service response.',call.=FALSE)
                found[[1]]
            }
            # Prima valida tutta la risposta, poi sostituisce insieme i risultati precedenti.
            plot <- item('explorer')$content
            summary <- item('summary')$content
            prepared <- list()
            for(name in c('counts','metrics')) {
                columns <- if(name=='counts')c('cell','n') else c('metric','estimate','lower','upper')
                prepared[[name]] <- lapply(item(name)$rows,function(row) {
                    if(length(row)!=length(columns)) stop('Unexpected Pj table schema.',call.=FALSE)
                    row <- lapply(row,function(value)if(is.null(value))NA else value)
                    setNames(row,columns)
                })
            }
            for(name in names(prepared)) {
                self$results[[name]]$deleteRows()
                for(i in seq_along(prepared[[name]]))
                    self$results[[name]]$addRow(rowKey=as.character(i),values=prepared[[name]][[i]])
                self$results[[name]]$setVisible(TRUE)
            }
            self$results$metrics$setNote('assumptions','Exact Clopper-Pearson 95% intervals assume independent rows and a fixed cutoff; they do not account for cutoff selection. Predictive values depend on sample group proportions.')
            # Come criterio generale gia verificato in Metafora, non sostituisce contenuto identico.
            # Protobuf puo perdere l'etichetta Encoding di R pur conservando gli stessi byte UTF-8.
            if(!identical(charToRaw(self$results$explorer$content),charToRaw(plot)))
                self$results$explorer$setContent(plot)
            self$results$explorer$setVisible(TRUE)
            self$results$status$setContent(paste0('<p><strong>Pj service API ',service$info$api_version,
                '</strong> &middot; ',escape(self$options$python),' Python &middot; ',
                escape(summary),'</p>'))
        },error=function(error) {
            for(name in c('explorer','counts','metrics')) self$results[[name]]$setVisible(FALSE)
            self$results$counts$deleteRows()
            self$results$metrics$deleteRows()
            message <- if(inherits(error,'mzPjServiceError')&&!is.null(error$details))error$details else conditionMessage(error)
            self$results$status$setContent(paste0('<p><strong>Analysis unavailable or failed</strong></p><pre style="white-space:pre-wrap">',escape(message),'</pre>'))
        })
    }))
