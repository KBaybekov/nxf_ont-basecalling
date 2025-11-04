/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    МОДУЛЬ: DORADO_BASECALLING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Бейсколлинг POD5 файлов без выравнивания, с генерацией UBAM. Если версия поры 10.4.1 и не используется fast-модель, бейсколлинг проводится в duplex формате
    Входы: id образца, POD5 файлы, версия поры
    Выходы: UBAM, использованная модель для бейсколлинга, версия dorado
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process DORADO_BASECALLING {
    tag "$meta.id"
    label 'gpu_intensive_task'
    containerOptions '--gpus all'

    conda "${moduleDir}/dorado_environment.yml"
    container params.dorado_container
    

    input:
    tuple val(meta), path(pod5_folder), path(model_dir)

    output:
    tuple val(meta), path("*.ubam"),      emit: ubam
    env(USED_MODEL), emit: used_model 
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}:"
    def modifications_list = params.modifications != "basic" ? "--modified-bases ${params.modifications}":"--emit-moves"
    def mod = params.modifications != "basic" ? params.modifications.replaceAll(',', '_'):params.modifications
    def ubam_name = "${params.sample}_${mod}:${meta.pore_version}"
    def models_dir = model_dir ? "--models-directory ${model_dir}": ""

    if (!params.basecalling_model.contains("fast") && meta.pore == 'r1041') {
        dorado_cmd = """
            dorado duplex \\
            $args \\
            $models_dir \\
            $modifications_list \\
            --device cuda:all \\
            --recursive \\
            $params.basecalling_model \\
            ${pod5_folder}/ > ${ubam_name}.ubam
        """
    } else {
        dorado_cmd = """
            dorado basecaller \\
            $args \\
            $models_dir \\
            $modifications_list \\
            --device cuda:all \\
            --emit-moves \\
            --recursive \\
            $params.basecalling_model \\
            ${pod5_folder}/ > ${ubam_name}.ubam
        """
    }
    
    """
    ${dorado_cmd}

    export USED_MODEL=\$(samtools view \\
    -H ${ubam_name}.ubam \\
    | grep -oP \\
    'basecall_model=\\K[^ ]+' \\
    | head -1)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado --version 2>&1 | head -n1 | sed 's/dorado //')
    END_VERSIONS
    """
}
