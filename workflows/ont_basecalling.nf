/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FAST5_TO_POD5_BATCH } from '../modules/local/fast5_to_pod5_batch'
//include { FAST5_TO_POD5 } from '../modules/local/fast5_to_pod5'
include { GROUP_POD5S } from '../modules/local/group_pod5s'
include { DORADO_BASECALLING } from '../modules/local/dorado_basecalling/main'
include { SEQUALI } from '../modules/nf-core/sequali/main' 
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { DB_FILLER              } from '../modules/local/db_filler/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_basecalling_pipeline'



/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow ONT_BASECALLING {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    ch_samplesheet.branch {_meta, file ->
    fast5: file.toString().endsWith('.fast5')
    pod5: file.toString().endsWith('.pod5')}
    .set { ch_branched }
    
    
    size_sorted_fast5_files_batches = ch_branched.fast5
                .toSortedList { a, b -> 
                    b[1].size() <=> a[1].size()  // сортировка по убыванию размера файла
                }
                .flatten()
                .collate(2)  // восстанавливаем структуру [meta, file]
                .buffer(size: 16)
                .map { batch -> 
                    def meta = batch[0][0]  // берем мету из первого элемента
                    def files = batch.collect { it[1] }  // собираем все файлы
                    [meta, files]
                }


    FAST5_TO_POD5_BATCH(size_sorted_fast5_files_batches)

    /*
    Раскомментировать при работе не в slurm
    FAST5_TO_POD5(ch_branched.fast5)
    */

    converted_pod5s_ch = FAST5_TO_POD5_BATCH.out.pod5.transpose()

    ch_prepared = ch_branched.pod5.mix(converted_pod5s_ch)
    ch_pod5s = ch_prepared
                .groupTuple()

    GROUP_POD5S(ch_pod5s)

    ch_basecalling_data = GROUP_POD5S.out.folder.map {meta, pod5_d ->
                            [meta, pod5_d, params.model_dir]
                            }
    
    DORADO_BASECALLING(ch_basecalling_data)

    SEQUALI(DORADO_BASECALLING.out.ubam)

    //
    // Collate and save software versions
    //
    ch_versions = ch_versions
                    .mix(FAST5_TO_POD5_BATCH.out.versions)
                    .mix(GROUP_POD5S.out.versions)
                    .mix(DORADO_BASECALLING.out.versions)
                    .mix(SEQUALI.out.versions)
    
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/logs/nextflow",
            name:  "${params.run_id}_" + 'software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    ch_multiqc_files = ch_multiqc_files
                        .mix(ch_collated_versions)
                        .mix(SEQUALI.out.json.map {it[1]})

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    // DB_FILLER part
    // Получаем каналы, которые эмитят строки (имена/пути)
    ch_ubam = DORADO_BASECALLING.out.ubam.map { _meta, ubam ->
                                                file(params.outdir).resolve(ubam.getName()).toAbsolutePath().toString() }
    ch_qc   = SEQUALI.out.html.map { _meta, html -> 
                                                file(params.outdir).resolve('qc').resolve(html.getName()).toAbsolutePath().toString() }
    ch_mqc  = MULTIQC.out.report.map { report -> 
                                                file(params.outdir).resolve('qc').resolve(report.getName()).toAbsolutePath().toString() }

    // Берём по одному значению из каждого (будут валидные строки при подстановке в process)
    // Если в каналах несколько элементов — используйте combine/zip вместо first()
    ch_ubam_first = ch_ubam.first()
    ch_qc_first   = ch_qc.first()
    ch_mqc_first  = ch_mqc.first()

    // json_files — ваш канал JSON'ов (оставьте как есть)
    json_files = SEQUALI.out.json.map { _meta, json -> json }

    // Вызов process: передаём три val + channel с json'ами
    DB_FILLER(ch_ubam_first, DORADO_BASECALLING.out.used_model, ch_qc_first, ch_mqc_first, json_files)


    emit:
    ubam           = DORADO_BASECALLING.out.ubam
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    sequali_json   = SEQUALI.out.json
    sequali_html   = SEQUALI.out.html
    data_to_db     = DB_FILLER.out.yaml
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
