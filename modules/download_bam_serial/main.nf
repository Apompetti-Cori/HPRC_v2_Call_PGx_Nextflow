#!/usr/bin/env nextflow

/*
================================================================================
Coriell Institute for Medical Research

Contributors:
Anthony Pompetti <apompetti@coriell.org>
================================================================================
*/

/*
================================================================================
Enable Nextflow DSL2
================================================================================
*/
nextflow.enable.dsl=2

/*
================================================================================
Configurable variables for module
================================================================================
*/
params.outdir = "./nfoutput"
params.pubdir = "pbmm2"

/*
================================================================================
Module declaration
================================================================================
*/

process DOWNLOAD_BAM {

    cpus 32
    memory '32 GB'
    maxForks 3
    cache 'lenient'

    conda "/usr/local/programs/miniconda3/envs/pbmm2"

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Set up scratch directory for this process
    scratch "${launchDir}/.nextflow/scratch/"

    storeDir {
        meta.batch == '' ? "${params.outdir}/${meta.id}/${params.pubdir}" : "${params.outdir}/${meta.batch}/${meta.id}/${params.pubdir}"
    }

    input:
    tuple val(meta), val(s3)
    each path(db)
    each path(bed)
    each fasta
    each path(clean)

    output:
    tuple val(meta), path("*.GRCh38.filtered.sorted.bam*"), emit: reads

    script:

    """
    # Bash array for storing aligned bam files

    ALIGNED_BAMS=()

    # Function for aligning different read types. 
    # CCS and HIFI reads cannot be put in the same fofn apparently and must be merged separately

    align_group() {
        local pattern="\$1"
        local suffix="\$2"
        local preset="\$3"
        local fofn="input_\${suffix}.fofn"
        
        # Use find to safely identify files and avoid literal glob issues
        # This looks for files in the current directory matching the pattern
        find . -maxdepth 1 -name "\$pattern" > "\$fofn"

        # Check if the FOFN is empty
        if [ ! -s "\$fofn" ]; then
            echo "No files found matching [\$pattern]. Skipping \$suffix."
            rm "\$fofn"
            return 0
        fi

        echo "Found files for \$suffix. Attempting batch alignment..."
        
        if pbmm2 align --num-threads ${task.cpus} \
                    --sort-threads 4 \
                    --preset "\${preset}" \
                    --sample ${meta.id} \
                    --sort \
                    --strip \
                    -k 15 -w 10 -l 50 \
                    ${db}/${fasta} "\$fofn" "${meta.id}.\${suffix}.aligned.bam"; then
            
            ALIGNED_BAMS+=("${meta.id}.\${suffix}.aligned.bam")
            echo "Batch alignment for \$suffix successful."
        else
            echo "WARNING: pbmm2 batch alignment failed for \$suffix. Falling back to individual..."
            
            local count=1
            while IFS= read -r file; do
                # Double check the file actually exists (not a literal glob)
                [ -f "\$file" ] || continue 

                local individual_out="${meta.id}.\${suffix}.\${count}.aligned.bam"
                pbmm2 align --num-threads ${task.cpus} \
                            --preset "\${preset}" \
                            --sample ${meta.id} \
                            --sort \
                            --strip \
                            -k 15 -w 10 -l 50 \
                            ${db}/${fasta} "\$file" "\$individual_out"
                
                ALIGNED_BAMS+=("\$individual_out")
                ((count++))
            done < "\$fofn"
        fi
        rm "\$fofn"
    }
    
    # Download s3 links provided

    echo "${s3.join('\n')}" | parallel --halt soon,fail=1 aws s3 --no-sign-request --quiet cp {} ./

    # Align each read type

    align_group "*.hifi_reads*.bam" "hifi_bam" "HIFI"
    align_group "*.hifi_reads*.fastq.gz" "hifi_fastq" "HIFI"
    align_group "*.ccs.bam" "ccs_bam" "CCS"

    # Merge all successful alignments

    if [ \${#ALIGNED_BAMS[@]} -eq 0 ]; then
        echo "Error: No matching sequence files found."
        exit 1
    elif [ \${#ALIGNED_BAMS[@]} -eq 1 ]; then
        mv "\${ALIGNED_BAMS[0]}" ${meta.id}.GRCh38.aligned.bam
    else
        echo "Merging all successful alignments: \${ALIGNED_BAMS[*]}"
        samtools merge -@ 8 ${meta.id}.GRCh38.aligned.bam "\${ALIGNED_BAMS[@]}"
    fi

    # Filter sort and index bam

    samtools view -@ 4 -L ${bed} -u ${meta.id}.GRCh38.aligned.bam | \
    samtools sort -@ 4 -o ${meta.id}.GRCh38.filtered.sorted.bam -

    samtools index ${meta.id}.GRCh38.filtered.sorted.bam
    """
}