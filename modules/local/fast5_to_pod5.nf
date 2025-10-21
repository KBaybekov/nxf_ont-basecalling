process FAST5_TO_POD5 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pod5:0.3.23--pyhdfd78af_0' :
        'biocontainers/pod5:0.3.23--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(fast5_files), val(threads)

    output:
    tuple val(meta), path("*.pod5"), emit: pod5
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    pod5 convert fast5 \\
        $args \\
        --output ${prefix}.pod5 \\
        --threads $threads \\
        $fast5_files

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pod5: \$(pod5 --version 2>&1 | sed 's/pod5 //')
    END_VERSIONS
    """
}