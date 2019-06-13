test_df <- DataFrame(msLevel = c(1L, 2L, 2L), scanIndex = 4:6)
test_df$mz <- list(c(1.1, 1.3, 1.5), c(4.1, 5.1), c(1.6, 1.7, 1.8, 1.9))
test_df$intensity <- list(c(45.1, 34, 12), c(234.4, 1333), c(42.1, 34.2, 65, 6))

test_that("backendInitialize,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    be <- backendInitialize(be)
    expect_true(validObject(be))
    expect_true(length(be@files) == 0)
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L))
    expect_true(validObject(be))
    expect_error(backendInitialize(be, spectraData = DataFrame(msLevel = 1L)),
                 "fromFile is/are")
    expect_error(backendInitialize(MsBackendDataFrame(),
                                   spectraData = DataFrame(msLevel = 1L,
                                                           fromFile = 1L)),
                 "'files' can not be empty")
    df <- test_df
    df$fromFile <- 1L
    be <- backendInitialize(be, files = NA_character_, df)
    expect_true(validObject(be))
    expect_true(is(be@spectraData$mz, "NumericList"))
    expect_true(is(be@spectraData$intensity, "NumericList"))

    df$mz <- SimpleList(df$mz)
    df$intensity <- SimpleList(df$intensity)
    be <- backendInitialize(be, files = NA_character_, df)
    expect_true(validObject(be))
    expect_true(is(be@spectraData$mz, "NumericList"))
    expect_true(is(be@spectraData$intensity, "NumericList"))

    df$mz <- NumericList(df$mz)
    df$intensity <- NumericList(df$intensity)
    be <- backendInitialize(be, files = NA_character_, df)
    expect_true(validObject(be))
    expect_true(is(be@spectraData$mz, "NumericList"))
    expect_true(is(be@spectraData$intensity, "NumericList"))
})

test_that("backendMerge,MsBackendDataFrame works", {
    df <- DataFrame(msLevel = c(1L, 2L, 2L), fromFile = 1L,
                    rtime = as.numeric(1:3))
    df2 <- DataFrame(msLevel = c(2L, 1L), fromFile = 1L,
                     rtime = c(4.1, 5.2), scanIndex = 1:2)
    df3 <- DataFrame(msLevel = c(1L, 2L), fromFile = 1L,
                     precScanNum = 1L, other_col = "z")
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    be2 <- backendInitialize(MsBackendDataFrame(), NA_character_, df2)
    be3 <- backendInitialize(MsBackendDataFrame(), NA_character_, df3)

    expect_equal(backendMerge(be), be)
    expect_error(backendMerge(be, 4), "backends of the same type")

    res <- backendMerge(be, be2, be3)
    expect_true(is(res, "MsBackendDataFrame"))
    expect_identical(res@files, NA_character_)
    expect_identical(res@modCount, 0L)
    expect_identical(msLevel(res), c(1L, 2L, 2L, 2L, 1L, 1L, 2L))
    expect_identical(rtime(res), c(1:3, 4.1, 5.2, NA, NA))
    expect_identical(res@spectraData$other_col,
                     Rle(c(rep(NA_character_, 5), "z", "z")))
    expect_true(is(be3@spectraData$precScanNum, "integer"))
    expect_true(is(res@spectraData$precScanNum, "Rle"))

    ## One backend with and one without m/z
    df2$mz <- list(c(1.1, 1.2), c(1.1, 1.2))
    df2$intensity <- list(c(12.4, 3), c(123.4, 1))
    be2 <- backendInitialize(MsBackendDataFrame(), NA_character_, df2)
    res <- backendMerge(be, be2, be3)
    expect_identical(lengths(mz(res)), c(0L, 0L, 0L, 2L, 2L, 0L, 0L))

    ## with multiple files
    a <- tempfile()
    cat("a", file = a)
    b <- tempfile()
    cat("b", file = b)
    c <- tempfile()
    cat("c", file = c)

    df$fromFile <- c(1L, 1L, 2L)
    be <- backendInitialize(MsBackendDataFrame(), c(b, a), df)
    expect_equal(fileNames(be), c(b, a))
    df2$fromFile <- c(1L, 2L)
    be2 <- backendInitialize(MsBackendDataFrame(), c(a, b), df2)
    be3 <- backendInitialize(MsBackendDataFrame(), c, df3)

    res <- backendMerge(be, be2, be3)
    expect_identical(res@files, c(b, a, c))
    expect_identical(fromFile(res), c(1L, 1L, 2L, 2L, 1L, 3L, 3L))
    expect_identical(rtime(res), c(1:3, 4.1, 5.2, NA, NA))
    expect_identical(rtime(res)[fromFile(res) == 1], c(1, 2, 5.2))

    ## different modCount
    be@modCount <- c(0L, 1L)
    be2@modCount <- c(0L, 3L)
    res <- backendMerge(be, be2, be3)
    expect_identical(res@modCount, c(3L, 1L, 0L))
})

