process COLLECT_RESULTS {
    tag "pipeline_results"
    label 'process_single'
    publishDir params.outdir, mode: params.publish_dir_mode

    conda "${moduleDir}/python_environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    path(ubam_files)
    path(qc_reports)

    output:
    path "pipeline_results.yaml", emit: results
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    collect_pipeline_results.py \\
        --ubam-files $ubam_files \\
        --qc-reports $qc_reports \\
        --output pipeline_results.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        pyyaml: \$(python -c "import yaml; print(yaml.__version__)")
    END_VERSIONS
    """
}