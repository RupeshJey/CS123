-- Rupesh Jeyaram 
-- Created April 21st, 2019

SET GLOBAL log_bin_trust_function_creators = 1;

DROP TABLE IF EXISTS entry_pool; 
DROP TABLE IF EXISTS traverser; 

DROP TABLE IF EXISTS stack; 
DROP PROCEDURE IF EXISTS graham_scan; 
DROP PROCEDURE IF EXISTS push; 
DROP PROCEDURE IF EXISTS pop; 
DROP FUNCTION IF EXISTS top; 
DROP FUNCTION IF EXISTS next_to_top; 
DROP FUNCTION IF EXISTS polar_angle; 
DROP FUNCTION IF EXISTS ccw; 

DROP PROCEDURE IF EXISTS rtree_insert; 
DROP PROCEDURE IF EXISTS split_node; 
DROP PROCEDURE IF EXISTS insert_leaf_entry; 
DROP PROCEDURE IF EXISTS update_MBR;
DROP FUNCTION IF EXISTS distance; 
DROP FUNCTION IF EXISTS area_increment; 

-- Use this table to unify all the entries that should be considered
-- when splitting an overflowing node. 
CREATE TABLE entry_pool (entry_id INTEGER NOT NULL); 
CREATE TABLE stack 
(
    stack_pos INTEGER AUTO_INCREMENT, 
    entry_id INTEGER NOT NULL, 
    PRIMARY KEY (stack_pos)
);

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
    
    SELECT mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon, area
    FROM entry_geom
    WHERE entry_id = entry_id_large
    INTO tlc_lat, tlc_lon, brc_lat, brc_lon, original_area;
    
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

    DECLARE depth INTEGER DEFAULT (SELECT depth FROM rtree_properties);

    DECLARE max_entries INTEGER DEFAULT (SELECT max_entries FROM rtree_properties);
    DECLARE curr_level, child, parent INTEGER;
    DECLARE new_tlc_lat, new_tlc_lon, new_brc_lat, new_brc_lon NUMERIC(10,3);

    SET max_sp_recursion_depth = 10; 
    
    SELECT child_node_id, level, node_id FROM inner_node_entries WHERE entry_id = curr_entry_id
    INTO child, curr_level, parent ;
    
    IF (curr_level + 1 = depth) THEN 
        SELECT MAX(mbr_tlc_lat) , MIN(mbr_tlc_lon), MIN(mbr_brc_lat), MAX(mbr_brc_lon)
        FROM entry_geom 
        WHERE entry_id IN 
            (SELECT entry_id FROM leaf_node_entries WHERE level = curr_level + 1 AND node_id = child)
        INTO new_tlc_lat, new_tlc_lon, new_brc_lat, new_brc_lon; 
    ELSE 
        SELECT MAX(mbr_tlc_lat) , MIN(mbr_tlc_lon), MIN(mbr_brc_lat), MAX(mbr_brc_lon)
        FROM entry_geom 
        WHERE entry_id IN 
            (SELECT entry_id FROM inner_node_entries WHERE level = curr_level + 1 AND node_id = child)
        INTO new_tlc_lat, new_tlc_lon, new_brc_lat, new_brc_lon; 
    END IF; 

    UPDATE entry_geom 
    SET mbr_tlc_lat = new_tlc_lat, mbr_tlc_lon = new_tlc_lon, 
            mbr_brc_lat = new_brc_lat, mbr_brc_lon = new_brc_lon
    WHERE entry_id = curr_entry_id; 

    -- If the node we came from has exceeded the capacity, split it

    IF (SELECT num_entries FROM nodes WHERE level = curr_level AND node_id = parent) > max_entries THEN 
        CALL split_node(curr_level, parent);
    END IF;

    -- Just traverse up the tree and update MBRs

    IF curr_level > 0 THEN 
        CALL update_MBR((SELECT entry_id FROM inner_node_entries WHERE level = curr_level - 1 AND child_node_id = parent));
    END IF;

