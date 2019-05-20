-- Rupesh Jeyaram 
-- Created April 21st, 2019

SET GLOBAL log_bin_trust_function_creators = 1;

DROP TABLE IF EXISTS entry_pool; 
DROP TABLE IF EXISTS traverser; 
DROP TABLE IF EXISTS path_to_leaf;

DROP PROCEDURE IF EXISTS rtree_insert; 
DROP PROCEDURE IF EXISTS insert_leaf_entry; 
DROP PROCEDURE IF EXISTS update_MBR;
DROP FUNCTION IF EXISTS distance; 
DROP FUNCTION IF EXISTS area_increment; 

CREATE TABLE entry_pool (entry_id INTEGER NOT NULL); 

-- Use this table to store the path taken to a certain leaf node on entry. 
-- This way, you can retrace steps and update the appropriate MBRs
CREATE TABLE path_to_leaf (level INTEGER PRIMARY KEY, node_id INTEGER NOT NULL, entry_id INTEGER NOT NULL);

-- Use this table to get all entries at a given level 
CREATE TABLE traverser LIKE inner_node_entries; 
-- Column to indicate the increment of area needed to cover the current entry
ALTER TABLE traverser ADD COLUMN area_increment NUMERIC(10, 5) AFTER node_id; 

DELIMITER !

-- Function to compute the distance between two entries. 

CREATE FUNCTION distance 
(
    e1 INTEGER,     -- entry id in entry_geom
    e2 INTEGER      -- another entry id in entry_geom
)

RETURNS NUMERIC(10, 7)

BEGIN
    DECLARE dist NUMERIC(10, 5); 

    DECLARE lat1, lat2, lon1, lon2 NUMERIC(10,3); 

    SELECT center_lat, center_lon FROM entry_geom WHERE entry_id = e1 
    INTO lat1, lon1; 

    SELECT center_lat, center_lon FROM entry_geom WHERE entry_id = e2 
    INTO lat2, lon2; 
    
    RETURN sqrt(pow(lat1 - lat2, 2) + pow(lon1 - lon2, 2)); 
END !

-- Compute the increment in area needed to capture a new rectangle from an 
-- existing rectangle

CREATE FUNCTION area_increment (
    entry_id_large INTEGER,
    x1 NUMERIC(10, 7), 
    y1 NUMERIC(10, 7), 
    x2 NUMERIC(10, 7), 
    y2 NUMERIC(10, 7)
)

RETURNS NUMERIC(10, 5)

BEGIN

    DECLARE original_area, new_area NUMERIC(10,5) DEFAULT 0;

    DECLARE tlc_lat, tlc_lon, brc_lat, brc_lon NUMERIC(10,3); 
    
    SELECT mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon
    FROM entry_geom
    WHERE entry_id = entry_id_large
    INTO tlc_lat, tlc_lon, brc_lat, brc_lon;
    
    SET original_area = (tlc_lat - brc_lat) * (brc_lon - tlc_lon);
    
    SET tlc_lat = GREATEST(tlc_lat, y1),
            tlc_lon = LEAST(tlc_lon, x1), 
            brc_lat = LEAST(brc_lat, y2), 
            brc_lon = GREATEST(brc_lon, x2);
            
    SET new_area = (tlc_lat - brc_lat) * (brc_lon - tlc_lon); 

    RETURN new_area - original_area; 

END !

-- Function to update the values in entry_geom given the parent entry 

CREATE PROCEDURE update_MBR (curr_entry_id INTEGER)

BEGIN 

    DECLARE curr_level, child, parent INTEGER;
    DECLARE new_tlc_lat, new_tlc_lon, new_brc_lat, new_brc_lon NUMERIC(10,3); 
    
    SELECT child_node_id, level, node_id FROM inner_node_entries WHERE entry_id = curr_entry_id
    INTO child, curr_level, parent ;
    
    -- UPDATE rtree_properties SET a = curr_entry_id, b = child, c = parent; 

    -- SET curr_level = 1-- (SELECT level FROM inner_node_entries WHERE entry_id = curr_entry_id);
    -- SET child = (SELECT child_node_id FROM inner_node_entries WHERE entry_id = curr_entry_id);
    
    SELECT MAX(mbr_tlc_lat) , MIN(mbr_tlc_lon), MIN(mbr_brc_lat), MAX(mbr_brc_lon)
    FROM entry_geom 
    WHERE entry_id IN 
        (SELECT entry_id FROM leaf_node_entries WHERE level = 1 AND node_id = child)
    INTO new_tlc_lat, new_tlc_lon, new_brc_lat, new_brc_lon; 

    UPDATE entry_geom 
    SET mbr_tlc_lat = new_tlc_lat, mbr_tlc_lon = new_tlc_lon, 
            mbr_brc_lat = new_brc_lat, mbr_brc_lon = new_brc_lon
    WHERE entry_id = curr_entry_id; 