test_that("acquisitionNum, MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(acquisitionNum(be), integer())
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = c(1L, 2L)))
    expect_equal(acquisitionNum(be), c(NA_integer_, NA_integer_))
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = 1L,
                                                    acquisitionNum = 1:10))
    expect_equal(acquisitionNum(be), 1:10)
})

test_that("centroided, centroided<-, MsBackendDataFrame work", {
    be <- MsBackendDataFrame()
    expect_equal(centroided(be), logical())
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = c(1L, 2L)))
    expect_equal(centroided(be), c(NA, NA))
    expect_error(centroided(be) <- "a", "to be a 'logical'")
    expect_error(centroided(be) <- c(FALSE, TRUE, TRUE), "has to be a")
    centroided(be) <- c(TRUE, FALSE)
    expect_equal(centroided(be), c(TRUE, FALSE))
    centroided(be) <- FALSE
    expect_equal(centroided(be), c(FALSE, FALSE))
})

test_that("collisionEnergy, collisionEnergy<-,MsBackendDataFrame work", {
    be <- MsBackendDataFrame()
    expect_equal(collisionEnergy(be), numeric())
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = c(1L, 2L)))
    expect_equal(collisionEnergy(be), c(NA_real_, NA_real_))
    expect_error(collisionEnergy(be) <- "a", "to be a 'numeric'")
    expect_error(collisionEnergy(be) <- c(2.3), "has to be a")
    collisionEnergy(be) <- c(2.1, 3.2)
    expect_equal(collisionEnergy(be), c(2.1, 3.2))
})

test_that("fromFile,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(fromFile(be), integer())
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = c(1L, 2L)))
    expect_equal(fromFile(be), c(1L, 1L))
})

test_that("intensity,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(intensity(be), NumericList(compress = FALSE))
    be <- backendInitialize(be, files = NA_character_,
                            spectraData = DataFrame(fromFile = 1L,
                                                    msLevel = c(1L, 2L)))
    expect_equal(intensity(be), NumericList(numeric(), numeric(),
                                            compress = FALSE))
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    df$intensity <- list(1:4, c(2.1, 3.4))
    df$mz <- list(1:4, 1:2)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(intensity(be), NumericList(1:4, c(2.1, 3.4), compress = FALSE))
})

test_that("intensity<-,MsBackendDataFrame works", {
    test_df$fromFile <- 1L
    be <- backendInitialize(MsBackendDataFrame(), files = NA_character_,
                            spectraData = test_df)

    new_ints <- lapply(test_df$intensity, function(z) z / 2)
    intensity(be) <- new_ints
    expect_identical(intensity(be), NumericList(new_ints, compress = FALSE))
    expect_identical(be@modCount, 1L)

    expect_error(intensity(be) <- 3, "has to be a list")
    expect_error(intensity(be) <- list(3, 2), "match the length")
    expect_error(intensity(be) <- list(3, 2, 4), "number of peaks")
})

