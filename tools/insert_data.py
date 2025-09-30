#!/usr/bin/env python3
"""
Insert Data - JSON Format Converter
Converts various JSON formats to the standardized data-example.json format.

Usage: python3 insert_data.py [input_file] [output_file] [--include-all] [--wipe-output-file]
"""

import json
import sys
from pathlib import Path
from difflib import SequenceMatcher

# ANSI color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# Essential fields required in the output format
ESSENTIAL_LEVEL_FIELDS = ['id', 'title', 'facts']  # factCount is auto-generated
ESSENTIAL_FACT_FIELDS = ['index', 'operands', 'operator', 'result', 'expression']  # type is optional

# Optional fields that can be included
OPTIONAL_LEVEL_FIELDS = ['objective', 'standards', 'mastery', 'difficulty']
OPTIONAL_FACT_FIELDS = ['prompt', 'asking_for', 'type']

# Statistics tracking
stats = {
    'levels_processed': 0,
    'facts_processed': 0,
    'facts_skipped': 0,
    'warnings': [],
    'field_mappings': {}
}

def similarity(a, b):
    """Calculate similarity ratio between two strings."""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def find_similar_keys(target_key, available_keys, threshold=0.6):
    """Find keys similar to the target key."""
    similar = []
    for key in available_keys:
        score = similarity(target_key, key)
        if score >= threshold:
            similar.append((key, score))
    return sorted(similar, key=lambda x: x[1], reverse=True)

def prompt_user_for_field(field_name, available_keys, context=""):
    """Prompt user to map a field from available keys."""
    similar = find_similar_keys(field_name, available_keys)
    
    print(f"\n🔍 {Colors.OKBLUE}Looking for field: '{field_name}'{Colors.ENDC}")
    if context:
        print(f"   Context: {context}")
    
    if similar:
        print(f"\n   Potential matches found:")
        for i, (key, score) in enumerate(similar[:5], 1):
            confidence = "★★★" if score > 0.8 else "★★☆" if score > 0.6 else "★☆☆"
            print(f"   {i}. '{key}' {confidence}")
        print(f"   0. None of these / Skip")
    else:
        print(f"   {Colors.WARNING}No similar fields found in source data.{Colors.ENDC}")
        print(f"   Available fields: {', '.join(available_keys[:10])}")
        if len(available_keys) > 10:
            print(f"   ... and {len(available_keys) - 10} more")
    
    while True:
        if similar:
            choice = input(f"\n   Select option (0-{len(similar[:5])}): ").strip()
            try:
                choice_num = int(choice)
                if choice_num == 0:
                    return None
                if 1 <= choice_num <= len(similar[:5]):
                    selected = similar[choice_num - 1][0]
                    print(f"   ✅ Mapped '{field_name}' → '{selected}'")
                    return selected
                else:
                    print(f"   {Colors.FAIL}Invalid choice. Try again.{Colors.ENDC}")
            except ValueError:
                print(f"   {Colors.FAIL}Please enter a number.{Colors.ENDC}")
        else:
            manual = input(f"\n   Enter field name manually (or press Enter to skip): ").strip()
            if not manual:
                return None
            if manual in available_keys:
                print(f"   ✅ Mapped '{field_name}' → '{manual}'")
                return manual
            else:
                print(f"   {Colors.FAIL}Field '{manual}' not found. Try again.{Colors.ENDC}")

def auto_generate_operator(fact_type):
    """Auto-generate operator based on fact type."""
    type_to_operator = {
        'addition': '+',
        'subtraction': '-',
        'multiplication': '*',
        'division': '/',
        'identify_numerator': 'identify',
        'identify_denominator': 'identify',
        'compare_to_half': 'compare',
        'compare_two_fractions': 'compare',
        'equivalent_fill_numerator': 'equivalent',
        'equivalent_fill_denominator': 'equivalent',
        'add_like_denominators': '+',
        'subtract_like_denominators': '-',
        'is_unit_fraction': 'identify',
    }
    return type_to_operator.get(fact_type, '')