END ! 

-- Find the convex hull of entry_pool so that the two farthest points 
-- can be computed more efficiently. 

CREATE PROCEDURE push (entry_id INTEGER) 
BEGIN 
    INSERT INTO stack VALUES (NULL, entry_id);
END !

CREATE PROCEDURE pop ()
BEGIN 
    DECLARE max_stack_pos INTEGER DEFAULT (SELECT MAX(stack_pos) FROM stack);
    DELETE FROM stack WHERE stack_pos = max_stack_pos;
END !

CREATE FUNCTION top ()
RETURNS INTEGER
BEGIN 
    DECLARE max_stack_pos INTEGER DEFAULT (SELECT MAX(stack_pos) FROM stack);
    RETURN (SELECT entry_id FROM stack WHERE stack_pos = max_stack_pos LIMIT 1);
END !

CREATE FUNCTION next_to_top ()
RETURNS INTEGER
BEGIN 
    DECLARE max_stack_pos INTEGER DEFAULT (SELECT MAX(stack_pos) FROM stack);
    RETURN (SELECT entry_id FROM stack WHERE stack_pos < max_stack_pos ORDER BY stack_pos DESC LIMIT 1);
END !

CREATE FUNCTION polar_angle(e1 INTEGER, e2 INTEGER)
RETURNS NUMERIC(12, 3)
BEGIN 
    DECLARE x1, y1 INTEGER; 
    DECLARE x2, y2 INTEGER; 

    SELECT center_lon, center_lat 
    FROM entry_pool NATURAL JOIN entry_geom
    WHERE entry_id = e1
    INTO x1, y1; 

    SELECT center_lon, center_lat 
    FROM entry_pool NATURAL JOIN entry_geom
    WHERE entry_id = e2
    INTO x2, y2; 

    RETURN sqrt(x1 * x2 + y1 + y2) / ((sqrt(x1 * x1 + y1 * y1)) * (sqrt(x2 * x2 + y2 * y2))); 
END ! 

CREATE FUNCTION ccw (e1 INTEGER, e2 INTEGER, e3 INTEGER)
RETURNS NUMERIC(12, 3)
BEGIN 

    DECLARE x1, y1 INTEGER; 
    DECLARE x2, y2 INTEGER; 
    DECLARE x3, y3 INTEGER; 

    SELECT center_lon, center_lat 
    FROM entry_pool NATURAL JOIN entry_geom
    WHERE entry_id = e1
    INTO x1, y1; 

    SELECT center_lon, center_lat 
    FROM entry_pool NATURAL JOIN entry_geom
    WHERE entry_id = e2
    INTO x2, y2; 

    SELECT center_lon, center_lat 
    FROM entry_pool NATURAL JOIN entry_geom
    WHERE entry_id = e3
    INTO x3, y3; 

    RETURN (x2 - x1) * (y3 - y1) * (x3 - x1);
END !

CREATE PROCEDURE graham_scan ()
BEGIN 

    DECLARE P0, curr_entry INTEGER DEFAULT 0; 
    DECLARE ccw_val NUMERIC(12, 3) DEFAULT 0; 

    DECLARE t, ntt INTEGER DEFAULT 0;

    DECLARE done INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT entry_id FROM entry_pool;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000'
        SET done = 1;

    CREATE TEMPORARY TABLE ordered_points LIKE entry_pool; 

    WITH geoms AS (SELECT * FROM entry_pool NATURAL JOIN entry_geom)
    SELECT entry_id 
    FROM geoms
    WHERE center_lat = (SELECT MIN(center_lat) FROM geoms)
    ORDER BY center_lat 
    LIMIT 1
    INTO P0;

    INSERT INTO ordered_points 
    SELECT entry_id FROM entry_pool
    ORDER BY polar_angle(P0, entry_id);

    OPEN cur;

    REPEAT
         FETCH cur INTO curr_entry;
         IF NOT done THEN
            SET t = top();
            SET ntt = next_to_top();
            SET ccw_val = ccw(ntt, t, curr_entry);
            
            WHILE ((SELECT COUNT(*) FROM stack) > 1 AND ccw_val < 0) DO 
                CALL pop();
            END WHILE; 

            CALL push(curr_entry);

         END IF;
     UNTIL done END REPEAT;
     CLOSE cur;

    DROP TEMPORARY TABLE ordered_points;

