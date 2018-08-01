#!/bin/sh

# Build the Galacticus Perl analysis documentation.
# Andrew Benson (31-July-2018)

# Move to the documentation folder.
cd doc

# Demangle the bibliography.
Bibliography_Demangle.pl
if [ $? -ne 0 ]; then
 echo Failed to demangle bibliography
 exit 1
fi

# Compile the manual.
iPass=1
while [ $iPass -le 6 ]; do
 # Run pdflatex.
 pdflatex GalacticusAnalysisPerl | grep -v -i -e overfull -e underfull | sed -r /'^$'/d | sed -r /'\[[0-9]*\]'/d
 if [ $? -ne 0 ]; then
  echo pdflatex failed
  exit 1
 fi

 # Run bibtex.
 bibtex GalacticusAnalysisPerl
 if [ $? -ne 0 ]; then
  echo bibtex failed
  exit 1
 fi

 # Run makeindex.
 makeindex GalacticusAnalysisPerl
 if [ $? -ne 0 ]; then
  echo makeindex failed for main index
  exit 1
 fi

 # Run makeglossaries.
 makeglossaries GalacticusAnalysisPerl
 if [ $? -ne 0 ]; then
  echo make glossaries failed
  exit 1
 fi

 iPass=$((iPass+1))
done

exit 0
