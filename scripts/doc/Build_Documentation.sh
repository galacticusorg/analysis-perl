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
    if [ $iPass -le 5 ]; then
	pdflatex GalacticusAnalysisPerl | grep -v -i -e overfull -e underfull | sed -r /'^$'/d | sed -r /'\[[0-9]*\]'/d >& /dev/null
    else
	pdflatex GalacticusAnalysisPerl | grep -v -i -e overfull -e underfull | sed -r /'^$'/d | sed -r /'\[[0-9]*\]'/d
    fi
    if [ $? -ne 0 ]; then
	echo pdflatex failed
	exit 1
    fi

 # Run bibtex.
    if [ $iPass -le 5 ]; then
	bibtex GalacticusAnalysisPerl >& /dev/null
    else
	bibtex GalacticusAnalysisPerl
    fi
    if [ $? -ne 0 ]; then
	echo bibtex failed
	exit 1
    fi

 # Run makeindex.
    if [ $iPass -le 5 ]; then
	makeindex GalacticusAnalysisPerl >& /dev/null
    else
	makeindex GalacticusAnalysisPerl
    fi
    if [ $? -ne 0 ]; then
	echo makeindex failed for main index
	exit 1
    fi

 # Run makeglossaries.
    if [ $iPass -le 5 ]; then
	makeglossaries GalacticusAnalysisPerl >& /dev/null
    else
	makeglossaries GalacticusAnalysisPerl
    fi
    if [ $? -ne 0 ]; then
	echo make glossaries failed
	exit 1
    fi

    iPass=$((iPass+1))
done

exit 0
