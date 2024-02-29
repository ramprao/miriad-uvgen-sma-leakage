#! /bin/csh -f
#

set harangeCal=-5,1,0.1
set harangeSource=-2.5,-2.0,0.1
set harangeSource=-1.5,3.5,0.1
set leakage=$2
touch fluxes_unc_leakage_"$leakage".txt
#set leakoff=2,-2
set leakoff=0,0

set refant=1
set interval=20
set imsize=256
set cell=0.5

set telescope=sma
set lat=19:49:27.14
set ant=smaCompact.txt
set baseunit=3.33564
set freq=230.0,0.0
set pbfwhm=53.0
set dt=`date +%y%b%d:%H:%M:%S | tr '[A-Z]' '[a-z]'`

set evec=45
set evec=`echo $evec | awk '{printf("%.6f", $1/180.0*3.141592654)}'`

goto $1

GEN:
# Generate dataset
echo "########### Generating Dataset ##############"
#echo -n "Enter input linear polarization of calibrator (%pol, PA in degrees) eg. Default 5,30   " ; set ans="$<"
set ans=1.49,-45.7
echo "1,0,0,0,0,0,$ans,0" >! calib.so
#echo "Do you want noisy data (y/n)? Default y."; set ans=$<
set ans="n"
if($ans == "") set ans="y"
if ($ans == "y") then
set systemp=60,290,0.08
set gnoise=1
set pnoise=5
else
set systemp=0
set gnoise=0
set pnoise=0
endif

set UVGENDIR="."
set UVGENDIR="/home/rrao/repos/miriad-uvgen-sma-leakage"

\rm -fr cal_dataset source_dataset
$UVGENDIR/uvgen source=calib.so ant=$ant baseunit=$baseunit telescop=nasmyth,45 corr=0 \
	time=$dt freq=$freq harange=$harangeCal ellim=20 pbfwhm=$pbfwhm \
	stokes=ll,lr,rl,rr leakage=$leakage out=cal_dataset lat=$lat \
	leakoff=$leakoff gnoise=$gnoise pnoise=$pnoise systemp=$systemp radec=03:19:48.1600,41:30:42.1060
$UVGENDIR/uvgen source=source.so ant=$ant baseunit=$baseunit telescop=nasmyth,45 corr=0 \
	time=$dt freq=$freq harange=$harangeSource ellim=20 pbfwhm=$pbfwhm \
	stokes=ll,lr,rl,rr leakage=$leakage out=source_dataset lat=$lat \
	leakoff=$leakoff gnoise=$gnoise pnoise=$pnoise systemp=$systemp radec=03:19:48.1600,-29:00:28.1180


echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

PLT1:
# Uvplot the dataset
echo "########### Plotting Dataset ##############"
#echo "Do you want to plot (y/n)? Default n."; set ans=$<
set ans="n"
if ($ans == "") set ans="n"
if ($ans == "y") then
echo "Plotting calibrator"
uvplt vis=cal_dataset device=/xw axis=ti,ph axis=ti,ph 
echo "Plotting source"
uvplt vis=source_dataset device=/xw axis=ti,ph axis=ti,ph 
endif
#echo -n "Press enter to goto next step "; set ans=$<

CALIB:
# Calibrate leakage using gpcal
echo "########### Polarization Calibration of Dataset ##############"
gpcal vis=cal_dataset flux=1 refant=$refant interval=$interval \
	options=circular,qusolve,noamphase,noxy
echo "These are the original starting values of the leakage"
grep 'Dx,Dy' cal_dataset/history | grep UVGEN | cut -c8-
set q=`awk 'BEGIN{FS=","} {printf("%.3f\n",$7*cos(2.0*3.142/180.0*$8))}' < calib.so`
set u=`awk 'BEGIN{FS=","} {printf("%.3f\n",$7*sin(2.0*3.142/180.0*$8))}' < calib.so`
echo "This is the original values of the source linear polarization" 
echo "Percent Q:" $q
echo "Percent U:" $u
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

APPLYCAL:
echo "########### APPLY Leakage  ##############"
#echo "Do you want to apply leakage calibration (y/n)? Default n."; set ans=$<
#if ($ans == "") set ans="n"
#if ($ans == "y") then
gpcopy vis=cal_dataset out=source_dataset options=nocal
#endif
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

PLT2:
# Uvplot after leakage calibration
echo "########### Plotting Dataset after leakage calibration ##############"
#echo "Do you want to plot (y/n)? Default n."; set ans=$<
set ans="n"
if ($ans == "") set ans="n"
if ($ans == "y") then
echo "Plotting calibrator"
uvplt vis=cal_dataset device=/xw axis=ti,ph axis=ti,ph 
echo "Plotting source"
uvplt vis=source_dataset device=/xw axis=ti,ph axis=ti,ph 
endif
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

UNCAL:
INVERT:
# Invert
echo "########### Mapping Dataset ##############"
\rm -fr *.mp bm
invert vis=source_dataset options=nopol stokes=i,q,u,v map=i.mp,q.mp,u.mp,v.mp \
	beam=bm imsize=$imsize cell=$cell sup=0 
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

CLEAN:
# Clean
echo "########### Cleaning Dataset ##############"
set cutoff=`imhist in=u.mp region='relpix,box(-100,-100,-60,100)' device=/null | head -8 | tail -1 | awk '{print 3.0*$3}'`
\rm -fr *.cl *.cm
foreach stokes(i q u v)
clean map=$stokes.mp beam=bm out=$stokes.cl cutoff=$cutoff
restor map=$stokes.mp beam=bm out=$stokes.cm model=$stokes.cl
end
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

