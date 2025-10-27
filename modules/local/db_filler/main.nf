process DB_FILLER {
    publishDir "${params.outdir}", mode: 'copy'

    input:
      val ubam_path      // строка, напр. "./result/r941.ubam"
      val qc_name        // строка, напр. "t3_basic:basecalling_sequali.html"
      val mqc_name       // строка или 'null'
      path input_files   // список JSON'ов (channel)

    output:
      path "${params.run_id}_to_db.yaml", emit: yaml

    script:
    def set_params="--set ubam='${ubam_path}' --set qc='${qc_name}' --set mqc='${mqc_name}'"
    """
    OUTPUT_YAML="${params.run_id}_to_db.yaml"

    # Собираем dict внутри process — теперь все значения уже обычные строки
    

    # Формируем bash-массив из переданных путей
    FILES=(${input_files.collect { "\"${it.getName()}\"" }.join(' ')})

    echo "Processing \${#FILES[@]} files..." >> shell_execution.log

    for i in "\${!FILES[@]}"; do
      file="\${FILES[\$i]}"
      if [ "\$i" -eq 0 ]; then
        python3 ${moduleDir}/db_filler.py --input_json "\$file" --output_yaml "\$OUTPUT_YAML" --keys_prefix '${params.run_id}' ${set_params}
      else
        python3 ${moduleDir}/db_filler.py --input_json "\$file" --output_yaml "\$OUTPUT_YAML" --keys_prefix '${params.run_id}'
      fi
    done
    """
}

