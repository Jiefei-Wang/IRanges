### =========================================================================
### AtomicList objects
### -------------------------------------------------------------------------


## A list that holds atomic objects

setClass("AtomicList", representation("VIRTUAL"),
        prototype = prototype(elementType = "logical"),
        contains = "List")

setClass("LogicalList", representation("VIRTUAL"),
         prototype = prototype(elementType = "logical"),
         contains = "AtomicList")

setClass("IntegerList", representation("VIRTUAL"),
         prototype = prototype(elementType = "integer"),
         contains = "AtomicList")

setClass("NumericList", representation("VIRTUAL"),
         prototype = prototype(elementType = "numeric"),
         contains = "AtomicList")

setClass("ComplexList", representation("VIRTUAL"),
         prototype = prototype(elementType = "complex"),
         contains = "AtomicList")

setClass("CharacterList", representation("VIRTUAL"),
         prototype = prototype(elementType = "character"),
         contains = "AtomicList")

setClass("RawList", representation("VIRTUAL"),
         prototype = prototype(elementType = "raw"),
         contains = "AtomicList")

setClass("RleList", representation("VIRTUAL"),
         prototype = prototype(elementType = "Rle"),
         contains = "AtomicList")

setClass("FactorList", representation("VIRTUAL"),
         prototype = prototype(elementType = "factor"),
         contains = "IntegerList")

setClass("SimpleAtomicList",
         contains =  c("AtomicList", "SimpleList"),
         representation("VIRTUAL"))
 
setClass("SimpleLogicalList",
         prototype = prototype(elementType = "logical"),
         contains = c("LogicalList", "SimpleAtomicList"))

setClass("SimpleIntegerList",
         prototype = prototype(elementType = "integer"),
         contains = c("IntegerList", "SimpleAtomicList"))

setClass("SimpleNumericList",
         prototype = prototype(elementType = "numeric"),
         contains = c("NumericList", "SimpleAtomicList"))

setClass("SimpleComplexList",
         prototype = prototype(elementType = "complex"),
         contains = c("ComplexList", "SimpleAtomicList"))

setClass("SimpleCharacterList",
         prototype = prototype(elementType = "character"),
         contains = c("CharacterList", "SimpleAtomicList"))

setClass("SimpleRawList",
         prototype = prototype(elementType = "raw"),
         contains = c("RawList", "SimpleAtomicList"))

setClass("SimpleRleList",
         prototype = prototype(elementType = "Rle"),
         contains = c("RleList", "SimpleAtomicList"))

setClass("SimpleFactorList",
         prototype = prototype(elementType = "factor"),
         contains = c("FactorList", "SimpleAtomicList"))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructors
###

.dotargsAsList <- function(type, ...) {
  listData <- list(...)
  if (length(listData) == 1) {
      arg1 <- listData[[1]]
      if (is.list(arg1) || is(arg1, "List"))
        listData <- arg1
      else if (type == "integer" && class(arg1) == "character")
        listData <- strsplitAsListOfIntegerVectors(arg1) # weird special case
  }
  listData
}

AtomicListConstructor <- function(type, compress.default = TRUE) {
  constructor <- eval(substitute(function(..., compress = compress.default) {
    if (!isTRUEorFALSE(compress))
      stop("'compress' must be TRUE or FALSE")
    listData <- .dotargsAsList(type, ...)
    CompressedOrSimple <- if (compress) "Compressed" else "Simple"
    if (is(listData, S4Vectors:::listClassName(CompressedOrSimple, type)))
      listData
    else CoercerToList(type, compress)(listData)
  }, list(type = type)))
  formals(constructor)$compress <- compress.default
  constructor
}

LogicalList <- AtomicListConstructor("logical")
IntegerList <- AtomicListConstructor("integer")
NumericList <- AtomicListConstructor("numeric")
ComplexList <- AtomicListConstructor("complex")
CharacterList <- AtomicListConstructor("character")
RawList <- AtomicListConstructor("raw")
RleList <- AtomicListConstructor("Rle")
FactorList <- AtomicListConstructor("factor")


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion
###

