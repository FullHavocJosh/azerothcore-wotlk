# Patching AzerothCore to Use Stored Procedures

## Overview

This document describes how to modify AzerothCore C++ source code to use the sp_safe_insert_pet_spell stored procedure instead of raw INSERT statements.

## Important Notes

- This is a FUTURE enhancement - the stored procedure currently exists but is not being called
- Modifying source code will create merge conflicts with upstream AzerothCore updates
- Consider this approach only if pet_spell errors become severe enough to warrant the maintenance burden

## Option 1: Patch C++ Source (Recommended for Long-Term)

### Step 1: Identify the Code Location

The pet spell insertion happens in the Pet class. Likely locations:

1. src/server/game/Entities/Pet/Pet.cpp - Pet::addSpell() function
2. src/server/game/Handlers/PetHandler.cpp - Pet spell handlers
3. Check for: INSERT INTO pet_spell

### Step 2: Find the Exact Code

Search for the INSERT statement:
  cd /root/azerothcore-wotlk
  grep -r "INSERT INTO pet_spell" src/

### Step 3: Modify the Code

Replace INSERT statements with CALL statements:

BEFORE:
  CharacterDatabase.Execute("INSERT INTO pet_spell (guid, spell, active) VALUES ({}, {}, {})",
      petNumber, spellId, activeFlag);

AFTER:
  CharacterDatabase.Execute("CALL sp_safe_insert_pet_spell({}, {}, {})",
      petNumber, spellId, activeFlag);

### Step 4: Rebuild AzerothCore

  cd /root/azerothcore-wotlk
  docker compose down
  docker compose build --no-cache ac-worldserver
  docker compose up -d

### Step 5: Test

Monitor error logs for pet_spell duplicate errors - they should disappear.

## Option 2: Use INSERT ... ON DUPLICATE KEY UPDATE in C++ (Alternative)

Instead of calling stored procedure, modify C++ to use upsert directly:

BEFORE:
  CharacterDatabase.Execute("INSERT INTO pet_spell (guid, spell, active) VALUES ({}, {}, {})",
      petNumber, spellId, activeFlag);

AFTER:
  CharacterDatabase.Execute(
      "INSERT INTO pet_spell (guid, spell, active) VALUES ({}, {}, {}) "
      "ON DUPLICATE KEY UPDATE active = VALUES(active)",
      petNumber, spellId, activeFlag);

This approach:
- Does not require stored procedures
- Avoids GRANT permission issues
- Still requires C++ source modification
- May be easier to maintain

## Option 3: Wait for Upstream Fix (Safest)

Report the issue to AzerothCore:
- GitHub: https://github.com/azerothcore/azerothcore-wotlk
- Create an issue describing the duplicate entry errors
- Link to this documentation
- Wait for official fix in upstream repository

## Testing the Patch

After applying any patch:

1. Monitor error logs:
     docker exec ac-worldserver tail -f /azerothcore/env/dist/logs/Errors.log | grep pet_spell

2. Check for crashes:
     docker ps --filter name=worldserver
     docker inspect ac-worldserver --format '{{.RestartCount}}'

3. Verify stored procedure is being called (if using Option 1):
     docker exec ac-database mysql -uroot -ppassword -e "SHOW PROCEDURE STATUS WHERE Name = 'sp_safe_insert_pet_spell';"

## Rollback Plan

If the patch causes issues:

1. Revert C++ changes:
     cd /root/azerothcore-wotlk
     git checkout src/

2. Rebuild:
     docker compose build --no-cache ac-worldserver
     docker compose up -d

3. Optional: Remove stored procedure:
     docker exec ac-database mysql -uroot -ppassword acore_characters -e "DROP PROCEDURE IF EXISTS sp_safe_insert_pet_spell;"

## Maintenance Strategy

Recommendation: Do NOT patch C++ source unless absolutely necessary

Reasons:
- Current error rate is low (2 errors in 13 minutes post-restart)
- Errors do not always cause crashes
- Source modifications complicate upstream merges
- Stored procedure is ready if needed in the future

Alternative: Monitor and restart when necessary
- Current uptime was 8 hours before crash
- Automatic restart recovery works well
- Consider this acceptable for now

## Related Documentation

- Custom SQL procedures: /root/azerothcore-wotlk/sql/custom/db_characters/README.md
- Stored procedure file: /root/azerothcore-wotlk/sql/custom/db_characters/pet_spell_stored_procedure.sql
- Production context: /Users/havoc/aicontexts/azerothcore/.opencode/context.md
