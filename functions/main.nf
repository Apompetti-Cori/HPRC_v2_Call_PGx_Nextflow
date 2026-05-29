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
Function declaration
================================================================================
*/
def createInputChannel(String sample_table) {
    // Channel for the samplesheet
    def ch_samplesheet = channel.fromPath(sample_table)

    def input_ch = ch_samplesheet
        .splitCsv(header:true)
        .toSortedList({ a, b -> a.sample_id <=> b.sample_id })
        .flatten()
        .map{ row ->

            def id = row.sample_id
            def s3 = row.s3
            def _vcf = row.vcf
            
            def meta = [
                id : id,
                batch : row.batch
            ]

            [meta, s3]
        }
        .groupTuple()

    return input_ch
}
