process FAST5_TO_POD5 {
    tag "$fast5_file"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pod5:0.3.23--pyhdfd78af_0' :
        'quay.io/biocontainers/pod5:0.3.23--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(fast5_file)

    output:
    tuple val(meta), path("*.pod5"), emit: pod5
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    pod5 convert fast5 \\
        $args \\
        --output ${fast5_file.baseName}.pod5 \\
        $fast5_file
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pod5: \$(pod5 --version 2>&1 | sed 's/Pod5 version: //')
    END_VERSIONS
    """
}