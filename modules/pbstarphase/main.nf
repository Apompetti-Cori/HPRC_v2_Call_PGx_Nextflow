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
params.pubdir = "pbstarphase"

/*
================================================================================
Module declaration
================================================================================
*/

process PBSTARPHASE {

    maxForks 3
    cache 'lenient'

    conda "bioconda::pbstarphase=2.1.0"

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Check batch and save output accordingly
    storeDir {
        meta.batch == '' ? "${params.outdir}/${meta.id}/${params.pubdir}" : "${params.outdir}/${meta.batch}/${meta.id}/${params.pubdir}"
    }

    input:
    tuple val(meta), path(reads)
    each path(db)
    each fasta
    each path(pbspdb)
    each path(vcf)
    each path(tbi)
    each path(clean)

    output:
    tuple val(meta), path("*.pbstarphase.json*"), emit: calls

    script:

    """
    export RUST_BACKTRACE=1
    
    pbstarphase diplotype \
        --bam ${reads[0]} \
        --database ${pbspdb} \
        --reference ${db}/${fasta} \
        --vcf ${vcf[0]} \
        --output-calls ${meta.id}.pbstarphase.json
    """
}