test_that("ionCound,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(ionCount(be), numeric())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    df$intensity <- list(1:4, c(2.1, 3.4))
    df$mz <- list(1:4, 1:2)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(ionCount(be), c(sum(1:4), sum(c(2.1, 3.4))))
})

test_that("isEmpty,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(isEmpty(be), logical())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(isEmpty(be), c(TRUE, TRUE))
    df$intensity <- list(1:2, 1:5)
    df$mz <- list(1:2, 1:5)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(isEmpty(be), c(FALSE, FALSE))
})

test_that("isolationWindowLowerMz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_identical(isolationWindowLowerMz(be), numeric())

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 2L, 2L, 2L))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    expect_identical(isolationWindowLowerMz(be), rep(NA_real_, 5))
    isolationWindowLowerMz(be) <- c(NA_real_, 2, 2, 3, 3)
    expect_identical(isolationWindowLowerMz(be), c(NA_real_, 2, 2, 3, 3))

    df$isolationWindowLowerMz <- c(NA_real_, 4, 4, 3, 1)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    expect_identical(isolationWindowLowerMz(be), c(NA_real_, 4, 4, 3, 1))

    expect_error(isolationWindowLowerMz(be) <- 2.1, "of length 5")
})

test_that("isolationWindowTargetMz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_identical(isolationWindowTargetMz(be), numeric())

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 2L, 2L, 2L))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    expect_identical(isolationWindowTargetMz(be), rep(NA_real_, 5))
    isolationWindowTargetMz(be) <- c(NA_real_, 2, 2, 3, 3)
    expect_identical(isolationWindowTargetMz(be), c(NA_real_, 2, 2, 3, 3))

    df$isolationWindowTargetMz <- c(NA_real_, 4, 4, 3, 1)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    expect_identical(isolationWindowTargetMz(be), c(NA_real_, 4, 4, 3, 1))

    expect_error(isolationWindowTargetMz(be) <- 2.1, "of length 5")
})

test_that("isolationWindowUpperMz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_identical(isolationWindowUpperMz(be), numeric())

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 2L, 2L, 2L))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    expect_identical(isolationWindowUpperMz(be), rep(NA_real_, 5))
    isolationWindowUpperMz(be) <- c(NA_real_, 2, 2, 3, 3)
    expect_identical(isolationWindowUpperMz(be), c(NA_real_, 2, 2, 3, 3))

    df$isolationWindowUpperMz <- c(NA_real_, 4, 4, 3, 1)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    expect_identical(isolationWindowUpperMz(be), c(NA_real_, 4, 4, 3, 1))

    expect_error(isolationWindowUpperMz(be) <- 2.1, "of length 5")
})

test_that("length,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(length(be), 0)
    be <- new("MsBackendDataFrame", spectraData = DataFrame(a = 1:3, fromFile = 1L),
              files = NA_character_, modCount = 0L)
    expect_equal(length(be), 3)
})

test_that("msLevel,MsBackendDataFrame works", {
    be <- backendInitialize(MsBackendDataFrame(), NA_character_,
                            DataFrame(msLevel = c(1L, 2L, 1L),
                                      fromFile = 1L))
    expect_equal(msLevel(be), c(1, 2, 1))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_,
                            DataFrame(scanIndex = 1:4,
                                      fromFile = 1L))
    expect_equal(msLevel(be), rep(NA_integer_, 4))
})

test_that("mz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(mz(be), NumericList(compress = FALSE))
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 1L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(mz(be), NumericList(numeric(), numeric(), compress = FALSE))
    df$intensity <- list(1:3, 4)
    df$mz <- list(1:3, c(2.1))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(mz(be), NumericList(1:3, 2.1, compress = FALSE))
})