END !

-- Split a node (after it has overflown capacity by 1 element)

CREATE PROCEDURE split_node
(
    curr_level INTEGER,
    curr_node  INTEGER
)

BEGIN 

    -- load properties
    DECLARE depth INTEGER DEFAULT (SELECT depth FROM rtree_properties);
    DECLARE max_entries INTEGER DEFAULT (SELECT max_entries FROM rtree_properties);
    DECLARE curr_entry_node INTEGER DEFAULT 
        (SELECT node_id FROM inner_node_entries WHERE level = curr_level-1 AND child_node_id = curr_node);

    -- declare useful variables
    DECLARE e1, e2, max_dist INTEGER DEFAULT 0;
    DECLARE curr_entry, splitting_node_id, splitting_entry_id, m_nodes INTEGER DEFAULT 0; 
    DECLARE x1, y1, x2, y2 NUMERIC(10, 7); 
    DECLARE increment_1, increment_2 NUMERIC(10, 5) DEFAULT 0; 

    DECLARE use_inner BOOLEAN DEFAULT FALSE; 

    -- cursor 
    
    DECLARE done INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT entry_id FROM entry_pool;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000'
        SET done = 1;


    -- We should be referring to the inner node
    IF (curr_level < depth ) THEN 
        SET use_inner = 1;
    END IF;
    
    -- Two special nodes that I use as intermediates
    INSERT INTO nodes VALUES (-1, 0, 0), (-1, 1, 0);

    -- The entries in the node being split
    IF (use_inner) THEN 
        INSERT INTO entry_pool (SELECT entry_id FROM inner_node_entries WHERE level = curr_level AND node_id = curr_node);
    ELSE 
        INSERT INTO entry_pool (SELECT entry_id FROM leaf_node_entries WHERE level = curr_level AND node_id = curr_node);
    END IF;
    
    -- Find two farthest away points among first 30 entries in root (using graham scan algorithm)

    CALL graham_scan();

    WITH ep1 AS (SELECT * FROM stack), ep2 AS (SELECT * FROM stack)
    SELECT ep1.entry_id, ep2.entry_id, distance(ep1.entry_id, ep2.entry_id) AS dist 
    FROM ep1 CROSS JOIN ep2 WHERE ep1.entry_id > ep2.entry_id ORDER BY dist DESC LIMIT 1
    INTO e1, e2, max_dist;

    TRUNCATE stack;

    -- insert these into node entries
    IF (use_inner) THEN 
        INSERT INTO inner_node_entries VALUES
        (e1, (SELECT child_node_id FROM (SELECT * FROM inner_node_entries WHERE entry_id = e1 LIMIT 1) AS ine1), -1, 0),
        (e2, (SELECT child_node_id FROM (SELECT * FROM inner_node_entries WHERE entry_id = e2 LIMIT 1) AS ine2), -1, 1); 
    ELSE 
        INSERT INTO leaf_node_entries VALUES
        (e1, (SELECT tropomi_id FROM (SELECT * FROM leaf_node_entries WHERE entry_id = e1 LIMIT 1) AS ine1), -1, 0),
        (e2, (SELECT tropomi_id FROM (SELECT * FROM leaf_node_entries WHERE entry_id = e2 LIMIT 1) AS ine2), -1, 1); 
    END IF;
    
    -- Insert two farthest into entry_geom
    INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
        SELECT -1, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon FROM entry_geom WHERE entry_id = e1; 
    INSERT INTO entry_geom (entry_id, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon) 
        SELECT -2, mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon FROM entry_geom WHERE entry_id = e2;  
    
    -- Increment num entries in nodes
    UPDATE nodes SET num_entries = num_entries + 1 WHERE level = -1 AND (node_id = 1 OR node_id = 0); 
    
    -- Remove two farthest from entry pool 
    DELETE FROM entry_pool WHERE entry_id = e1 OR entry_id = e2; 

    OPEN cur;

    REPEAT
         FETCH cur INTO curr_entry;
         IF NOT done THEN
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

            IF (use_inner) THEN 
                -- insert value into appropriate leaf_node entries
                -- UPDATE rtree_properties SET a = 2000;
                INSERT INTO inner_node_entries VALUES 
                (curr_entry, 
                    (SELECT child_node_id 
                     FROM 
                     (SELECT * FROM inner_node_entries WHERE entry_id = curr_entry LIMIT 1) AS lne1), 
                -1, splitting_node_id); 
            ELSE 
                -- insert value into appropriate leaf_node entries
                INSERT INTO leaf_node_entries VALUES 
                (curr_entry, 
                    (SELECT tropomi_id 
                     FROM (SELECT * FROM leaf_node_entries WHERE entry_id = curr_entry LIMIT 1) AS lne1), 
                -1, splitting_node_id); 
            END IF;
            
            -- update the entry_geom value of the second node 
            UPDATE entry_geom SET 
                mbr_tlc_lat = GREATEST(mbr_tlc_lat, y1),
                mbr_tlc_lon = LEAST(mbr_tlc_lon, x1), 
                mbr_brc_lat = LEAST(mbr_brc_lat, y2), 
                mbr_brc_lon = GREATEST(mbr_brc_lon, x2)
            WHERE entry_id = splitting_entry_id; 
            
            -- Increment count of entries in nodes
            UPDATE nodes SET num_entries = num_entries + 1 WHERE level = -1 AND node_id = splitting_node_id; 
         END IF;
     UNTIL done END REPEAT;
     CLOSE cur;

    TRUNCATE entry_pool;

    -- Maximum entries in node 
    SET m_nodes = (SELECT MAX(node_id) FROM nodes WHERE level = curr_level);

    -- Remove overflowing node
    DELETE FROM nodes WHERE level = curr_level AND node_id = curr_node; 

    -- Remove all the relevant leaf entry nodes

    IF (use_inner) THEN 
        DELETE FROM inner_node_entries WHERE level = curr_level AND node_id = curr_node;
    ELSE 
        DELETE FROM leaf_node_entries WHERE level = curr_level AND node_id = curr_node;
    END IF;
    

    IF curr_level = 0 THEN 
        
        -- Increment each node's level 
        UPDATE nodes SET level = level + 1; 
        UPDATE nodes SET level = level + 1 WHERE level = 0; 

        -- Insert new root node, with two entries
        INSERT INTO nodes VALUES (0, 0, 2); 
        
        -- Insert two leaf nodes as entries into root node
        INSERT INTO rtree_entries VALUES (NULL); 
        INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), 1, 0, 0);
        INSERT INTO rtree_entries VALUES (NULL); 
        INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), 0, 0, 0);
        
        -- Should be level + 1, because we're now at level 1
        IF (use_inner) THEN 
            -- UPDATE rtree_properties SET a = 3000;
            UPDATE inner_node_entries SET level = level + 2 WHERE level = -1; 
        END IF;

        UPDATE leaf_node_entries SET level = depth + 1 ; 
        
        -- Update all the entry geoms
        UPDATE entry_geom SET entry_id = entry_id + 1 + (SELECT MAX(entry_id) FROM rtree_entries) WHERE entry_id < 0; 
        
        -- Increment the depth of the tree
        UPDATE rtree_properties SET depth = depth + 1; 

    ELSE 

        -- Move temp nodes into final position
        UPDATE nodes SET level = curr_level, node_id = curr_node WHERE level = -1 AND node_id = 0; 
        UPDATE nodes SET level = curr_level, node_id = m_nodes + 1 WHERE level = -1 AND node_id = 1; 
        
        -- Insert two leaf nodes as entries into inner node
        INSERT INTO rtree_entries VALUES (NULL); 
        INSERT INTO inner_node_entries VALUES ((SELECT MAX(entry_id) FROM rtree_entries), m_nodes + 1, curr_level-1, curr_entry_node);
        
        -- Should be level + 1, because we're now at level 1
        -- These should update on cascade of nodes... Maybe... 
        -- Should be level + 1, because we're now at level 1
        IF (use_inner) THEN 
            -- UPDATE rtree_properties SET a = 4000;
            UPDATE inner_node_entries SET level = curr_level, node_id = curr_node WHERE level = -1 AND node_id = 0; 
            UPDATE inner_node_entries SET level = curr_level, node_id = m_nodes + 1 WHERE level = -1 AND node_id = 1; 
        ELSE 
            UPDATE leaf_node_entries SET level = curr_level, node_id = curr_node WHERE level = -1 AND node_id = 0; 
            UPDATE leaf_node_entries SET level = curr_level, node_id = m_nodes + 1 WHERE level = -1 AND node_id = 1; 
        END IF;
        
        -- Get the maximum entry_id and remove this entry geometry
        SET m_nodes = (SELECT (entry_id) FROM inner_node_entries WHERE level = curr_level-1 AND child_node_id = curr_node);
        DELETE FROM entry_geom WHERE entry_id = m_nodes;
        
        -- Update entry_id of reloaded entry
        UPDATE entry_geom SET entry_id = m_nodes WHERE entry_id = -1; 
        
        -- Update entry_id of the new entry 
        SET m_nodes = (SELECT MAX(entry_id) FROM entry_geom);
        UPDATE entry_geom SET entry_id = m_nodes+1 WHERE entry_id = -2; 
        
        -- Update number of entries in nodes table
        UPDATE nodes SET num_entries = num_entries + 1 
        WHERE level = curr_level-1 AND node_id = curr_entry_node; 

    END IF;

