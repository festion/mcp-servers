#!/usr/bin/env python3
"""
Simple duplicate entity scanner
Identifies numbered duplicate entities in Home Assistant
"""
import json
import sqlite3
import sys
from pathlib import Path

def scan_duplicates():
    db_path = "/config/home-assistant_v2.db"
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Query for numbered entities
        cursor.execute("""
            SELECT entity_id 
            FROM states_meta 
            WHERE entity_id REGEXP '.*_[0-9]+$'
            ORDER BY entity_id
        """)
        
        numbered_entities = [row[0] for row in cursor.fetchall()]
        
        # Find base entities that have numbered duplicates
        duplicate_groups = {}
        for entity in numbered_entities:
            parts = entity.split('_')
            if parts[-1].isdigit():
                base_name = '_'.join(parts[:-1])
                
                # Check if base entity exists
                cursor.execute("SELECT entity_id FROM states_meta WHERE entity_id = ?", (base_name,))
                if cursor.fetchone():
                    if base_name not in duplicate_groups:
                        duplicate_groups[base_name] = []
                    duplicate_groups[base_name].append(entity)
        
        conn.close()
        
        print(f"Found {len(duplicate_groups)} duplicate groups:")
        for base, duplicates in duplicate_groups.items():
            print(f"  {base}: {', '.join(duplicates)}")
        
        return duplicate_groups
        
    except Exception as e:
        print(f"Error scanning duplicates: {e}")
        return {}

if __name__ == "__main__":
    scan_duplicates()