test_that("mz<-,MsBackendDataFrame works", {
    test_df$fromFile <- 1L
    be <- backendInitialize(MsBackendDataFrame(), files = NA_character_,
                            spectraData = test_df)

    new_mzs <- lapply(test_df$mz, function(z) z / 2)
    mz(be) <- new_mzs
    expect_identical(mz(be), NumericList(new_mzs, compress = FALSE))
    expect_identical(be@modCount, 1L)

    expect_error(mz(be) <- 3, "has to be a list")
    expect_error(mz(be) <- list(3, 2), "match the length")
    expect_error(mz(be) <- list(3, 2, 4), "number of peaks")
})

test_that("peaks,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(peaks(be), list())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 1L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(peaks(be), list(cbind(mz = numeric(), intensity = numeric()),
                                 cbind(mz = numeric(), intensity = numeric())))
    df$mz <- list(1:3, c(2.1))
    df$intensity <- list(1:3, 4)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(peaks(be), list(cbind(mz = 1:3, intensity = 1:3),
                                 cbind(mz = 2.1, intensity = 4)))
})

test_that("peaks<-,MsBackendDataFrame works", {
    test_df$fromFile <- 1L
    be <- backendInitialize(MsBackendDataFrame(), files = NA_character_,
                            spectraData = test_df)

    pks <- lapply(peaks(be), function(z) z / 2)
    peaks(be) <- pks
    expect_identical(peaks(be), pks)
    expect_identical(be@modCount, 1L)

    expect_error(peaks(be) <- 3, "has to be a list")
    expect_error(peaks(be) <- list(3, 2), "match length")
    expect_error(peaks(be) <- list(3, 2, 4), "dimensions")
})

test_that("peaksCount,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(peaksCount(be), integer())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 1L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(peaksCount(be), c(0L, 0L))
    df$mz <- list(1:3, c(2.1))
    df$intensity <- list(1:3, 4)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(peaksCount(be), c(3L, 1L))
})

test_that("polarity, polarity<- MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(polarity(be), integer())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 1L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(polarity(be), c(NA_integer_, NA_integer_))
    expect_error(polarity(be) <- "a", "has to be an 'integer'")
    expect_error(polarity(be) <- c(1L, 1L, 2L), "has to be")
    polarity(be) <- 0
    expect_equal(polarity(be), c(0L, 0L))
    polarity(be) <- 1:2
    expect_equal(polarity(be), 1:2)
})

test_that("precScanNum,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(precScanNum(be), integer())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precScanNum(be), c(NA_integer_, NA_integer_))
    df$precScanNum <- c(0L, 1L)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precScanNum(be), c(0L, 1L))
})

test_that("precursorCharge,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(precursorCharge(be), integer())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorCharge(be), c(NA_integer_, NA_integer_))
    df$precursorCharge <- c(-1L, 1L)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorCharge(be), c(-1L, 1L))
})

test_that("precursorIntensity,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(precursorIntensity(be), numeric())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorIntensity(be), c(NA_real_, NA_real_))
    df$precursorIntensity <- c(134.4, 4322.2)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorIntensity(be), c(134.4, 4322.2))
})

test_that("precursorMz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(precursorMz(be), numeric())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorMz(be), c(NA_real_, NA_real_))
    df$precursorMz <- c(134.4, 342.2)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(precursorMz(be), c(134.4, 342.2))
})

test_that("rtime, rtime<-,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(rtime(be), numeric())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(rtime(be), c(NA_real_, NA_real_))
    expect_error(rtime(be) <- "2", "has to be a 'numeric'")
    expect_error(rtime(be) <- 1:4, "of length 2")
    rtime(be) <- c(123, 124)
    expect_equal(rtime(be), c(123, 124))
})

test_that("scanIndex,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(scanIndex(be), integer())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(scanIndex(be), c(NA_integer_, NA_integer_))
    df$scanIndex <- c(1L, 2L)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(scanIndex(be), c(1L, 2L))
})

