#!/usr/bin/env python3

from sys import argv
from pod5 import Reader
from json import dumps
from datetime import datetime

version = '1.0.0'
def read_pod5(pod5_file:str) -> dict:
    metadata = {}
    with Reader(pod5_file) as reader:
        try:
            # Берём первый рид, читаем его свойства
            read = next(reader.reads())
        except StopIteration:
            return metadata
        # Собираем метадату по свойствам read.run_info, в случае её отсутствия - пишем 'unknown'
        if read.run_info.acquisition_start_time:
            read.run_info.acquisition_start_time
            metadata['created'] = read.run_info.acquisition_start_time.strftime('%d.%m.%Y %H:%M:%S')
        if read.run_info.context_tags:
            for key in ['sample_frequency', 'sequencing_kit']:
                if key in read.run_info.context_tags.keys():
                    metadata[key] = read.run_info.context_tags[key]
            # Вытаскиваем basecall_config_filename для извлечения данных о поре и скорости чтения
            basecall_config_filename = read.run_info.context_tags.get('basecall_config_filename', '')
            if basecall_config_filename:
                bcf_parts = basecall_config_filename.split('_')
                metadata['experiment_type'] = bcf_parts[0]
                metadata['pore'] = bcf_parts[1].replace('.', '')
                metadata['pore_speed'] = bcf_parts[2]
        
        for k,v in {'flow_cell':read.run_info.flow_cell_product_code,
                    'sequencer_type':read.run_info.sequencer_position_type}.items():
            if v:
                metadata[k] = v
        #print(metadata)
        # Проверка, что мы имеем все важные данные и они валидны
        for important_key in [
                              'experiment_type',
                              'pore',
                              'pore_speed',
                              'sample_frequency',
                              'sequencing_kit'
                             ]:
            if any([
                    important_key not in metadata.keys(),
                    not data_is_valid(important_key, metadata[important_key])
                  ]):
                return {}
    return metadata

def data_is_valid(key:str, value:str) -> bool:
    validations = {
                   'experiment_type':['dna', 'rna'],
                   'pore':['r941', 'r1041', 'rp4'],
                   'pore_speed':['70bps', '130bps', '260bps', '400bps', '450bps', 'e8.2'],
                   'sample_frequency':['3000', '3012', '4000', '5000']
                  }
    if key == 'sequencing_kit':
        if value:
            return True
    if value in validations[key]:
        return True
    return False

if __name__ == '__main__':
    request = argv[1]
    if request == 'version':
        data = version
    else:
        data = dumps(read_pod5(request))
    print(data)