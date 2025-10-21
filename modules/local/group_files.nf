process GROUP_FILES {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(pod5_files), val(pore_version), val(molecule_type)

    output:
    tuple val(meta_grouped), path(pod5_files), emit: grouped_files
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def group_key = "${pore_version}_${molecule_type}"
    def meta_grouped = meta + [group_key: group_key, pore_version: pore_version, molecule_type: molecule_type]
    """
    echo "Grouping files for ${meta.id} with pore version: ${pore_version}, molecule type: ${molecule_type}"
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}