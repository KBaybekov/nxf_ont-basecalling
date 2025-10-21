process DORADO_BASECALLER {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/dorado_environment.yml"
    container get_dorado_container(meta.pore_version)

    input:
    tuple val(meta), path(pod5_files)

    output:
    tuple val(meta), path("*.ubam"), emit: ubam
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
        
    // Определяем модификации для базового и дополнительных вызовов
    def modifications_list = get_modifications_list(meta.pore_version, meta.molecule_type)
    
    // Создаем команды для базового и модификационного basecalling
    def basecalling_commands = []
    
    // Базовый basecalling (без модификаций)
    basecalling_commands.add("""
    dorado basecaller \\
        $args \\
        sup \\
        --emit-moves \\
        $pod5_files > ${prefix}_basic.ubam
    """)
    
    // Basecalling с модификациями
    modifications_list.each { mod ->
        def mod_safe = mod.replaceAll('[,]', '_')
        basecalling_commands.add("""
    dorado basecaller \\
        $args \\
        sup \\
        --modified-bases $mod \\
        --emit-moves \\
        $pod5_files > ${prefix}_${mod_safe}.ubam
        """)
    }
    
    def all_commands = basecalling_commands.join('\n\n')
    
    """
    $all_commands

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado --version 2>&1 | head -n1 | sed 's/dorado //')
    END_VERSIONS
    """
}

def get_dorado_container(pore_version) {
    def container_map = [
        'r941': 'nanoporetech/dorado:sha268dcb4cd02093e75cdc58821f8b93719c4255ed',
        'r1041': 'nanoporetech/dorado:shae423e761540b9d08b526a1eb32faf498f32e8f22'
    ]
    return container_map[pore_version] ?: 'nanoporetech/dorado:sha268dcb4cd02093e75cdc58821f8b93719c4255ed'
}

def get_modifications_list(pore_version, molecule_type) {
    def modifications_map = [
        'r941': [
            'dna': ['5mCG', '5mCG_5hmCG'],
            'rna': ['m5C,m6A_DRACH', 'inosine_m6A,pseU', 'm6A']
        ],
        'r1041': [
            'dna': ['5mC,6mA', '4mC_5mC', '5mC_5hmC', '5mCG_5hmCG'],
            'rna': ['inosine_m6A,pseU_2OmeU', 'inosine_m6A_2OmeA,m5C,pseU', 'm6A_DRACH,2OmeG', 'm5C_2OmeC,m6A']
        ]
    ]
    return modifications_map[pore_version]?[molecule_type] ?: []
}