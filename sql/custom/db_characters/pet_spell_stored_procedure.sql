-- Pet Spell Duplicate Prevention Fix
-- This stored procedure provides an upsert operation for pet_spell
-- to prevent duplicate key errors during concurrent pet spell updates
--
-- USAGE: Call this instead of raw INSERT statements:
--   CALL sp_safe_insert_pet_spell(guid_value, spell_value, active_value);
--
-- MAINTENANCE: This file will be automatically applied on database initialization
-- For existing databases, apply manually or during next maintenance window

USE acore_characters;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_safe_insert_pet_spell$$

CREATE PROCEDURE sp_safe_insert_pet_spell(
    IN p_guid INT UNSIGNED,
    IN p_spell INT UNSIGNED,
    IN p_active TINYINT UNSIGNED
)
BEGIN
    -- Use INSERT ... ON DUPLICATE KEY UPDATE to handle race conditions
    -- If the (guid, spell) pair already exists, just update the active flag
    INSERT INTO pet_spell (guid, spell, active) 
    VALUES (p_guid, p_spell, p_active)
    ON DUPLICATE KEY UPDATE 
        active = VALUES(active);
END$$

DELIMITER ;