def prompt_for_optional_fields(available_fields, context="level"):
    """Ask user which optional fields to include."""
    optional_pool = OPTIONAL_LEVEL_FIELDS if context == "level" else OPTIONAL_FACT_FIELDS
    found_optional = [f for f in available_fields if f in optional_pool or f not in ESSENTIAL_LEVEL_FIELDS + ESSENTIAL_FACT_FIELDS]
    
    if not found_optional:
        return []
    
    print(f"\n📋 {Colors.OKCYAN}Optional fields found in {context} data:{Colors.ENDC}")
    for i, field in enumerate(found_optional, 1):
        print(f"   {i}. {field}")
    
    print(f"\n   Enter field numbers to include (comma-separated), 'all', or press Enter to skip:")
    choice = input(f"   Choice: ").strip().lower()
    
    if not choice:
        return []
    if choice == 'all':
        print(f"   ✅ Including all optional fields")
        return found_optional
    
    try:
        indices = [int(x.strip()) for x in choice.split(',')]
        selected = [found_optional[i-1] for i in indices if 1 <= i <= len(found_optional)]
        print(f"   ✅ Including: {', '.join(selected)}")
        return selected
    except (ValueError, IndexError):
        print(f"   {Colors.WARNING}Invalid input. Skipping optional fields.{Colors.ENDC}")
        return []

def map_fact(source_fact, field_mapping, optional_fields, level_context):
    """Map a single fact to the target format."""
    try:
        target_fact = {}
        
        # Map essential fields
        for essential_field in ESSENTIAL_FACT_FIELDS:
            if essential_field == 'operator':
                # Try to get operator, or auto-generate
                if 'operator' in field_mapping and field_mapping['operator'] in source_fact:
                    target_fact['operator'] = source_fact[field_mapping['operator']]
                elif 'operator' in source_fact:
                    target_fact['operator'] = source_fact['operator']
                else:
                    # Auto-generate from type
                    fact_type = target_fact.get('type', '')
                    target_fact['operator'] = auto_generate_operator(fact_type)
                    if not target_fact['operator']:
                        stats['warnings'].append(
                            f"Level '{level_context}' fact #{source_fact.get('index', '?')}: No operator found or generated"
                        )
            else:
                mapped_key = field_mapping.get(essential_field, essential_field)
                if mapped_key in source_fact:
                    target_fact[essential_field] = source_fact[mapped_key]
                else:
                    # Essential field missing
                    stats['warnings'].append(
                        f"Level '{level_context}' fact #{source_fact.get('index', '?')}: Missing essential field '{essential_field}'"
                    )
                    return None
        
        # Map optional fields
        for opt_field in optional_fields:
            if opt_field in source_fact:
                target_fact[opt_field] = source_fact[opt_field]
            elif opt_field in field_mapping and field_mapping[opt_field] in source_fact:
                target_fact[opt_field] = source_fact[field_mapping[opt_field]]
        
        stats['facts_processed'] += 1
        return target_fact
        
    except Exception as e:
        stats['warnings'].append(
            f"Level '{level_context}' fact #{source_fact.get('index', '?')}: Error processing - {str(e)}"
        )
        return None