test_that("smoothed, smoothed<-,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(smoothed(be), logical())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(smoothed(be), c(NA, NA))
    expect_error(smoothed(be) <- "2", "has to be a 'logical'")
    expect_error(smoothed(be) <- c(TRUE, TRUE, FALSE), "of length 1 or 2")
    smoothed(be) <- c(TRUE, FALSE)
    expect_equal(smoothed(be), c(TRUE, FALSE))
    smoothed(be) <- c(TRUE)
    expect_equal(smoothed(be), c(TRUE, TRUE))
})

test_that("spectraNames, spectraNames<-,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_null(spectraNames(be))
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_null(spectraNames(be))
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    rownames(df) <- c("sp_1", "sp_2")
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(spectraNames(be), c("sp_1", "sp_2"))
    expect_error(spectraNames(be) <- "a", "rownames length")
    spectraNames(be) <- c("a", "b")
    expect_equal(spectraNames(be), c("a", "b"))
})

test_that("tic,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(tic(be), numeric())
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(tic(be), c(NA_real_, NA_real_))
    expect_equal(tic(be, initial = FALSE), c(0, 0))
    df$totIonCurrent <- c(5, 3)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(tic(be), c(5, 3))
    expect_equal(tic(be, initial = FALSE), c(0, 0))
    df$intensity <- list(5:7, 1:4)
    df$mz <- list(1:3, 1:4)
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(tic(be, initial = FALSE), c(sum(5:7), sum(1:4)))
})

test_that("spectraVariables,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(spectraVariables(be), names(Spectra:::.SPECTRA_DATA_COLUMNS))
    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L))
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(spectraVariables(be), names(Spectra:::.SPECTRA_DATA_COLUMNS))
    df$other_column <- 3
    be <- backendInitialize(be, files = NA_character_, spectraData = df)
    expect_equal(spectraVariables(be), c(names(Spectra:::.SPECTRA_DATA_COLUMNS),
                                         "other_column"))
})

test_that("spectraData, spectraData<-, MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    res <- spectraData(be)
    expect_true(is(res, "DataFrame"))
    expect_true(nrow(res) == 0)
    expect_equal(colnames(res), names(.SPECTRA_DATA_COLUMNS))

    df <- DataFrame(fromFile = c(1L, 1L), scanIndex = 1:2, a = "a", b = "b")
    be <- backendInitialize(be, files = NA_character_, spectraData = df)

    res <- spectraData(be)
    expect_true(is(res, "DataFrame"))
    expect_true(all(names(.SPECTRA_DATA_COLUMNS) %in% colnames(res)))
    expect_equal(res$a, c("a", "a"))
    expect_equal(res$b, c("b", "b"))

    res <- spectraData(be, "msLevel")
    expect_true(is(res, "DataFrame"))
    expect_equal(colnames(res), "msLevel")
    expect_equal(res$msLevel, c(NA_integer_, NA_integer_))

    res <- spectraData(be, c("mz"))
    expect_true(is(res, "DataFrame"))
    expect_equal(colnames(res), "mz")
    expect_equal(res$mz, NumericList(numeric(), numeric(), compress = FALSE))

    res <- spectraData(be, c("a", "intensity"))
    expect_true(is(res, "DataFrame"))
    expect_equal(colnames(res), c("a", "intensity"))
    expect_equal(res$intensity, NumericList(numeric(), numeric(),
                                            compress = FALSE))
    expect_equal(res$a, c("a", "a"))

    spectraData(be) <- DataFrame(fromFile = 1L, mzLevel = c(3L, 4L),
                                 rtime = c(1.2, 1.4), other_col = "b")
    expect_identical(rtime(be), c(1.2, 1.4))
    expect_true(any(spectraVariables(be) == "other_col"))
    expect_identical(spectraData(be, "other_col")[, 1], c("b", "b"))

    expect_error(spectraData(be) <- DataFrame(msLevel = 1:3, fromFile = 1),
                 "with 2 rows")
})