END !

-- Insert a data point into the tree structure

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
    
    -- Declare useful variables
    DECLARE curr_level, curr_node, curr_entry_node INTEGER DEFAULT 0; 
    
    SET UNIQUE_CHECKS = 0;
    SET FOREIGN_KEY_CHECKS = 0;
    
    -- First insert the record into tropomi
    INSERT INTO tropomi VALUES (NULL, date, SIF); 
    
    -- ------------------------------------------------------------------------
    -- Find curr_level and curr_node (where to insert current leaf entry into)
    -- ------------------------------------------------------------------------

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
        
        SET curr_level = curr_level + 1; 
        
        -- Clear the traverser
        DELETE FROM traverser; 
        
    END WHILE;

    DELETE FROM traverser; 

    -- ---------------------------------------------------------------------
    -- Insert the entry that is being added (will split after if necessary)
    -- ---------------------------------------------------------------------

    -- Insert new leaf_node entry
    INSERT INTO rtree_entries VALUES (NULL);
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

    -- Increment num entries in nodes
    UPDATE nodes 
    SET num_entries = num_entries + 1
    WHERE level = curr_level AND node_id = curr_node; 

    -- -------------------------
    -- Split node if necessary
    -- -------------------------

    IF (SELECT num_entries FROM nodes WHERE level = curr_level AND node_id = curr_node) >= max_entries THEN
            
        CALL split_node(curr_level, curr_node);
            
    END IF;

    IF curr_level > 0 THEN 
        CALL update_MBR(
                (SELECT entry_id
                 FROM entry_geom NATURAL JOIN inner_node_entries WHERE level = curr_level-1 AND child_node_id = curr_node) 
        );
    END IF;

    SET UNIQUE_CHECKS=1; 
    SET FOREIGN_KEY_CHECKS=1;

END ! 

DELIMITER ; 
