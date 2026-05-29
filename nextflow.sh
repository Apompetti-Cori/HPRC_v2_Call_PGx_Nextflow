#!/bin/bash

nextflow \
-log "./.nextflow/pipeline_info/nextflow.log" \
run $(find . -type f -path "*/HPRC_PBSPHASE_Nextflow/main.nf") \
-resume \
-work-dir $(pwd)/.nextflow/work/ \
-with-dag "./.nextflow/pipeline_info/pipeline_dag.svg" \
-with-report "./.nextflow/pipeline_info/execution_report.html" \
-with-trace "./.nextflow/pipeline_info/execution_trace.txt" \
--sample_table $(find $(pwd) -type f -name "sample_table.csv") \
--genome "GRCh38"