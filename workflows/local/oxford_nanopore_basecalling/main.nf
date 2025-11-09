/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { NANOPORE_BASECALLING } from '../../../subworkflows/local/nanopore_basecalling'
include { QC_NANOPORE_BASECALLING } from '../../../subworkflows/local/qc_nanopore_basecalling'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow OXFORD_NANOPORE_BASECALLING {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    NANOPORE_BASECALLING(ch_samplesheet, ch_versions)
    QC_NANOPORE_BASECALLING(NANOPORE_BASECALLING.out.ubam, NANOPORE_BASECALLING.out.versions, ch_multiqc_files)

    emit:
    ubam             = NANOPORE_BASECALLING.out.ubam
    used_model       = NANOPORE_BASECALLING.out.used_model
    source_file_meta = NANOPORE_BASECALLING.out.metadata_tsv
    multiqc_report   = QC_NANOPORE_BASECALLING.out.multiqc_report
    sequali_json     = QC_NANOPORE_BASECALLING.out.sequali_json
    sequali_html     = QC_NANOPORE_BASECALLING.out.sequali_html
    versions         = QC_NANOPORE_BASECALLING.out.versions
}