IMP:
# Impol
echo "########### Creating Polarization Images ##############"
set sigma=`imhist in=u.mp region='relpix,box(-100,-100,-60,100)' device=/null | head -8 | tail -1 | awk '{print $3}'`
\rm -fr poli polierr polm polmerr pa paerr
impol in=q.cm,u.cm,i.cm poli=poli,polierr polm=polm,polmerr \
	pa=pa,paerr sigma=$sigma sncut=3,100 
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

DISP:
#Display
echo "########### Displaying Polarization Images ##############"
#cgdisp in=i.cm,poli,polm,pa type=c,p,amp,ang device=/xw \
#	region='arcsec,box(-20,-20,20,20)' labtyp=arcsec,arcsec \
#    options=full,wedge lines=1,1,6
#echo -n "Press enter to goto next step "; set ans=$<


FLUX:
#flux
set fbox=`imhist in=i.cm | grep Maximum | awk '{print $5}' | cut -c 2- | awk 'BEGIN{FS=","} {printf("(%s,%s,%s,%s)\n",$1,$2,$1,$2)}'`
echo "########### Computing Flux from Images ##############"
set maxpos=`imhist in=i.cm device=/null | grep MAXIMUM | awk '{print $3}'`
echo "I        Q        U        POLI    POLIERR   POLM  POLMERR  PA PAERR"

set ii=`imlist in=i.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
set iq=`imlist in=q.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
set iu=`imlist in=u.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
#echo $ii $iq $iu

foreach val( poli polierr polm polmerr pa paerr)
set $val=`imlist in=$val options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
end

set pa=`echo $pa | awk '{if($1<0)  {print 180+$1} else {print $1}}'`
echo $ii $iq $iu $poli $polierr $polm $polmerr $pa $paerr | awk '{printf("FLUXES_UNC %7.5f  %7.5f  %7.5f  %7.5f  %7.5f  %.5f %.5f %5.0f %2.0f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}' 
echo $ii $iq $iu $poli $polierr $polm $polmerr $pa $paerr | awk '{printf("FLUXES_UNC %7.5f  %7.5f  %7.5f  %7.5f  %7.5f  %.5f %.5f %5.0f %2.0f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}' >> fluxes_unc_leakage_"$leakage".txt

#echo -n "Press enter to goto next step "; set ans=$<


CAL:
INVERT:
# Invert
echo "########### Mapping Dataset ##############"
\rm -fr *.mp bm
invert vis=source_dataset stokes=i,q,u,v map=i.mp,q.mp,u.mp,v.mp \
	beam=bm imsize=$imsize cell=$cell sup=0 
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

CLEAN:
# Clean
echo "########### Cleaning Dataset ##############"
set cutoff=`imhist in=u.mp region='relpix,box(-100,-100,-60,100)' device=/null | head -8 | tail -1 | awk '{print 3.0*$3}'`
\rm -fr *.cl *.cm
foreach stokes(i q u v)
clean map=$stokes.mp beam=bm out=$stokes.cl cutoff=$cutoff
restor map=$stokes.mp beam=bm out=$stokes.cm model=$stokes.cl
end
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

IMP:
# Impol
echo "########### Creating Polarization Images ##############"
set sigma=`imhist in=u.mp region='relpix,box(-100,-100,-60,100)' device=/null | head -8 | tail -1 | awk '{print $3}'`
\rm -fr poli polierr polm polmerr pa paerr
impol in=q.cm,u.cm,i.cm poli=poli,polierr polm=polm,polmerr \
	pa=pa,paerr sigma=$sigma sncut=3,100 
echo "###############################################"
#echo -n "Press enter to goto next step "; set ans=$<

DISP:
#Display
echo "########### Displaying Polarization Images ##############"
#cgdisp in=i.cm,poli,polm,pa type=c,p,amp,ang device=/xw \
#	region='arcsec,box(-20,-20,20,20)' labtyp=arcsec,arcsec \
#    options=full,wedge lines=1,1,6
#echo -n "Press enter to goto next step "; set ans=$<


FLUX:
#flux
set fbox=`imhist in=i.cm | grep Maximum | awk '{print $5}' | cut -c 2- | awk 'BEGIN{FS=","} {printf("(%s,%s,%s,%s)\n",$1,$2,$1,$2)}'`
echo "########### Computing Flux from Images ##############"
set maxpos=`imhist in=i.cm device=/null | grep MAXIMUM | awk '{print $3}'`
echo "I        Q        U        POLI    POLIERR   POLM  POLMERR  PA PAERR"

set ii=`imlist in=i.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
set iq=`imlist in=q.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
set iu=`imlist in=u.mp options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
#echo $ii $iq $iu

foreach val( poli polierr polm polmerr pa paerr)
set $val=`imlist in=$val options=data region='box'$fbox | tail -4 | head -1 | awk '{print $1}'`
end

set pa=`echo $pa | awk '{if($1<0)  {print 180+$1} else {print $1}}'`
echo $ii $iq $iu $poli $polierr $polm $polmerr $pa $paerr | awk '{printf("FLUXES_CAL %7.5f  %7.5f  %7.5f  %7.5f  %7.5f  %.5f %.5f %5.0f %2.0f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}' 

#echo -n "Press enter to goto next step "; set ans=$<

echo "#############################################"
echo "               FINISHED                      "
echo "#############################################"

HSCLN:
#killpgx
#/bin/rm -rd  --force *.mp bm *.cm *.cl pol* pa* cal_dataset


terminate:
