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

    # Создаём симлинки вместо копирования
    for file in ${pod5_files}; do
        ln -s "\$(readlink -f "\$file")" ${meta.id}_pod5_folder/
    done

    echo "Files in folder:"
    ls -la
        cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}