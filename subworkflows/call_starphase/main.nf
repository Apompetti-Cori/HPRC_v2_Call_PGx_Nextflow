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
Configurable variables for pipeline
================================================================================
*/

/*
================================================================================
Include modules to main pipeline
================================================================================
*/

include { DOWNLOAD_BAM } from '../../modules/download_bam_serial/main.nf'
include { PBMM2 } from '../../modules/pbmm2/main.nf'
include { PBSTARPHASE } from '../../modules/pbstarphase/main.nf'

/*
================================================================================
Include functions to main pipeline
================================================================================
*/

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow CALL_STARPHASE {

    take:
        input_ch

    main:
        // Create an empty channel for multiqc input
        def multiqc_ch = channel.empty()
        
        // Download BAM file from S3
        DOWNLOAD_BAM(
            input_ch,
            channel.fromPath(params.db),
            channel.fromPath(params.bed_filter),
            channel.value(params.fasta),
            channel.value(params.clean_script)
        )
        
        // Run pbstarphase
        def vcf_files = files(params.vcf).sort{ item -> item.name }
        def vcf = vcf_files[0]
        def tbi = vcf_files[1]
        
        PBSTARPHASE(
            DOWNLOAD_BAM.out.reads,
            channel.fromPath(params.db),
            channel.value(params.fasta),
            channel.value(params.pbspdb),
            vcf,
            tbi,
            channel.value(params.clean_script)
        )
}