### Equivalent to 'as.vector(as.list(x), mode=mode)' but faster on
### CompressedAtomicList objects (10x, 75x, or more, depending on 'length(x)').
setMethod("as.vector", "AtomicList",
    function(x, mode="any")
    {
        valid_modes <- c("any", S4Vectors:::ATOMIC_TYPES, "double", "list")
        mode <- match.arg(mode, valid_modes)
        if (mode %in% c("any", "list"))
            return(as.list(x))
        x_eltNROWS <- elementNROWS(x)
        if (any(x_eltNROWS > 1L))
            stop("coercing an AtomicList object to an atomic vector ",
                 "is supported only for\n",
                 "  objects with top-level elements of length <= 1")
        ans <- base::rep.int(as.vector(NA, mode=mode), length(x))
        ans[x_eltNROWS == 1L] <- as.vector(unlist(x, use.names=FALSE),
                                           mode=mode)
        ans
    }
)

as.matrix.AtomicList <- function(x, col.names=NULL, ...) {
    p <- PartitioningByEnd(x)
    vx <- decode(unlist(x, use.names=FALSE))
    if (is.null(col.names)) {
        col.names <- names(vx)
    }
    if (is.null(col.names) || is.character(col.names)) {
        col.ind <- unlist_as_integer(IRanges(1, width(p)))
    } else if (is.list(col.names) || is(col.names, "List")) {
        col.names <- unlist(col.names, use.names=FALSE)
        if (is.factor(col.names)) {
            col.ind <- as.integer(col.names)
            col.names <- levels(col.names)
        } else {
            col.ind <- selfmatch(col.names)
            col.names <- col.names[col.ind == seq_along(col.ind)]
        }
    } else {
        stop("'col.names' should be NULL, a character vector or list")
    }
    row.ind <- togroup(p)
    nc <- if (!is.null(col.names)) length(col.names) else max(width(p))
    m <- matrix(nrow=length(x), ncol=nc)
    m[cbind(row.ind, col.ind)] <- vx
    if (!is.null(col.names))
        colnames(m) <- col.names
    m
}
setMethod("as.matrix", "AtomicList", function(x, col.names=NULL)
    as.matrix.AtomicList(x, col.names))

setMethod("drop", "AtomicList", function(x) {
  x_eltNROWS <- elementNROWS(x)
  if (any(x_eltNROWS > 1))
    stop("All element lengths must be <= 1")
  x_dropped <- rep.int(NA, sum(x_eltNROWS))
  x_unlisted <- unlist(x, use.names = FALSE)
  x_dropped[x_eltNROWS > 0L] <- x_unlisted
  if (is.factor(x_unlisted)) {
      x_dropped <- structure(as.integer(x_dropped), levels=levels(x_unlisted),
                             class="factor")
  }
  names(x_dropped) <- names(x)
  x_dropped
})