def convert_json(input_data, include_all_optional=False):
    """Convert input JSON to target format."""
    print(f"\n{'='*60}")
    print(f"🚀 {Colors.HEADER}{Colors.BOLD}Starting Conversion Process{Colors.ENDC}")
    print(f"{'='*60}")
    
    # Step 1: Find the levels/tracks container
    print(f"\n📦 {Colors.OKBLUE}Step 1: Identifying levels container...{Colors.ENDC}")
    
    levels_key = None
    if 'levels' in input_data:
        levels_key = 'levels'
        print(f"   ✅ Found 'levels' key")
    else:
        print(f"   ⚠️  'levels' key not found")
        potential_keys = [k for k in input_data.keys() if isinstance(input_data[k], (dict, list))]
        
        if potential_keys:
            print(f"\n   Potential container keys:")
            for i, key in enumerate(potential_keys, 1):
                data_type = "array" if isinstance(input_data[key], list) else "object"
                print(f"   {i}. '{key}' ({data_type})")
            
            while True:
                choice = input(f"\n   Select the key containing levels (1-{len(potential_keys)}): ").strip()
                try:
                    choice_num = int(choice)
                    if 1 <= choice_num <= len(potential_keys):
                        levels_key = potential_keys[choice_num - 1]
                        print(f"   ✅ Using '{levels_key}' as levels container")
                        break
                    else:
                        print(f"   {Colors.FAIL}Invalid choice. Try again.{Colors.ENDC}")
                except ValueError:
                    print(f"   {Colors.FAIL}Please enter a number.{Colors.ENDC}")
    
    if not levels_key:
        print(f"   {Colors.FAIL}❌ Could not identify levels container. Aborting.{Colors.ENDC}")
        return None
    
    # Get levels data and convert to array if needed
    levels_data = input_data[levels_key]
    if isinstance(levels_data, dict):
        print(f"   🔄 Converting object to array...")
        levels_array = list(levels_data.values())
    else:
        levels_array = levels_data
    
    print(f"   📊 Found {len(levels_array)} level(s)")
    
    if not levels_array:
        print(f"   {Colors.FAIL}❌ No levels found. Aborting.{Colors.ENDC}")
        return None
    
    # Step 1.5: Check if we need to flatten nested tracks structure
    sample_level = levels_array[0]
    available_level_keys = list(sample_level.keys())
    
    # Detect if this is a nested structure (e.g., grades → tracks)
    if 'tracks' in available_level_keys and isinstance(sample_level['tracks'], dict):
        print(f"\n🔍 {Colors.OKCYAN}Detected nested structure with 'tracks'...{Colors.ENDC}")
        print(f"   📦 Flattening: extracting tracks from each container")
        
        flattened_levels = []
        for container in levels_array:
            if 'tracks' in container and isinstance(container['tracks'], dict):
                for track in container['tracks'].values():
                    flattened_levels.append(track)
        
        levels_array = flattened_levels
        print(f"   ✅ Flattened to {len(levels_array)} track(s)")
    
    # Step 2: Analyze first level structure
    print(f"\n🔍 {Colors.OKBLUE}Step 2: Analyzing level structure...{Colors.ENDC}")
    sample_level = levels_array[0]
    available_level_keys = list(sample_level.keys())
    print(f"   Available fields: {', '.join(available_level_keys)}")
    
    # Map level fields
    level_field_mapping = {}
    for essential_field in ESSENTIAL_LEVEL_FIELDS:
        if essential_field in available_level_keys:
            level_field_mapping[essential_field] = essential_field
            print(f"   ✅ '{essential_field}' found")
        else:
            mapped = prompt_user_for_field(essential_field, available_level_keys, "level field")
            if mapped:
                level_field_mapping[essential_field] = mapped
                stats['field_mappings'][f"level.{essential_field}"] = mapped
            else:
                print(f"   {Colors.FAIL}❌ Essential field '{essential_field}' not mapped. Aborting.{Colors.ENDC}")
                return None
    
    # Handle optional level fields
    if include_all_optional:
        print(f"\n   🎯 Including all optional fields")
        optional_level_fields = [f for f in available_level_keys if f not in level_field_mapping.values()]
    else:
        optional_level_fields = prompt_for_optional_fields(available_level_keys, "level")
    
    # Step 3: Analyze fact structure
    print(f"\n🔍 {Colors.OKBLUE}Step 3: Analyzing fact structure...{Colors.ENDC}")
    
    # Find facts array in sample level
    facts_key = level_field_mapping['facts']
    if facts_key not in sample_level or not sample_level[facts_key]:
        print(f"   {Colors.FAIL}❌ No facts found in first level. Aborting.{Colors.ENDC}")
        return None
    
    sample_fact = sample_level[facts_key][0]
    available_fact_keys = list(sample_fact.keys())
    print(f"   Available fields: {', '.join(available_fact_keys)}")
    
    # Map fact fields
    fact_field_mapping = {}
    for essential_field in ESSENTIAL_FACT_FIELDS:
        if essential_field == 'operator':
            # Operator is special - can be auto-generated
            if 'operator' in available_fact_keys:
                fact_field_mapping['operator'] = 'operator'
                print(f"   ✅ 'operator' found")
            else:
                print(f"   ⚠️  'operator' not found - will auto-generate from type")
                fact_field_mapping['operator'] = None
        elif essential_field in available_fact_keys:
            fact_field_mapping[essential_field] = essential_field
            print(f"   ✅ '{essential_field}' found")
        else:
            mapped = prompt_user_for_field(essential_field, available_fact_keys, "fact field")
            if mapped:
                fact_field_mapping[essential_field] = mapped
                stats['field_mappings'][f"fact.{essential_field}"] = mapped
            else:
                print(f"   {Colors.FAIL}❌ Essential field '{essential_field}' not mapped. Aborting.{Colors.ENDC}")
                return None
    
    # Handle optional fact fields
    if include_all_optional:
        print(f"\n   🎯 Including all optional fields")
        optional_fact_fields = [f for f in available_fact_keys if f not in fact_field_mapping.values() and f is not None]
    else:
        optional_fact_fields = prompt_for_optional_fields(available_fact_keys, "fact")
    
    # Step 4: Process all levels
    print(f"\n⚙️  {Colors.OKBLUE}Step 4: Processing levels...{Colors.ENDC}")
    output_levels = []
    
    for i, source_level in enumerate(levels_array, 1):
        print(f"\n   Processing level {i}/{len(levels_array)}...", end=' ')
        
        target_level = {}
        
        # Map level fields
        for essential_field in ESSENTIAL_LEVEL_FIELDS:
            if essential_field == 'facts':
                continue  # Handle separately
            mapped_key = level_field_mapping[essential_field]
            if mapped_key in source_level:
                target_level[essential_field] = source_level[mapped_key]
        
        # Add optional level fields
        for opt_field in optional_level_fields:
            if opt_field in source_level:
                target_level[opt_field] = source_level[opt_field]
        
        # Process facts
        facts_key = level_field_mapping['facts']
        source_facts = source_level.get(facts_key, [])
        target_facts = []
        
        level_title = target_level.get('title', f'Level {i}')
        
        for source_fact in source_facts:
            mapped_fact = map_fact(source_fact, fact_field_mapping, optional_fact_fields, level_title)
            if mapped_fact:
                target_facts.append(mapped_fact)
            else:
                stats['facts_skipped'] += 1
        
        # Add factCount before facts for proper ordering
        target_level['factCount'] = len(target_facts)
        target_level['facts'] = target_facts
        
        output_levels.append(target_level)
        stats['levels_processed'] += 1
        
        print(f"✅ ({len(target_facts)} facts)")
    
    return {'levels': output_levels}

