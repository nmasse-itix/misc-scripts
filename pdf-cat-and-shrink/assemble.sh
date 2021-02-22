#!/bin/sh

for i in {1..24..1}; do
  qpdf --empty --pages "vivre-ensemble.pdf" $((i+1)) "langage-oral.pdf" $((i+3)) "langage-écrit.pdf" $((i+5)) "structurer-sa-pensée.pdf" $((i+3)) "découvrir-le-monde.pdf" $((i+3)) "activités-artistiques.pdf" $((i+3)) "activités-physiques.pdf" $((i+2)) -- tmp.pdf
  ./shrinkpdf.sh tmp.pdf livret-élève-$i.pdf 150
done