test_that("show,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    show(be)
    df <- DataFrame(fromFile = c(1L, 1L), rt = c(1.2, 1.3))
    be <- backendInitialize(be, files = NA_character_, df)
})

test_that("[,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_error(be[1])
    df <- DataFrame(fromFile = c(1L, 1L), scanIndex = 1:2, a = "a", b = "b")
    be <- backendInitialize(be, files = NA_character_, df)
    res <- be[1]
    expect_equal(be@spectraData[1, ], res@spectraData[1, ])
    res <- be[2]
    expect_equal(be@spectraData[2, ], res@spectraData[1, ])
    res <- be[2:1]
    expect_equal(be@spectraData[2:1, ], res@spectraData)

    res <- be[c(FALSE, FALSE)]
    expect_true(length(res) == 0)
    res <- be[c(FALSE, TRUE)]
    expect_equal(be@spectraData[2, ], res@spectraData[1, ])

    expect_error(be[TRUE], "match the length of")
    expect_error(be["a"], "does not have names")

    tmpfa <- tempfile()
    write(file = tmpfa, "a")
    tmpfb <- tempfile()
    write(file = tmpfb, "b")

    df <- DataFrame(fromFile = c(1L, 1L, 2L, 2L), scanIndex = c(1L, 2L, 1L, 2L),
                    file = c("a", "a", "b", "b"))
    be <- backendInitialize(be, files = c(tmpfa, tmpfb), df)
    res <- be[3]
    expect_equal(fromFile(res), 1L)
    expect_equal(res@files, tmpfb)
    expect_equal(res@spectraData$file, "b")

    res <- be[c(3, 1)]
    expect_equal(fromFile(res), 1:2)
    expect_equal(res@files, c(tmpfb, tmpfa))
    expect_equal(res@spectraData$file, c("b", "a"))
})

test_that("selectSpectraVariables,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    res <- selectSpectraVariables(be, c("fromFile", "msLevel"))

    df <- DataFrame(fromFile = c(1L, 1L), msLevel = 1:2, rtime = c(2.3, 1.2),
                    other_col = 2)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- selectSpectraVariables(be, c("fromFile", "other_col"))
    expect_equal(colnames(res@spectraData), c("fromFile", "other_col"))
    expect_equal(msLevel(res), c(NA_integer_, NA_integer_))

    res <- selectSpectraVariables(be, c("fromFile", "rtime"))
    expect_equal(colnames(res@spectraData), c("fromFile", "rtime"))

    expect_error(selectSpectraVariables(be, "rtime"), "fromFile is/are missing")
    expect_error(selectSpectraVariables(be, "something"),
                 "something not available")
})

test_that("$,$<-,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_identical(be$msLevel, integer())

    df <- DataFrame(fromFile = c(1L, 1L), msLevel = 1:2, rtime = c(2.3, 1.2),
                    other_col = 2)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    expect_identical(be$msLevel, 1:2)
    expect_identical(be$other_col, c(2, 2))

    be$other_col <- 4
    expect_equal(be$other_col, c(4, 4))

    df$mz <- list(1:3, 1:4)
    df$intensity <- list(c(3, 3, 3), c(4, 4, 4, 4))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    be$intensity <- list(c(5, 5, 5), 1:4)
    expect_equal(be$intensity, NumericList(c(5, 5, 5), 1:4, compress = FALSE))
})

