process GROUP_POD5S {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(pod5_files)

    output:
    tuple val(meta), path("${meta.id}_pod5_folder"), emit: folder
    path "versions.yml", emit: versions
    script:
    """
    mkdir -p ${meta.id}_pod5_folder

    # Файлы уже симлинки, нужно получить их цели
    for file in *.pod5; do
        if [[ -L "\$file" ]]; then
            # Это симлинк, берем его цель
            target=\$(readlink "\$file")
            ln -s "\$target" ${meta.id}_pod5_folder/
        elif [[ -f "\$file" ]]; then
            # Обычный файл
            ln -s "\$(realpath "\$file")" ${meta.id}_pod5_folder/
        fi
    done

    echo "Files in folder:"
    ls -la ${meta.id}_pod5_folder/
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}