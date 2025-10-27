#!/usr/bin/env python3
# encoding: utf-8

import argparse
from pathlib import Path
from json import load
from yaml import safe_load, dump
from typing import Any, Dict, List

def parse_cli_kv(pairs: List[str]) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for item in pairs:
        if not item:
            continue
        if '=' not in item:
            raise ValueError(f"Неверный формат пары (ожидается key=value): {item!r}")
        key, val = item.split('=', 1)
        key = key.strip()
        if not key:
            raise ValueError(f"Пустой ключ в паре: {item!r}")
        result[key] = val
    return result


def import_important_vals(input_file: Path, selected_keys: List[Any]) -> Dict[str, Any]:
    """Читает JSON и по шаблону selected_keys формирует словарь результатов.
    selected_keys — список элементов: либо строк, либо словарей с нужной структурой.
    Порядок ключей сохраняется в порядке списка."""
    with input_file.open('r', encoding='utf-8') as f:
        data = load(f)

    filtered: Dict[str, Any] = {}
    for item in selected_keys:
        if isinstance(item, str):
            # простая строка — значение на top-level
            filtered[item] = process_template(data, item)
        elif isinstance(item, dict):
            # словарь — process_template вернёт словарь с топ-уровневыми ключами,
            # добавляем их в итог, сохраняя порядок
            processed = process_template(data, item)
            if isinstance(processed, dict):
                # обновляем, чтобы верхние ключи dict попали как отдельные топ-level записи
                filtered.update(processed)
    return filtered


def process_template(data: Any, template: Any) -> Any:
    """Рекурсивно обрабатывает шаблон:
    - template == str  -> вернёт значение data[template] или '' если нет
    - template == list -> список ключей / вложенных шаблонов -> вернёт dict
    - template == dict -> вернёт dict с ключом->результат (рекурсивно)"""
    # Защититься, если data не dict (в глубине может быть пусто)
    if isinstance(template, str):
        return data.get(template, '') if isinstance(data, dict) else ''

    if isinstance(template, list):
        result: Dict[str, Any] = {}
        for elem in template:
            if isinstance(elem, str):
                result[elem] = data.get(elem, '') if isinstance(data, dict) else ''
            elif isinstance(elem, dict):
                # элемент списка может быть вложенным шаблоном вида {k: ...}
                for k, sub in elem.items():
                    result[k] = process_template(data.get(k, {}), sub) if isinstance(data, dict) else process_template({}, sub)
        return result

    if isinstance(template, dict):
        result: Dict[str, Any] = {}
        for key, sub_template in template.items():
            # спускаемся в data[key]
            sub_data = data.get(key, {}) if isinstance(data, dict) else {}
            # рекурсивно обрабатываем любой вид sub_template
            result[key] = process_template(sub_data, sub_template)
        return result

    # прочие типы — пусто
    return ''


def main():
    p = argparse.ArgumentParser(description="Import selected values from JSON to YAML by template.")
    p.add_argument("--input_json", type=Path, help="Input JSON file")
    p.add_argument("--output_yaml", type=Path, help="Output YAML file (will be created or updated)")
    p.add_argument("--keys_prefix", type=str, help="Prefix to add to all top-level keys in the output")
    p.add_argument("--set", type=str, action="append", default=[], help="Пара key=value, добавляется в начало итогового YAML в порядке указания")    
    p.add_argument("--config", type=Path, default=Path(__file__).resolve().parent / "config.yaml",
                   help="YAML template (default: ./config.yaml next to script)")
    args = p.parse_args()

    if not args.input_json.exists():
        raise SystemExit(f"Input JSON not found: {args.input_json}")

    if not args.config.exists():
        raise SystemExit(f"Config (template) YAML not found: {args.config}")


    with args.config.open('r', encoding='utf-8') as f:
        data = safe_load(f) or {}
        # загружаем из конфига только те ключи, которые относятся к данному файлу QC
        for key in data:
            if key in args.input_json.name:
                selected_keys = data[key]

    if not isinstance(selected_keys, list): # type: ignore
        raise SystemExit("Config (template) should be a YAML list (top-level).")

    preset_data = parse_cli_kv(args.set)
    
    filtered_data = import_important_vals(input_file=args.input_json, selected_keys=selected_keys)

    res_data = {**preset_data, **filtered_data}

    # Добавляем префикс ко всем top-level ключам (сохранение порядка)
    prefixed = {f"{args.keys_prefix}_{k}": v for k, v in res_data.items()}

    # Если YAML уже существует — дописываем / обновляем существующие ключи
    to_write = prefixed
    if args.output_yaml.exists():
        with args.output_yaml.open('r', encoding='utf-8') as f:
            old = safe_load(f) or {}
        if not isinstance(old, dict):
            old = {}
        old.update(prefixed)
        to_write = old

    # Сохраняем
    with args.output_yaml.open('w', encoding='utf-8') as f:
        dump(to_write, f, sort_keys=False, allow_unicode=True)

    # Краткий вывод результата
    print(f"Wrote {len(prefixed)} keys to {args.output_yaml}")


if __name__ == "__main__":
    main()