test_that("filterAcquisitionNum,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterAcquisitionNum(be, n = 4))

    df <- DataFrame(fromFile = c(1L, 1L, 1L, 2L, 2L, 3L, 3L, 3L),
                    acquisitionNum = c(1L, 2L, 3L, 2L, 3L, 1L, 2L, 4L),
                    msLevel = 1L)
    a <- tempfile()
    b <- tempfile()
    c <- tempfile()
    cat("a", file = a)
    cat("b", file = b)
    cat("c", file = c)
    be <- backendInitialize(MsBackendDataFrame(),
                            c(a, b, c), df)
    res <- filterAcquisitionNum(be, n = c(2L, 4L))
    expect_equal(length(res), 4)
    expect_equal(fromFile(res), c(1L, 2L, 3L, 3L))
    expect_equal(acquisitionNum(res), c(2L, 2L, 2L, 4L))

    res <- filterAcquisitionNum(be, n = 2L, file = 2L)
    expect_equal(fromFile(res), c(1L, 1L, 1L, 2L, 3L, 3L, 3L))
    expect_equal(acquisitionNum(res), c(1L, 2L, 3L, 2L, 1L, 2L, 4L))

    expect_error(filterAcquisitionNum(be, n = "a"), "integer representing")
    expect_error(filterAcquisitionNum(be, n = 4L, file = "d"), "integer with")
    expect_equal(filterAcquisitionNum(be), be)
})

test_that("filterEmptySpectra,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(filterEmptySpectra(be), be)

    df <- DataFrame(msLevel = c(1L, 1L, 1L), rtime = c(1.2, 1.3, 1.5),
                    fromFile = 1L)
    df$mz <- SimpleList(1:3, 1:4, integer())
    df$intensity <- SimpleList(c(5, 12, 9), c(6, 9, 12, 5), numeric())
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterEmptySpectra(be)
    expect_true(length(res) == 2)
    expect_equal(rtime(res), c(1.2, 1.3))

    res <- filterEmptySpectra(be[3])
    expect_true(length(res) == 0)
})

test_that("filterFile,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterFile(be))
    df <- DataFrame(fromFile = c(1L, 1L, 1L, 2L, 2L, 3L, 3L, 3L),
                    acquisitionNum = c(1L, 2L, 3L, 2L, 3L, 1L, 2L, 4L),
                    rtime = as.numeric(1:8),
                    msLevel = 1L)
    a <- tempfile()
    b <- tempfile()
    c <- tempfile()
    cat("a", file = a)
    cat("b", file = b)
    cat("c", file = c)
    be <- backendInitialize(MsBackendDataFrame(),
                            c(a, b, c), df)
    res <- filterFile(be, c(3, 1))
    expect_equal(length(res), 6)
    expect_equal(fromFile(res), c(1L, 1L, 1L, 2L, 2L, 2L))
    expect_equal(rtime(res), c(6, 7, 8, 1, 2, 3))
    expect_equal(fileNames(res), c(c, a))

    res <- filterFile(be, 2)
    expect_equal(rtime(res), c(4, 5))
    expect_equal(fileNames(res), b)

    res <- filterFile(be, c(2, 3))
    expect_equal(rtime(res), c(4, 5, 6, 7, 8))
    expect_equal(fileNames(res), c(b, c))

    res <- filterFile(be)
    expect_equal(res, be)

    expect_error(filterFile(be, 5), "index out of")
    expect_error(filterFile(be, "a"), "names present in")

    df$fromFile <- 1L
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterFile(be, 1L)
    expect_equal(res, be)
})

test_that("filterIsolationWindow,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterIsolationWindow(be))

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 2L, 2L, 2L, 2L),
                    rtime = as.numeric(1:6))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    expect_error(filterIsolationWindow(be, c(1.2, 1.3)), "single m/z value")
    res <- filterIsolationWindow(be, 1.2)
    expect_true(length(res) == 0)

    df$isolationWindowLowerMz <- c(NA_real_, 1.2, 2.1, 3.1, 3, 3.4)
    df$isolationWindowUpperMz <- c(NA_real_, 2.2, 3.2, 4.1, 4, 4.4)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterIsolationWindow(be, 3)
    expect_equal(rtime(res), c(3, 5))
})