END ! 

-- The actual meat of this script. 
-- Should insert a data point into the tree structure

CREATE PROCEDURE rtree_insert 
(
    date                  DATETIME, 
    SIF                   NUMERIC(10, 2), 
    
    new_mbr_tlc_lat       NUMERIC(10, 7), 
    new_mbr_tlc_lon      NUMERIC(10, 7), 
    new_mbr_brc_lat      NUMERIC(10, 7), 
    new_mbr_brc_lon     NUMERIC(10, 7)
)

BEGIN
    
    -- load properties
    DECLARE depth INTEGER DEFAULT (SELECT depth FROM rtree_properties);
    DECLARE max_entries INTEGER DEFAULT (SELECT max_entries FROM rtree_properties);
    
    DECLARE curr_level, curr_node, curr_entry_node, m_nodes, max_inner INTEGER DEFAULT 0; 

    DECLARE e1, e2, e_curr, max_dist, curr_entry, splitting_node_id, splitting_entry_id INTEGER DEFAULT 0; 
    
    DECLARE x1, y1, x2, y2 NUMERIC(10, 7); 
    
    DECLARE increment_1, increment_2 NUMERIC(10, 5) DEFAULT 0; 
    
    SET UNIQUE_CHECKS = 0;
    SET FOREIGN_KEY_CHECKS = 0;
    
    -- First insert the record into tropomi
    INSERT INTO tropomi VALUES (NULL, date, SIF); 
    
    -- Find curr_level and curr_node (where to insert current leaf entry into)
    -- While we haven't reached the bottom-most level, 
    
    WHILE ((SELECT curr_level) <> depth) DO
    
        -- Get all the entries at the current level and current node, and the 
        -- incremental area required to hold the current leaf entry
        INSERT INTO traverser 
            (SELECT *, area_increment(entry_id, new_mbr_tlc_lon, new_mbr_tlc_lat, new_mbr_brc_lon, new_mbr_brc_lat) 
         FROM inner_node_entries WHERE level = curr_level AND node_id = curr_node); 
         
         -- Mark which node we are coming from
        SET curr_entry_node = curr_node;
        
        -- And determine the best entry for this value to go into
        SET curr_node = (
            SELECT child_node_id 
            FROM traverser NATURAL LEFT JOIN entry_geom 
            WHERE area_increment = 
                (SELECT MIN(area_increment) FROM traverser) 
            ORDER BY area DESC  -- In case of ties, take the minimum area
            LIMIT 1
        );
        
        -- And reflect it in the path_to_leaf table
        -- Nothing inserted is a valid option. 
        -- INSERT INTO path_to_leaf VALUES (curr_level, curr_node, (SELECT entry_id FROM inner_node_entries WHERE level = curr_level AND child_node_id = curr_entry_node));
        -- Update current level 
        SET curr_level = curr_level + 1; 
        
        -- Clear the traverser
        DELETE FROM traverser; 
        
    END WHILE;
    
    DELETE FROM traverser; 

    -- ---------------------------------------------
    -- Case that we still have room in leaf
    -- ---------------------------------------------

    IF (SELECT num_entries FROM nodes WHERE level = curr_level AND node_id = curr_node) < max_entries THEN

        -- Insert this into leaf
        INSERT INTO rtree_entries VALUES (NULL);
        
        -- Insert new leaf_node entry
        INSERT INTO leaf_node_entries VALUES (
            (SELECT MAX(entry_id) FROM rtree_entries),  -- entry_id
            (SELECT MAX(tropomi_id) FROM tropomi),      -- tropomi_id
            curr_level,                                                           -- level
            curr_node                                                           -- node
        ); 
            
        -- Insert into entry_geom
        INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
            VALUES (
                (SELECT MAX(entry_id) FROM rtree_entries),  -- entry_id
                new_mbr_tlc_lat, new_mbr_tlc_lon,
                new_mbr_brc_lat, new_mbr_brc_lon
        ); 
            
        -- Increment num entries in nodes
        UPDATE nodes 
        SET num_entries = num_entries + 1
        WHERE level = curr_level AND node_id = curr_node; 

        -- Only need to update the lowest inner node
        -- SET max_inner = (SELECT MAX(level) FROM path_to_leaf);
        -- DELETE FROM path_to_leaf WHERE level < max_inner; 
        -- CALL update_MBRs();

        IF curr_level <> 0 THEN 
            CALL update_MBR(
                (SELECT entry_id FROM 
                    (SELECT * 
                     FROM entry_geom NATURAL JOIN inner_node_entries) AS t1 
                    WHERE level = 0 AND child_node_id = curr_node)
            );
        -- CALL update_MBR((SELECT entry_id FROM leaf_node_entries AS t1 WHERE level = 0 AND node_id = 0));
            
        END IF;

        

    ELSE 
    
        -- Two special nodes that I use as intermediates
        INSERT INTO nodes VALUES (-1, 0, 0), (-1, 1, 0);

        -- Insert the entry that is being added (will split after)
        -- ------------------------------------------------------ 
        INSERT INTO rtree_entries VALUES (NULL);
        
        -- Insert new leaf_node entry
        INSERT INTO leaf_node_entries VALUES (
            (SELECT MAX(entry_id) FROM rtree_entries),  -- entry_id
            (SELECT MAX(tropomi_id) FROM tropomi),      -- tropomi_id
            curr_level,                                 -- level
            curr_node                                   -- node
        ); 
    
        -- Insert into entry_geom
        INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
        VALUES (
            (SELECT MAX(entry_id) FROM rtree_entries),  -- entry_id
            new_mbr_tlc_lat, new_mbr_tlc_lon,
            new_mbr_brc_lat, new_mbr_brc_lon
        ); 
        -- ------------------------------------------------------

        -- The entries in the node being split
        INSERT INTO entry_pool SELECT entry_id FROM leaf_node_entries WHERE level = curr_level AND node_id = curr_node;
        
        -- UPDATE rtree_properties SET d = (SELECT COUNT(*) FROM entry_pool);
        
        -- Find two farthest away points among first 30 entries in root
        WITH ep1 AS (SELECT * FROM entry_pool), ep2 AS (SELECT * FROM entry_pool)
        SELECT ep1.entry_id, ep2.entry_id, distance(ep1.entry_id, ep2.entry_id) AS dist 
        FROM ep1 CROSS JOIN ep2 WHERE ep1.entry_id <> ep2.entry_id ORDER BY dist DESC LIMIT 1
        INTO e1, e2, max_dist;
        
        -- insert these into leaf node entries
        INSERT INTO leaf_node_entries VALUES
            (e1, (SELECT tropomi_id FROM (SELECT * FROM leaf_node_entries) AS lne1 WHERE entry_id = e1 LIMIT 1), -1, 0),
            (e2, (SELECT tropomi_id FROM (SELECT * FROM leaf_node_entries) AS lne2 WHERE entry_id = e2 LIMIT 1), -1, 1); 
        
        -- Insert two farthest into entry_geom
        INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
            SELECT -1, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon FROM entry_geom WHERE entry_id = e1; 
        INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
            SELECT -2, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon FROM entry_geom WHERE entry_id = e2;  
        
        -- Increment num entries in nodes
        UPDATE nodes SET num_entries = num_entries + 1 WHERE level = -1 AND (node_id = 1 OR node_id = 0); 
        
        -- Remove two farthest from entry pool 
        DELETE FROM entry_pool WHERE entry_id = e1 OR entry_id = e2; 
        
        -- While there are still remaining elements in the pool
        WHILE (SELECT COUNT(*) FROM entry_pool ) > 0 DO
            
            -- Load in the current entry_id
            SELECT entry_id FROM entry_pool LIMIT 1 INTO curr_entry;
            
            -- Get the bounding coordinates of this new entry
            SELECT mbr_tlc_lon, mbr_tlc_lat, mbr_brc_lon, mbr_brc_lat
                FROM entry_geom WHERE entry_id = curr_entry
                INTO x1, y1, x2, y2;
            
            -- Get increments necessary to encapsulate these two points
            SET increment_1 = area_increment(-1, x1, y1, x2, y2);
            SET increment_2 = area_increment(-2, x1, y1, x2, y2);
            
            -- Case that increment 2 encapsulates in a smaller increment
            IF increment_1 > increment_2 THEN 
                SET splitting_node_id = 1; 
                SET splitting_entry_id = -2; 
            ELSE 
                SET splitting_node_id = 0;
                SET splitting_entry_id = -1;
            END IF;

            -- insert value into appropriate leaf_node entries
            INSERT INTO leaf_node_entries VALUES 
            (curr_entry, 
                (SELECT tropomi_id 
                 FROM (SELECT * FROM leaf_node_entries) AS lne1 
                 WHERE entry_id = curr_entry LIMIT 1), 
            -1, splitting_node_id); 
            
            -- update the entry_geom value of the second node 
            UPDATE entry_geom SET 
                mbr_tlc_lat = GREATEST(mbr_tlc_lat, y1),
                mbr_tlc_lon = LEAST(mbr_tlc_lon, x1), 
                mbr_brc_lat = LEAST(mbr_brc_lat, y2), 
                mbr_brc_lon = GREATEST(mbr_brc_lon, x2)
            WHERE entry_id = splitting_entry_id; 
            
            -- Increment count of entries in nodes
            UPDATE nodes SET num_entries = num_entries + 1 WHERE level = -1 AND node_id = splitting_node_id; 

            -- Delete the value from entry pool 
            DELETE FROM entry_pool WHERE entry_id = curr_entry;
        
        END WHILE;

        IF depth = 0 THEN 
            -- Remove actual root
            DELETE FROM nodes WHERE level = 0; 
            
            -- Increment each node's level 
            UPDATE nodes SET level = level + 1 WHERE level = -1; 
            UPDATE nodes SET level = level + 1; 

            -- Insert new root node, with two entries
            INSERT INTO nodes VALUES (0, 0, 2); 
            
            -- Insert two leaf nodes as entries into root node
            INSERT INTO rtree_entries VALUES (NULL); 
            INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), 1, 0, 0);
            INSERT INTO rtree_entries VALUES (NULL); 
            INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), 0, 0, 0);
            
            -- Update all the leaf node entries
            DELETE FROM leaf_node_entries WHERE level = 0; 
            
            -- Should be level + 1, because we're now at level 1
            UPDATE leaf_node_entries SET level = level + 2 WHERE level = -1; 
            
            -- Update all the entry geoms
            UPDATE entry_geom SET entry_id = entry_id + 1 + (SELECT MAX(entry_id) FROM rtree_entries) WHERE entry_id < 0; 
            
            -- Increment the depth of the tree
            UPDATE rtree_properties SET depth = depth + 1; 

            -- CALL update_MBR((SELECT entry_id FROM entry_geom NATURAL JOIN inner_node_entries WHERE level = 0 AND node_id = 0));

        ELSE 

            -- Maximum entries in node 
            SET m_nodes = (SELECT MAX(node_id) FROM nodes WHERE level = curr_level);

            -- Remove overflowing node
            DELETE FROM nodes WHERE level = curr_level AND node_id = curr_node; 
            -- DELETE FROM inner_node_entries WHERE level = curr_level-1 AND child_node_id = curr_node;
            DELETE FROM leaf_node_entries WHERE level = curr_level AND node_id = curr_node;
            
            UPDATE nodes SET level = curr_level, node_id = curr_node WHERE level = -1 AND node_id = 0; 
            UPDATE nodes SET level = curr_level, node_id = m_nodes + 1 WHERE level = -1 AND node_id = 1; 
            
            -- Insert two leaf nodes as entries into inner node
            INSERT INTO rtree_entries VALUES (NULL); 
            INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), m_nodes + 1, curr_level-1, curr_entry_node);
            
            -- Should be level + 1, because we're now at level 1
            -- These should update on cascade of nodes... Maybe... 
            UPDATE leaf_node_entries SET level = curr_level, node_id = curr_node WHERE level = -1 AND node_id = 0; 
            UPDATE leaf_node_entries SET level = curr_level, node_id = m_nodes + 1 WHERE level = -1 AND node_id = 1; 
            
            SET m_nodes = (SELECT (entry_id) FROM inner_node_entries WHERE level = curr_level-1 AND child_node_id = curr_node);
            
            DELETE FROM entry_geom WHERE entry_id = m_nodes;
            
            -- -- Update all the entry geoms
            UPDATE entry_geom SET entry_id = m_nodes WHERE entry_id = -1; 
            
            SET m_nodes = (SELECT MAX(entry_id) FROM entry_geom);
            
            UPDATE entry_geom SET entry_id = m_nodes+1 WHERE entry_id = -2; 
            
            -- -- Update number of entries in nodes table
            UPDATE nodes SET num_entries = num_entries + 1 
            WHERE level = curr_level-1 AND node_id = curr_entry_node; 

            -- UPDATE rtree_properties SET a = curr_level-1; 
--             UPDATE rtree_properties SET b = curr_node;

            -- CALL update_MBR((SELECT entry_id FROM entry_geom NATURAL JOIN inner_node_entries WHERE level = 0 AND child_node_id = curr_entry_node));
            -- CALL update_MBR(
            --     (SELECT entry_id FROM 
            --         (SELECT * 
            --          FROM entry_geom NATURAL JOIN inner_node_entries) AS t1 
            --         WHERE level = 0 AND (child_node_id = curr_entry_node))
            -- );

        END IF;

        -- CALL update_MBRs();

    END IF; 

    --
    
    
    SET UNIQUE_CHECKS=1; 
    SET FOREIGN_KEY_CHECKS=1;

END ! 

DELIMITER ; 
