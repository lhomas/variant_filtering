#!/bin/bash

usage()
{
echo "
#
# Script to identity shared variants exclusive to a provided list of samples from a mulit-sample vcf.
#
# USAGE: 
#
# OPTIONS
# -v REQUIRED. /path/to/input.vcf.gz	Path to multisample VCF containing samples of interest.
# -s REQUIRED. /path/to/sample_list.txt	Path to list of samples of interest, one sample per line.
# -o REQUIRED. /path/to/output_dir		Path to location where ouptut files will be generated.
# -a OPTIONAL. /path/to/template.awk	Path to awk template file, will default to
# -p OPTIONAL.	prefix					Prefix for output files. If none is provided, date will be used.
# -h or --help							Prints this message. This will also be printed if you misuse the script.
#
# Created: 4th November 2024
#
"
}

while [ "$1" != "" ]; do
	case $1 in
	-v	)	shift
			variants=$1
			;;
	-s	)	shift
			samples=$1
			;;
	-o	)	shift
			output_dir=$1
			;;
	-a	)	shift
			awk_template=$1
			;;
	-p	)	shift
			prefix=$1
			;;
	-h | --help )	usage
					exit 0
					;;
	*	)	usage
			echo "ERROR: Wrong options used"
			exit 1
	esac
	shift
done

if [ -z "${variants}" ]; then # If no vcf file is provided, do not continue
	usage
	echo "ERROR: You need to provide a multisample vcf file"
	exit 1
fi

if [ -z "${samples}" ]; then # If no sample list is provided, do not continue
	usage
	echo "ERROR: You need to provide a list of samples you are interested in"
	exit 1
fi

if [ -z "${output_dir}" ]; then # IF not output directory is provided, do not continue
	usage
	echo "ERROR: You need to provide an output location for this script"
	exit 1
fi

if [ -f "${awk_template}"]; then # if no awk template is provided, use default
	awk_template=/Users/thomaslitster/binf/Scripts/reusable/variant_filtering/variant_filter_template.awk
	echo "NOTE: Using ${awk_template} to generate the .awk file for variant filtering"
fi

if [ -z "${prefix}" ]; then # If no prefix is provided, generate one based on todays date
	prefix=$(date | awk '{print $2$3$4}')
	echo "NOTE: Using ${prefix} to generate output files"
fi
	
## Setting Up ##

# Initialise empty arrays to ensure previously stored data will not interfere with current analysis
include_array=()
exclude_array=()

# Copy awk template
cp ${awk_template} ${output_dir}/${prefix}.awk

# Saving patterns for including and excluding samples to make for easy editing later
include_pattern='($inc !~ /^[0\.][\/\|][0\.]\:/) && \'
exclude_pattern='($exc ~ /^[0\.][\/\|][0\.]\:/) && \'

# Adding vcf positions of samples of interest to array for use in filtering variants.
while read r; 
do 
	include_array+=($(bcftools query -l ${variants} | \
	awk -v samp=${r} 'samp ~ $0 {print NR}'))
done < ${samples}


# Create array of positions to exclude
exclude_array=($(seq 1 $(bcftools query -l ${variants} | wc -l) | \
grep -v $(for inc in ${include_array[@]}; do printf "%s " "-e ${inc}"; done)))

for inum in ${include_array[@]};
do 
	inum=$((${inum}+9))
	sed 's/inc/'"${inum}"'/g' <<<$(echo ${include_pattern}) >> ${output_dir}/${prefix}.awk
done

for enum in ${exclude_array[@]};
do
	enum=$((${enum}+9))
	sed 's/exc/'"${enum}"'/g' <<<$(echo ${exclude_pattern}) >> ${output_dir}/${prefix}.awk
done

awk 'NR==FNR {last=$0; print} \
END {gsub(/&& \\/, "{", last); \
print last}' ${output_dir}/${prefix}.awk > ${output_dir}/temp.txt && \
mv ${output_dir}/temp.txt ${output_dir}/${prefix}.awk

echo -e "\t print \$0\n}" >> ${output_dir}/${prefix}.awk

bcftools view -h ${variants} > ${output_dir}/${prefix}.vcf
bcftools view -H ${variants} | awk -f ${output_dir}/${prefix}.awk >> ${output_dir}/${prefix}.vcf

bgzip ${output_dir}/${prefix}.vcf
tabix ${output_dir}/${prefix}.vcf.gz
