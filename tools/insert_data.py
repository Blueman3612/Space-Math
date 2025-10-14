#!/usr/bin/env python3
"""
Insert Data - JSON Format Converter
Converts various JSON formats to the standardized data-example.json format.

Usage: python3 insert_data.py [input_file] [output_file] [options]

Options:
  --include-all          Include all optional fields without prompting
  --wipe-output-file     Replace existing output file instead of merging
  --selective            Review and approve each level individually
  --skip-invalid-facts   Skip facts with missing fields (default: interactive resolution)
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
ESSENTIAL_FACT_FIELDS = ['index', 'result', 'expression']

# Optional fields that can be included
OPTIONAL_LEVEL_FIELDS = ['objective', 'standards', 'mastery', 'difficulty']
OPTIONAL_FACT_FIELDS = ['prompt', 'asking_for', 'type', 'operands', 'operator']

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
    # Known synonyms for common fields
    synonyms = {
        'facts': ['assessmentItems', 'problems', 'questions', 'items'],
        'index': ['identifier', 'id', 'number', 'position'],
        'result': ['answer', 'correctAnswer', 'solution', 'correct_response'],
        'expression': ['question', 'problem', 'prompt', 'equation'],
        'id': ['cluster', 'identifier', 'level_id', 'track_id', 'code'],
        'title': ['name', 'label', 'description', 'heading'],
    }
    
    similar = []
    
    # First, check for exact synonym matches
    if target_key in synonyms:
        for synonym in synonyms[target_key]:
            if synonym in available_keys:
                similar.append((synonym, 0.95))  # High score for known synonyms
    
    # Then check for text similarity
    for key in available_keys:
        score = similarity(target_key, key)
        if score >= threshold:
            # Don't duplicate if already added as synonym
            if not any(k == key for k, _ in similar):
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

def map_fact(source_fact, field_mapping, optional_fields, level_context, skip_invalid=False, use_metadata=False, fact_index=None):
    """Map a single fact to the target format."""
    try:
        # If using metadata field, extract it as the source
        if use_metadata and 'metadata' in source_fact and isinstance(source_fact['metadata'], dict):
            fact_data = source_fact['metadata']
        else:
            fact_data = source_fact
        
        target_fact = {}
        missing_fields = []
        
        # First, handle index (to ensure it's first in order)
        index_mapped_key = field_mapping.get('index', 'index')
        if index_mapped_key is None:
            # Auto-generate from position as integer
            if fact_index is not None:
                target_fact['index'] = fact_index
            else:
                target_fact['index'] = 0  # Fallback
        elif index_mapped_key and index_mapped_key in fact_data:
            target_fact['index'] = fact_data[index_mapped_key]
        elif 'index' in fact_data:
            target_fact['index'] = fact_data['index']
        else:
            # Missing index, will be handled below
            missing_fields.append('index')
        
        # Second, add 'type' field for QTI format (to ensure it's second in order)
        if use_metadata and 'title' in source_fact:
            target_fact['type'] = source_fact['title']
        
        # Map remaining essential fields
        for essential_field in ESSENTIAL_FACT_FIELDS:
            if essential_field == 'index':
                continue  # Already handled
            
            mapped_key = field_mapping.get(essential_field, essential_field)
            
            # First try the mapped key
            if mapped_key and mapped_key in fact_data:
                target_fact[essential_field] = fact_data[mapped_key]
            # Fallback: try the essential field name itself (in case mapping is wrong for this specific fact)
            elif essential_field in fact_data:
                target_fact[essential_field] = fact_data[essential_field]
            else:
                # Essential field missing (unless it's auto-generated)
                if mapped_key is not None:  # Only report missing if not auto-generated
                    missing_fields.append(essential_field)
        
        # If there are missing fields, handle interactively or skip
        if missing_fields:
            if skip_invalid:
                # Just log and skip
                for field in missing_fields:
                    stats['warnings'].append(
                        f"Level '{level_context}' fact #{source_fact.get('index', '?')}: Missing essential field '{field}'"
                    )
                return None
            else:
                # Interactive resolution
                print(f"\n   {Colors.WARNING}⚠️  Problem with fact #{fact_data.get('index', '?')} in '{level_context}'{Colors.ENDC}")
                print(f"   Missing essential field(s): {', '.join(missing_fields)}")
                print(f"\n   {Colors.OKBLUE}Fact contents:{Colors.ENDC}")
                for key, value in fact_data.items():
                    value_str = str(value)
                    if len(value_str) > 70:
                        value_str = value_str[:67] + "..."
                    print(f"      • {key}: {value_str}")
                
                available_keys = list(fact_data.keys())
                
                # Try to map each missing field
                for missing_field in missing_fields:
                    mapped = prompt_user_for_field(missing_field, available_keys, f"fact #{fact_data.get('index', '?')}")
                    if mapped:
                        field_mapping[missing_field] = mapped
                        target_fact[missing_field] = fact_data[mapped]
                        stats['field_mappings'][f"fact.{missing_field}"] = mapped
                        print(f"   📝 {Colors.OKCYAN}This mapping will be applied to all future facts (with fallback to '{missing_field}' if available){Colors.ENDC}")
                    else:
                        # User chose to skip this field
                        while True:
                            response = input(f"\n   Skip this fact? (y/n): ").strip().lower()
                            if response in ['y', 'yes']:
                                stats['warnings'].append(
                                    f"Level '{level_context}' fact #{fact_data.get('index', '?')}: User skipped - missing '{missing_field}'"
                                )
                                return None
                            elif response in ['n', 'no']:
                                print(f"   {Colors.FAIL}Cannot proceed without '{missing_field}'. Aborting conversion.{Colors.ENDC}")
                                sys.exit(1)
                            else:
                                print(f"   {Colors.FAIL}Please enter 'y' or 'n'{Colors.ENDC}")
        
        # Map optional fields
        for opt_field in optional_fields:
            if opt_field in fact_data:
                target_fact[opt_field] = fact_data[opt_field]
            elif opt_field in field_mapping and field_mapping[opt_field] in fact_data:
                target_fact[opt_field] = fact_data[field_mapping[opt_field]]
        
        stats['facts_processed'] += 1
        return target_fact
        
    except Exception as e:
        if skip_invalid:
            stats['warnings'].append(
                f"Level '{level_context}' fact #{source_fact.get('index', '?')}: Error processing - {str(e)}"
            )
            return None
        else:
            print(f"\n   {Colors.FAIL}❌ Error processing fact #{source_fact.get('index', '?')}: {str(e)}{Colors.ENDC}")
            while True:
                response = input(f"\n   Skip this fact? (y/n): ").strip().lower()
                if response in ['y', 'yes']:
                    stats['warnings'].append(
                        f"Level '{level_context}' fact #{source_fact.get('index', '?')}: User skipped - error: {str(e)}"
                    )
                    return None
                elif response in ['n', 'no']:
                    print(f"   {Colors.FAIL}Cannot proceed. Aborting conversion.{Colors.ENDC}")
                    sys.exit(1)
                else:
                    print(f"   {Colors.FAIL}Please enter 'y' or 'n'{Colors.ENDC}")

def convert_json(input_data, include_all_optional=False, selective_mode=False, skip_invalid_facts=False):
    """Convert input JSON to target format."""
    print(f"\n{'='*60}")
    print(f"🚀 {Colors.HEADER}{Colors.BOLD}Starting Conversion Process{Colors.ENDC}")
    print(f"{'='*60}")
    
    if selective_mode:
        print(f"   🎯 {Colors.OKCYAN}Selective mode enabled - you'll review each level{Colors.ENDC}")
    
    if skip_invalid_facts:
        print(f"   ⏭️  {Colors.WARNING}Skip mode enabled - facts with missing fields will be skipped{Colors.ENDC}")
    else:
        print(f"   🛠️  {Colors.OKGREEN}Interactive mode - you'll resolve any missing fields{Colors.ENDC}")
    
    # Step 1: Find the levels/tracks container
    print(f"\n📦 {Colors.OKBLUE}Step 1: Identifying levels container...{Colors.ENDC}")
    
    # Check for QTI format (single level with assessmentItems at root)
    is_qti_format = False
    if 'assessmentItems' in input_data and isinstance(input_data['assessmentItems'], list):
        # Check if this looks like a QTI file (has typical QTI root fields)
        qti_indicators = ['cluster', 'domain', 'grade', 'standards', 'title']
        matching_indicators = sum(1 for indicator in qti_indicators if indicator in input_data)
        
        if matching_indicators >= 3:  # If at least 3 indicators match
            print(f"   🔍 {Colors.OKCYAN}Detected QTI format (single level with assessmentItems){Colors.ENDC}")
            print(f"   📦 Will treat root as level container, assessmentItems as facts")
            is_qti_format = True
            
            # Wrap the root data as a single level in an array
            levels_array = [input_data]
            print(f"   📊 Found 1 level with {len(input_data['assessmentItems'])} assessment items")
    
    if not is_qti_format:
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
    
    # Step 1.5: Check if we need to flatten nested tracks structure (skip for QTI format)
    if not is_qti_format:
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
    
    # Step 1.6: Selective mode - let user choose which levels to include BEFORE field mapping
    selected_levels = []
    if selective_mode:
        print(f"\n🎯 {Colors.OKBLUE}Step 1.6: Selecting levels to include...{Colors.ENDC}")
        print(f"   You'll review each level and decide whether to include it.\n")
        
        for i, level in enumerate(levels_array, 1):
            # Try to find ID and title fields (they might have different names)
            level_id = level.get('id', level.get('level_id', level.get('track_id', f'Level {i}')))
            level_title = level.get('title', level.get('name', level.get('track_name', 'Untitled')))
            
            print(f"{'─'*60}")
            print(f"📋 {Colors.BOLD}Level {i}/{len(levels_array)}: {Colors.OKCYAN}{level_id}{Colors.ENDC}")
            print(f"   Title: {level_title}")
            print(f"{'─'*60}")
            
            # Show all level fields
            print(f"\n   {Colors.OKBLUE}Level Fields:{Colors.ENDC}")
            facts_keys = ['facts', 'problems', 'questions', 'items', 'assessmentItems']  # Common names for facts arrays
            facts_key_found = None
            
            for key, value in level.items():
                if key in facts_keys and isinstance(value, list):
                    facts_key_found = key
                    print(f"      • {key}: [{len(value)} items]")
                else:
                    value_preview = str(value)
                    if len(value_preview) > 60:
                        value_preview = value_preview[:57] + "..."
                    print(f"      • {key}: {value_preview}")
            
            # Show first fact if available
            if facts_key_found and level[facts_key_found]:
                first_fact = level[facts_key_found][0]
                
                # Check if facts use metadata field (QTI format)
                fact_display = first_fact
                if 'metadata' in first_fact and isinstance(first_fact['metadata'], dict):
                    print(f"\n   {Colors.OKCYAN}Note: Facts have 'metadata' field (QTI format) - showing metadata contents{Colors.ENDC}")
                    fact_display = first_fact['metadata']
                
                print(f"\n   {Colors.OKBLUE}Fact Fields (from first fact):{Colors.ENDC}")
                for key in fact_display.keys():
                    print(f"      • {key}")
                
                print(f"\n   {Colors.OKBLUE}First Fact Example:{Colors.ENDC}")
                for key, value in fact_display.items():
                    value_str = str(value)
                    if len(value_str) > 70:
                        value_str = value_str[:67] + "..."
                    print(f"      • {key}: {value_str}")
            else:
                print(f"\n   {Colors.WARNING}⚠️  No facts found in this level{Colors.ENDC}")
            
            # Ask for approval
            while True:
                response = input(f"\n   Include this level? (y/n/q to quit): ").strip().lower()
                if response in ['y', 'yes']:
                    print(f"   ✅ Including level '{level_id}'")
                    selected_levels.append(level)
                    break
                elif response in ['n', 'no']:
                    print(f"   ⏭️  Skipping level '{level_id}'")
                    break
                elif response in ['q', 'quit']:
                    print(f"\n   {Colors.WARNING}🛑 Level selection cancelled by user{Colors.ENDC}")
                    if selected_levels:
                        print(f"   📊 {len(selected_levels)} level(s) selected before cancellation")
                        break
                    else:
                        print(f"   ❌ No levels selected. Aborting.")
                        return None
                else:
                    print(f"   {Colors.FAIL}Please enter 'y', 'n', or 'q'{Colors.ENDC}")
            
            # Check if user quit
            if response in ['q', 'quit']:
                break
        
        if not selected_levels:
            print(f"\n   {Colors.FAIL}❌ No levels selected. Aborting.{Colors.ENDC}")
            return None
        
        levels_array = selected_levels
        print(f"\n   ✅ {Colors.OKGREEN}Selected {len(levels_array)} level(s) to process{Colors.ENDC}")
    
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
    
    # Check if facts are nested under a 'metadata' field (common in QTI format)
    use_metadata_field = False
    if 'metadata' in sample_fact and isinstance(sample_fact['metadata'], dict):
        print(f"   🔍 {Colors.OKCYAN}Detected 'metadata' field in facts (QTI format){Colors.ENDC}")
        print(f"   📦 Will extract fact data from 'metadata' field")
        use_metadata_field = True
        # Use metadata as the source for field mapping
        available_fact_keys = list(sample_fact['metadata'].keys())
    else:
        available_fact_keys = list(sample_fact.keys())
    print(f"   Available fields: {', '.join(available_fact_keys)}")
    
    # Map fact fields
    fact_field_mapping = {}
    for essential_field in ESSENTIAL_FACT_FIELDS:
        if essential_field == 'index':
            # Index is special - can be auto-generated from position
            if 'index' in available_fact_keys:
                fact_field_mapping['index'] = 'index'
                print(f"   ✅ 'index' found")
            else:
                print(f"   ⚠️  'index' not found - will auto-generate from position")
                fact_field_mapping['index'] = None
        elif essential_field == 'operator':
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
        level_id = source_level.get(level_field_mapping.get('id', 'id'), f'Level {i}')
        level_title = source_level.get(level_field_mapping.get('title', 'title'), f'Level {i}')
        
        print(f"\n   Processing level {i}/{len(levels_array)} ({level_id})...", end=' ')
        
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
        
        for fact_idx, source_fact in enumerate(source_facts):
            mapped_fact = map_fact(source_fact, fact_field_mapping, optional_fact_fields, level_title, skip_invalid_facts, use_metadata_field, fact_idx)
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
        print(f"{Colors.FAIL}❌ Usage: python3 insert_data.py [input_file] [output_file] [options]{Colors.ENDC}")
        print(f"\nOptions:")
        print(f"  --include-all          Include all optional fields without prompting")
        print(f"  --wipe-output-file     Replace existing output file instead of merging")
        print(f"  --selective            Review and approve each level individually")
        print(f"  --skip-invalid-facts   Skip facts with missing fields (default: interactive resolution)")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    include_all = '--include-all' in sys.argv or '--include_all' in sys.argv
    wipe_output = '--wipe-output-file' in sys.argv or '--wipe_output_file' in sys.argv
    selective_mode = '--selective' in sys.argv
    skip_invalid_facts = '--skip-invalid-facts' in sys.argv
    
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
    output_data = convert_json(input_data, include_all, selective_mode, skip_invalid_facts)
    
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