def print_report():
    """Print a detailed conversion report."""
    print(f"\n{'='*60}")
    print(f"📊 {Colors.HEADER}{Colors.BOLD}Conversion Report{Colors.ENDC}")
    print(f"{'='*60}")
    
    print(f"\n✅ {Colors.OKGREEN}Success:{Colors.ENDC}")
    print(f"   • Levels processed: {stats['levels_processed']}")
    print(f"   • Facts processed: {stats['facts_processed']}")
    
    if stats['facts_skipped'] > 0:
        print(f"\n⚠️  {Colors.WARNING}Warnings:{Colors.ENDC}")
        print(f"   • Facts skipped: {stats['facts_skipped']}")
    
    if stats['field_mappings']:
        print(f"\n🗺️  {Colors.OKCYAN}Field Mappings:{Colors.ENDC}")
        for target, source in stats['field_mappings'].items():
            print(f"   • {target} ← {source}")
    
    if stats['warnings']:
        print(f"\n⚠️  {Colors.WARNING}Detailed Warnings:{Colors.ENDC}")
        for warning in stats['warnings'][:10]:  # Show first 10
            print(f"   • {warning}")
        if len(stats['warnings']) > 10:
            print(f"   ... and {len(stats['warnings']) - 10} more warnings")
    
    print(f"\n{'='*60}")

