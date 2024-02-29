foreach leakage (0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0)
repeat 50 ./uvg_noprompt.csh GEN "$leakage" > ! output_"$leakage"
mv output_"$leakage" outputs_actual_parallactic_coverage
mv fluxes_unc_leakage_"$leakage".txt outputs_actual_parallactic_coverage
end
