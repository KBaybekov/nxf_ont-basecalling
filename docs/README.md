# nxf_ont/basecalling: Documentation

The nxf_ont/basecalling documentation is split into the following pages:

- [Usage](usage.md)
  - An overview of how the pipeline works, how to run it and a description of all of the different command-line flags.
- [Output](output.md)
  - An overview of the different results produced by the pipeline and how to interpret them.

TODO:

- сохранение исходных данных multiqc
- readme
- тесты
- референсы и цитирования
- описание в multiqc
- лого ЦСП

typical cmd:

nextflow -log /common_share/github/nextflow/nxf_ont-basecalling/tmp/tmp0/result/logs/nextflow/sample_1630_log.log run ../ -c /common_share/github/nextflow/nxf_ont-basecalling/tests/data/full_size_fast5_1Tb.config --outdir /common_share/github/nextflow/nxf_ont-basecalling/tmp/result/

typical config :

tests/data/full_size_fast5_1Tb.config
