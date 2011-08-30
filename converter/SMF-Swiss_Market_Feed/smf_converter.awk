#!/usr/bin/awk

function padWithRecursion(source, numParts, separator) {
    if (split(source, parts, separator) < numParts) {
        return padWithRecursion(source separator, numParts, separator)
    }
    return source
}

function padWith(source, numParts, oldSeparator, newSeparator) {
    result = source
    gsub(oldSeparator, newSeparator, result)
    return padWithRecursion(result, numParts, newSeparator)
}

BEGIN{
  LBREAK="\r\n"
  FS="#"
  OFS="\t"
  ORS=LBREAK
  ufile="part74.csv"
  rfile="rest.csv"
}
{
if ("<" != substr($1, 0, 1)) {
    isin=substr($1, 7) OFS substr($1,7, 12)
    frontNumber = substr($1, 0, 6)
    gsub(/ */, "", frontNumber)
    $1=isin OFS substr($1, 19, 3) OFS substr($1, 22) OFS frontNumber
    print >> "base.csv"
} else if ("<73>" == substr($1, 0, 4)) {
    part = substr($1, 5, 1)
    if ("A" == part) {
        $49 = padWith($49, 2, ";", OFS)
        $50 = padWith($50, 2, ";", OFS)
        $51 = padWith($51, 2, ";", OFS)
        $52 = padWith($52, 2, ";", OFS)
    }
    $1 = isin
    file="part73_" part ".csv"
    print >> file
} else if ("<74>" == substr($1, 0, 4)) {
    $7  = padWith( $7, 2, ";", OFS)
    if (NF >  7) {  $8 = padWith( $8, 4, ";", OFS) }
    if (NF >  8) {  $9 = padWith( $9, 4, ";", OFS) }
    if (NF >  9) { $10 = padWith($10, 4, ";", OFS) }
    if (NF > 10) { $11 = padWith($11, 4, ";", OFS) }
    $1 = isin OFS substr($1, 5)
    print >> ufile
} else {
    print >> rfile
}
}
