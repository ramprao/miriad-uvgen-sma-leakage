#! /bin/csh -f
#

set leakageslist = (0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0)
set leakageslist = (0.45 0.55)
set numrepeats = 2
mkdir -p ./outputs_actual_parallactic_coverage

foreach leakage ($leakageslist)
repeat $numrepeats ~/repos/miriad-uvgen-sma-leakage/uvg_noprompt.csh GEN "$leakage" > ! output_"$leakage"
mv output_"$leakage" outputs_actual_parallactic_coverage
mv fluxes_unc_leakage_"$leakage".txt outputs_actual_parallactic_coverage
end