def main():
    """Main entry point."""
    # Parse arguments
    if len(sys.argv) < 3:
        print(f"{Colors.FAIL}❌ Usage: python3 insert_data.py [input_file] [output_file] [--include-all] [--wipe-output-file]{Colors.ENDC}")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    include_all = '--include-all' in sys.argv or '--include_all' in sys.argv
    wipe_output = '--wipe-output-file' in sys.argv or '--wipe_output_file' in sys.argv
    
    # Load input file
    print(f"\n📂 Loading input file: {input_file}")
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            input_data = json.load(f)
        print(f"   ✅ File loaded successfully")
    except FileNotFoundError:
        print(f"   {Colors.FAIL}❌ File not found: {input_file}{Colors.ENDC}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"   {Colors.FAIL}❌ Invalid JSON: {e}{Colors.ENDC}")
        sys.exit(1)
    
    # Check if output file exists and handle merging
    existing_data = None
    if Path(output_file).exists() and not wipe_output:
        print(f"\n📂 Output file already exists: {output_file}")
        try:
            with open(output_file, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
            
            if 'levels' in existing_data and isinstance(existing_data['levels'], list):
                existing_count = len(existing_data['levels'])
                print(f"   📊 Found {existing_count} existing level(s)")
                print(f"   🔄 Will merge new data with existing levels")
            else:
                print(f"   ⚠️  Existing file doesn't have valid 'levels' array")
                print(f"   🔄 Will replace with new data")
                existing_data = None
        except json.JSONDecodeError:
            print(f"   ⚠️  Existing file has invalid JSON")
            print(f"   🔄 Will replace with new data")
            existing_data = None
        except Exception as e:
            print(f"   ⚠️  Error reading existing file: {e}")
            print(f"   🔄 Will replace with new data")
            existing_data = None
    elif wipe_output and Path(output_file).exists():
        print(f"\n🗑️  {Colors.WARNING}Wiping existing output file: {output_file}{Colors.ENDC}")
    
    # Convert
    output_data = convert_json(input_data, include_all)
    
    if output_data is None:
        print(f"\n{Colors.FAIL}❌ Conversion failed. No output file created.{Colors.ENDC}")
        sys.exit(1)
    
    # Merge with existing data if applicable
    if existing_data and 'levels' in existing_data:
        original_count = len(output_data['levels'])
        output_data['levels'] = existing_data['levels'] + output_data['levels']
        print(f"\n🔀 {Colors.OKCYAN}Merged data:{Colors.ENDC}")
        print(f"   • Existing levels: {len(existing_data['levels'])}")
        print(f"   • New levels: {original_count}")
        print(f"   • Total levels: {len(output_data['levels'])}")
    
    # Save output file
    print(f"\n💾 {Colors.OKBLUE}Saving output file: {output_file}{Colors.ENDC}")
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)
        print(f"   ✅ File saved successfully")
    except Exception as e:
        print(f"   {Colors.FAIL}❌ Error saving file: {e}{Colors.ENDC}")
        sys.exit(1)
    
    # Print report
    print_report()
    
    print(f"\n🎉 {Colors.OKGREEN}{Colors.BOLD}Conversion complete!{Colors.ENDC}")

if __name__ == "__main__":
    main()
