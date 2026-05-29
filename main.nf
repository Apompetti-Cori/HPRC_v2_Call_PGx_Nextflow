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

params.sample_table = false

params.genome = false
params.db = params.genome ? params.genomes[ params.genome ].db ?: false : false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false

params.vcf = false // hprc merged vcf file
params.pbspdb = false // pbstarphase db file
params.bed_filter = false // bed file for filtering alignments

params.clean_script = false // script for cleaning up work files

/*
================================================================================
Include modules to main pipeline
================================================================================
*/

/*
================================================================================
Include functions to main pipeline
================================================================================
*/

include { createInputChannel } from './functions/main.nf'

/*
================================================================================
Include subworkflows to main pipeline
================================================================================
*/

include { CALL_STARPHASE } from './subworkflows/call_starphase/main.nf'

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow {

    // Create an empty channel for multiqc input
    def multiqc_ch = channel.empty()

    // Ingest sample table to create input channel
    def input_ch = createInputChannel(params.sample_table)

    CALL_STARPHASE(input_ch)
}