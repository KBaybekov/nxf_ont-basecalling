process FAST5_TO_POD5_BATCH {
    tag "batch_${task.index}"
    label 'process_medium'
    scratch 'ram-disk'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pod5:0.3.23--pyhdfd78af_0' :
        'quay.io/biocontainers/pod5:0.3.23--pyhdfd78af_0' }"
    
    input:
    tuple val(meta), path(fast5_files)
    
    output:
    tuple val(meta), path("*.pod5"), emit: pod5
    path "versions.yml", emit: versions
    
        script:
    def args = task.ext.args ?: ''
    """
    # Обрабатываем каждый файл в батче
    for file in ${fast5_files}; do
        pod5 convert fast5 \\
            $args \\
            --threads 2 \\
            --output \${file%.fast5}.pod5 \\
            \$file &
    done

    # Ждем завершения ВСЕХ процессов
    wait

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pod5: \$(pod5 --version 2>&1 | sed 's/Pod5 version: //')
    END_VERSIONS
    """
}

/*
    # Сохраняем текущую рабочую директорию
    WORK_DIR=\$(pwd)

    # Копируем файлы на локальный диск узла
    LOCAL_DIR=\${TMPDIR:-/tmp}/nextflow_${workflow.runName}_fast5_to_pod5_${meta.id}_batch_${task.index}
    mkdir -p \$LOCAL_DIR
    
    # Копируем входные файлы локально
    cp ${fast5_files} \$LOCAL_DIR/
    
    # Обрабатываем локально
    cd \$LOCAL_DIR
    # Обрабатываем каждый файл в батче
    for file in ${fast5_files}; do
        pod5 convert fast5 \\
            $args \\
            --output \${file%.fast5}.pod5 \\
            \$file &
    done

    # Ждем завершения ВСЕХ процессов
    wait

    # Копируем результаты обратно
    cp -r *.pod5 \$WORK_DIR
    
    # Очищаем локальный диск
    rm -rf \$LOCAL_DIR
    
    cd \$WORK_DIR
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pod5: \$(pod5 --version 2>&1 | sed 's/Pod5 version: //')
    END_VERSIONS
    */