test_that("filterMsLevel,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterMsLevel(be))

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 1L, 2L, 3L, 2L),
                    rtime = as.numeric(1:6))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterMsLevel(be, 2L)
    expect_true(all(msLevel(res) == 2))
    expect_equal(rtime(res), c(2, 4, 6))

    res <- filterMsLevel(be, c(3L, 2L))
    expect_equal(rtime(res), c(2, 4, 5, 6))

    res <- filterMsLevel(be, c(3L, 5L))
    expect_equal(rtime(res), 5)
})

test_that("filterPolarity,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterPolarity(be))

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 3L, 1L, 2L, 3L),
                    rtime = as.numeric(1:6), polarity = c(1L, 1L, -1L, 0L, 1L, 0L))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterPolarity(be, c(1, 2))
    expect_true(all(polarity(res) == 1L))
    expect_equal(rtime(res), c(1, 2, 5))

    res <- filterPolarity(be, c(0L, -1L))
    expect_true(all(polarity(res) %in% c(0L, -1L)))
    expect_equal(rtime(res), c(3, 4, 6))
})

test_that("filterPrecursorMz,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterPrecursorMz(be))

    df <- DataFrame(fromFile = 1L, msLevel = c(1L, 2L, 2L, 2L),
                    rtime = as.numeric(1:4))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterPrecursorMz(be, 1.4)
    expect_true(length(res) == 0)

    df$precursorMz <- c(NA_real_, 4.43, 4.4312, 5.4)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterPrecursorMz(be, 5.4)
    expect_equal(rtime(res), 4)

    res <- filterPrecursorMz(be, 4.4311)
    expect_true(length(res) == 0)

    res <- filterPrecursorMz(be, 4.4311, ppm = 50)
    expect_equal(rtime(res), 3)
})

test_that("filterPrecursorScan,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(be, filterPrecursorScan(be))
    expect_true(length(filterPrecursorScan(be, 3)) == 0)

    df <- DataFrame(msLevel = c(1L, 2L, 3L, 4L, 1L, 2L, 3L),
                    fromFile = 1L,
                    rtime = as.numeric(1:7))
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterPrecursorScan(be, 2L)
    expect_true(length(res) == 0)

    df$acquisitionNum <- c(1L, 2L, 3L, 4L, 1L, 2L, 6L)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterPrecursorScan(be, 2L)
    expect_equal(acquisitionNum(res), c(2L, 2L))
    expect_equal(rtime(res), c(2, 6))

    df$precScanNum <- c(0L, 1L, 2L, 3L, 0L, 1L, 5L)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)
    res <- filterPrecursorScan(be, 2L)
    expect_equal(rtime(res), 1:6)

    res <- filterPrecursorScan(be, 5L)
    expect_true(length(rtime(res)) == 0)

    res <- filterAcquisitionNum(be, 6L)
    expect_equal(rtime(res), 7)
})

test_that("filterRt,MsBackendDataFrame works", {
    be <- MsBackendDataFrame()
    expect_equal(filterRt(be), be)
    expect_true(length(filterRt(be, rt = 2)) == 0)

    df <- DataFrame(fromFile = 1L, rtime = c(1, 2, 3, 4, 1, 2, 6, 7, 9),
                    index = 1:9)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterRt(be, c(4, 6))
    expect_equal(rtime(res), c(4, 6))
    expect_equal(res@spectraData$index, c(4, 7))

    res <- filterRt(be, c(4, 6), 2L)
    expect_equal(res, be)

    df$msLevel <- c(1L, 2L, 1L, 2L, 1L, 2L, 2L, 2L, 2L)
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterRt(be, c(2, 6), msLevel = 1L)
    expect_equal(rtime(res), c(2, 3, 4, 2, 6, 7, 9))


    df$rtime <- NULL
    be <- backendInitialize(MsBackendDataFrame(), NA_character_, df)

    res <- filterRt(be, c(2, 6), msLevel = 1L)
    expect_equal(res, filterMsLevel(be, 2L))

    res <- filterRt(be, c(2, 6))
    expect_true(length(res) == 0)
})