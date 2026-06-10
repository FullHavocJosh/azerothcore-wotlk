# Custom Database Procedures

## Pet Spell Stored Procedure

**File**: pet_spell_stored_procedure.sql

**Purpose**: Prevents duplicate key errors when inserting pet spells by using upsert logic.

### Problem Statement

AzerothCore C++ code performs raw INSERTs into the pet_spell table.
When multiple threads try to insert the same (guid, spell) pair simultaneously, MySQL raises duplicate entry errors.

### Solution

The stored procedure sp_safe_insert_pet_spell uses INSERT ... ON DUPLICATE KEY UPDATE syntax.

### Current Status

- Stored Procedure: Created in production database (Feb 6, 2026 at 4:26 PM)
- AzerothCore Patch: Not yet applied (requires C++ source modification)
- Persistence: SQL file will be applied on fresh database initialization

### Testing

Successfully tested insert and update operations without errors.

### Maintenance

Apply to existing database:
  docker exec -i ac-database mysql -uroot -ppassword < /root/azerothcore-wotlk/sql/custom/db_characters/pet_spell_stored_procedure.sql

Verify it exists:
  docker exec ac-database mysql -uroot -ppassword -e "SHOW PROCEDURE STATUS WHERE Db = 'acore_characters' AND Name = 'sp_safe_insert_pet_spell';"

### Impact Assessment

- Risk: Low (procedure exists but is not called)
- Performance: Minimal overhead
- Compatibility: High (no source code changes yet)
- Reversibility: High (can drop procedure anytime)