CoercerToList <- function(type, compress) {
  .coerceToList <- if (compress)
                     coerceToCompressedList
                   else
                     S4Vectors:::coerceToSimpleList
  function(from) {
    .coerceToList(from, type)
  }
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### General methods
###

### Could actually be made the "table" method for List objects. Will work on
### any List object 'x' for which 'as.factor(unlist(x))' works.
setMethod("table", "AtomicList",
    function(...)
    {
        args <- list(...)
        if (length(args) != 1L)
            stop("\"table\" method for AtomicList objects ",
                 "can only take one input object")
        x <- args[[1L]]
        if (!pcompareRecursively(x)) {
            ## Not sure why callNextMethod() doesn't work. Is it because of
            ## dispatch on the ellipsis?
            #return(callNextMethod())
            return(selectMethod("table", "Vector")(...))
        }
        y1 <- togroup(PartitioningByWidth(x))
        attributes(y1) <- list(levels=as.character(seq_along(x)),
                               class="factor")
        y2 <- as.factor(unlist(x, use.names=FALSE))
        ans <- table(y1, y2)
        names(dimnames(ans)) <- NULL
        x_names <- names(x)
        if (!is.null(x_names))
            rownames(ans) <- x_names
        ans
    }
)

setMethod("table", "SimpleAtomicList", function(...)
{
    args <- list(...)
    if (length(args) != 1L)
        stop("\"table\" method for SimpleAtomicList objects ",
             "can only take one input object")
    x <- args[[1L]]
    levs <- sort(unique(unlist(lapply(x, function(xi) {
        if (!is.null(levels(xi))) levels(xi) else unique(xi)
    }), use.names=FALSE)))
    as.table(do.call(rbind,
                     lapply(x, function(xi) {
                         if (is(xi, "Rle"))
                             runValue(xi) <- factor(runValue(xi), levs)
                         else xi <- factor(xi, levs)
                         table(xi)
                     })))
})


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Rle methods
###

### 'use.names' is ignored.
setMethod("unlist", "SimpleRleList",
    function (x, recursive=TRUE, use.names=TRUE)
    {
        if (!identical(recursive, TRUE))
            stop("\"unlist\" method for SimpleRleList objects ",
                 "does not support the 'recursive' argument")
        if (length(x) == 0L)
            return(Rle())
        ans_values <- unlist(lapply(x@listData, slot, "values"),
                             use.names=FALSE)
        ans_lengths <- unlist(lapply(x@listData, slot, "lengths"),
                              use.names=FALSE)
        Rle(ans_values, ans_lengths)
    }
)

setMethod("runLength", "RleList", function(x) {
  as(lapply(x, runLength), "IntegerList")
})

setMethod("runValue", "RleList", function(x) {
  as(lapply(x, runValue), "List")
})

setReplaceMethod("runValue", "SimpleRleList",
                 function(x, value) {
                   if (!identical(elementNROWS(ranges(x)),
                                  elementNROWS(value)))
                     stop("elementNROWS() of 'x' and 'value' must match")
                   x@listData <- mapply(function(rle, v) {
                     runValue(rle) <- v
                     rle
                   }, x, value, SIMPLIFY=FALSE)
                   x
                 })

setMethod("ranges", "RleList", function(x, use.names=TRUE, use.mcols=FALSE) {
  as(lapply(x, ranges, use.names=use.names, use.mcols=use.mcols), "List")
})

diceRangesByList <- function(x, list) {
  listPart <- PartitioningByEnd(list)
  ## 'x' cannot contain empty ranges so using
  ## 'hit.empty.query.ranges=TRUE' won't affect the result but
  ## it makes findOverlaps_IntegerRanges_Partitioning() just a little
  ## bit faster.
  hits <- findOverlaps_IntegerRanges_Partitioning(
              x, listPart,
              hit.empty.query.ranges=TRUE)
  ov <- overlapsRanges(x, listPart, hits)
  ans_unlistData <- shift(ov, 1L - start(listPart)[subjectHits(hits)])
  ans_partitioning <- PartitioningByEnd(subjectHits(hits), NG=length(list))
  ans <- relist(ans_unlistData, ans_partitioning)
  names(ans) <- names(list)
  ans
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Factor methods
###

setMethod("levels", "FactorList", function(x) {
  CharacterList(lapply(x, levels))
})

setMethod("unlist", "SimpleFactorList",
          function(x, recursive = TRUE, use.names = TRUE) {
            levs <- levels(x)
            if (length(x) > 1L &&
                !all(vapply(levs[-1L], identical, logical(1L), levs[[1L]]))) {
              stop("inconsistent level sets")
            }
            structure(callNextMethod(),
                      levels=as.character(levs[[1L]]),
                      class="factor")
          })


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The "show" method.
###

.showAtomicList <- function(object, minLines, ...)
{
    len <- length(object)
    object_names <- names(object)
    k <- min(minLines, len)
    d <- len - minLines
    for (i in seq_len(k)) {
        if (is.null(object_names)) {
            label <- i
        } else {
            nm <- object_names[[i]]
            if (is.na(nm)) {
                label <- "NA"
            } else {
                label <- paste0("\"", nm, "\"")
            }
        }
        label <- paste0("[[", label, "]]")
        if (length(object[[i]]) == 0) {
            cat(label, " ", sep = "")
            print(object[[i]])
        } else {
            cat(S4Vectors:::labeledLine(label, object[[i]], labelSep = "",
                                        count = FALSE))
        }
    }
    if (d > 0)
        cat("...\n<", d,
            ifelse(d == 1,
                   " more element>\n", " more elements>\n"), sep="")
}

setMethod("show", "AtomicList",
          function(object) 
          {
              cat(classNameForDisplay(object), " of length ",
                  length(object), "\n", sep = "")
              .showAtomicList(object, 10) 
          }
)

setMethod("show", "RleList",
          function(object) {
              lo <- length(object)
              k <- min(5, length(object))
              diffK <- lo - 5
              cat(classNameForDisplay(object), " of length ", lo,
                  "\n", sep = "")
              show(as.list(head(object, k)))
              if (diffK > 0)
                  cat("...\n<", diffK,
                      ifelse(diffK == 1,
                             " more element>\n", " more elements>\n"),
                      sep="")
          })
