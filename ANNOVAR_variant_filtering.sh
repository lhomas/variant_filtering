#!/bin/bash

usage () 
{
echo "#
#
# Script to identify variants below population frequency and allele fraction threshold.
# This script takes as input the het and ibdAndXl GenomeAnnotationsCOmbined.txt files, along with population frequency 
and allele fraction threshold.
# This will output a bed file that can then be used to select variants from a VCF that are below the provided 
thresholds.
# This script is designed to be used with the outputs of the Neurogenetics ANNOVAR pipeline.
# 
# USAGE: bash select_private_vars.sh \
# -h /path/to/het.GenomeAnnotationsCombined.txt \
# -x /path/to/ibdAndXl.GenomeAnnotationsCombined.txt \
# -p population_freq_threshold \
# -a allele_fraction_threshold \
# -o /path/to/output.bed
#
# The script has 6 REQUIRED options.
# Options:
# -h	REQUIRED.	het.GenomeAnnotationsCombined.txt output from neurogenetics ANNOVAR pipeline
# -x	REQUIRED.	ibdAndXl.GenomeAnnotationsCombined.txt output from neurogenetics ANNOVAR pipeline
# -p	REQUIRED.	Upper minor allele frequency threshold above which variants won't be included (No default, but 1/5000 (0.0002) is a good starting place)
# -a	REQUIRED.	Upper allele fraction limit for het file, above which variants won't be included 
### (Take the number of individuals of interest in the VCF and divide by double the # of individuals in the VCF input into the ANNOVAR pipeline)
# -I	REQUIRED.	Same as -a option but used for filtering of ibdAndXl file (Number of individuals of interest/number of samples in vcf input into ANNOVAR)
# -o	REQUIRED.	Path to output .bed file.
# -h | --help		Print this message
#
"
}


## Set Variables ##
while [ "$1" != "" ]; do 
	case $1 in
		-h )	shift
				het=${1}
				;;
		-x )	shift
				xlinked=${1}
				;;
		-p )	shift
				freq=${1}
				;;
		-a )	shift
				frac=${1}
				;;
		-i )	shift
				ifrac=${1}
				;;
		-o )	shift
				output=${1}
				;;
		-h | --help )	usage
						exit 0
						;;
		* )		usage
				exit 1
	esac
	shift
done


## Check Options ##

if [ -z "${het}" ]; then # If not het file provided do not proceed
	usage
	echo "## ERROR: You need to provide a het.GenomeAnnotationsCombined.txt"
	exit 1
fi

if [ -z "${het}" ]; then # If not ibdAndXl file provided do not proceed
	usage
	echo "## ERROR: You need to provide a ibdAndXl.GenomeAnnotationsCombined.txt"
	exit 1
fi

if ! [[ "${freq}" =~ ^[0]+(\.[0-9]+)?$ ]]; then # If not population frequency threshold is provided do not continue
	usage
	echo "## ERROR: You need to provide a population frequency threshold"
	exit 1
fi

if ! [[ "${frac}" =~ ^[0]+(\.[0-9]+)?$ ]]; then # If not allele fraction threshold is provided do not continue
	usage
	echo "## ERROR: You need to provide a allele fraction threshold"
	exit 1
fi

if ! [[ "${ifrac}" =~ ^[0]+(\.[0-9]+)?$ ]]; then # If not allele fraction threshold is provided do not continue
	usage
	echo "## ERROR: You need to provide a allele fraction threshold"
	exit 1
fi

if [ -z "${output}" ]; then # If not output location is provided do not continue
	usage
	echo "## ERROR: You need to provide the path and name of the output .bed file"
	exit 1
fi

if [ -f ${output} ]; then # If file already exists do not proceed, otherwise, create file
	echo "## ERROR: ${output} already exists, if you are ok with this being overwritten please delete the file and rerun this script"
	exit 1
else
	echo "## NOTE: Creating ${output}"
	touch ${output}
fi

## Run Variant Filtering ##

# Create .bed to output variant locations 

awk -F "\t"  \
-v freq=${freq} \
-v frac=${frac} \
'{if ($106 <= freq && $119 <= frac) print $2"\t"$3"\t"$4 }' \
${het} \
>> ${output}

awk -F "/t" \
-v freq=${freq} \
-v ifrac=${ifrac} \
'{if ($106 <= freq && $119 <= ifrac && $2 == "chrX") print $2"\t"$3"\t"$4 }' \
${xlinked} \
>> ${output}
