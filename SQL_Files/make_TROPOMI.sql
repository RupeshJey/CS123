-- Rupesh Jeyaram 
-- Created April 6th, 2019

-- DROP TABLE commands:

DROP TABLE IF EXISTS tropomi; 
DROP TABLE IF EXISTS rtree; 
DROP TABLE IF EXISTS rtree_pool; 
DROP TABLE IF EXISTS rtree_buffer; 
DROP TABLE IF EXISTS rtree_leaf1; 
DROP TABLE IF EXISTS rtree_leaf2; 
DROP TABLE IF EXISTS rtree_properties; 
DROP TABLE IF EXISTS rtree_nodes;


-- DROP TRIGGER commands: 

DROP TRIGGER IF EXISTS trg_insert; 
-- DROP TRIGGER IF EXISTS trg_insert;

-- CREATE TABLE commands:

-- This is the most important table of this project
-- It will store the direct satellite data

-- record_id is an autoincrementing unique id (primary key)
-- time is when the datapoint was recorded (UTC)
-- I am intentionally not setting this as UNIQUE, because it's conceivable 
-- that multiple spectrometers on a satellite all collect data at the same 
-- time. 
-- SIF is solar induced fluorescence, the property we are examining
-- lat/lon are center of the datapoint (projected on the surfece, not where
-- the satellite is)
-- mbr_* are minimum bounding rectangle
-- tlc_* are top left corner coordinates
-- brc_* are bottom right corner coordinates

CREATE TABLE tropomi (

    record_id       INTEGER             AUTO_INCREMENT PRIMARY KEY ,
    time               DATETIME           NOT NULL,
    SIF                VARCHAR(10)      NOT NULL,
    lat                  VARCHAR(20)      NOT NULL,
    lon                 VARCHAR(20)      NOT NULL, 
    
    
    mbr_tlc_lat       VARCHAR(20)      NOT NULL, 
    mbr_tlc_lon      VARCHAR(20)      NOT NULL, 
    
    mbr_brc_lat      VARCHAR(20)      NOT NULL, 
    mbr_brc_lon      VARCHAR(20)      NOT NULL
); 

-- This table holds the internal rtree structure of the data. 
-- It can be traversed when querying tropomi data instead of
-- directly probing the 'tropomi' table above. 

-- level and node refer to the node's location in the tree
-- mbr specs are the same as above

-- child is not null only if this row is an internal node. It holds
-- the 'node' of its child. We know the child's level will be 
-- level+1

-- record_id is not null only if this row is a leaf node. It holds
-- the record_id that points to the data point in 'tropomi'. 

CREATE TABLE rtree(
    level               INTEGER     NOT NULL,
    node              INTEGER      NOT NULL,
    
    mbr_tlc_lat       VARCHAR(20)      NOT NULL, 
    mbr_tlc_lon      VARCHAR(20)      NOT NULL, 
    
    mbr_brc_lat      VARCHAR(20)      NOT NULL, 
    mbr_brc_lon     VARCHAR(20)      NOT NULL,
    
    center_lat                  VARCHAR(20)      NOT NULL,
    center_lon                 VARCHAR(20)      NOT NULL, 
    
    child                  INTEGER,
    record_id           INTEGER
);

-- These tables are a temporary fix to the CREATE TEMPORARY TABLE issues
-- where I cannot refer to the table multiple times in the same query 
CREATE TABLE rtree_pool LIKE rtree; 
CREATE TABLE rtree_buffer LIKE rtree; 
CREATE TABLE rtree_leaf1 LIKE rtree; 
CREATE TABLE rtree_leaf2 LIKE rtree; 

-- This table contains information about the nodes of the tree
-- i.e, whether each node is an internal node or a leaf node

CREATE TABLE rtree_nodes(
    level               INTEGER     NOT NULL,
    node              INTEGER      NOT NULL,
    num_entries   INTEGER     NOT NULL,
    leaf                BOOLEAN     NOT NULL,
    
    PRIMARY KEY (level, node)
);

-- This table contains the numerical parameters of the rtree structure
-- The property name is a key to the propery value

CREATE TABLE rtree_properties (

    prop_name     VARCHAR(20)     NOT NULL,
    prop_value      VARCHAR(20)     NOT NULL
    
);

-- CREATE TRIGGER commands: 

DELIMITER !

CREATE TRIGGER trg_insert AFTER INSERT ON tropomi FOR EACH ROW
BEGIN 
    
    -- properties of the tree
    
    DECLARE depth INTEGER DEFAULT 0;
    DECLARE min_entries INTEGER DEFAULT 0;
    DECLARE max_entries INTEGER DEFAULT 0; 
    
    -- the level we are currently looking at
    DECLARE curr_level INTEGER DEFAULT 0;
    -- the node we are currently looking at
    DECLARE curr_node INTEGER DEFAULT 0;
    -- number of entries in the current node
    DECLARE curr_num_entries INTEGER DEFAULT 0; 
    -- the node that we should traverse down
    DECLARE best_node INTEGER DEFAULT 0;
    
    -- flag that signals whether we found the correct  leaf
    DECLARE found_leaf BOOLEAN DEFAULT FALSE;
    
    -- first need to get the number of entries in the node
    DECLARE num_entries_in_leaf INTEGER DEFAULT 0;
    
    -- e1, e2 that are the furthest away points in a leaf
    DECLARE e1 INTEGER DEFAULT 0; 
    DECLARE e2 INTEGER DEFAULT 0; 
    
    DECLARE area1 VARCHAR(10) DEFAULT 0; 
    DECLARE area2 VARCHAR(10) DEFAULT 0; 
    
    DECLARE incr1 VARCHAR(10) DEFAULT 0; 
    DECLARE incr2 VARCHAR(10) DEFAULT 0; 
    
    DECLARE height1 VARCHAR(10) DEFAULT 0; 
    DECLARE width1 VARCHAR(10) DEFAULT 0; 
    
    DECLARE height2 VARCHAR(10) DEFAULT 0; 
    DECLARE width2 VARCHAR(10) DEFAULT 0; 
    
    -- tree properties
    
    SELECT prop_value FROM rtree_properties WHERE prop_name = 'depth'
    INTO depth; 

    SELECT prop_value FROM rtree_properties WHERE prop_name = 'min_entries'
    INTO min_entries; 
    
    SELECT prop_value FROM rtree_properties WHERE prop_name = 'max_entries'
    INTO max_entries; 
    
    -- Traverse and find leaf node, L, that the new row should go in
    -- start at root (0,0)
    
    -- That is, select the entry at each level whose MBR will require
    -- minimum enlargement to cover the new row's MBR. The (n-1)th
    -- level will lead to selecting a leaf node. 
    
    -- If L can accommodate the new row, simply insert new row into L, 
    -- update all MBRs from root. Call it a day. 
    
    
    -- if the tree only consists of the root, then move on
    IF (curr_level = depth) THEN 
        SET found_leaf = TRUE;
    END IF;
    
    -- otherwise, traverse the tree until we find the appropriate leaf node
    WHILE NOT found_leaf DO
        SET curr_level = curr_level + 1; 
    END WHILE;


    SELECT num_entries FROM rtree_nodes 
    WHERE level = curr_level AND node = best_node
    INTO num_entries_in_leaf; 

    -- This code was SUPER inefficient. Don't use! 
    -- Store the number of entries per node instead of 
    -- retrieving it every time

--     SELECT num_entries FROM rtree 
--     WHERE level = curr_level AND node = best_node
--     INTO num_entries_in_leaf; 

    -- if the leaf can accommodate the new row, insert it 
    IF (num_entries_in_leaf < max_entries) THEN

        INSERT INTO rtree VALUES 
        (curr_level, best_node, 
            NEW.mbr_tlc_lat, NEW.mbr_tlc_lon, 
            NEW.mbr_brc_lat, NEW.mbr_brc_lon, 
            (NEW.mbr_tlc_lat + NEW.mbr_brc_lat)/2,
            (NEW.mbr_tlc_lon + NEW.mbr_brc_lon)/2,
            NULL, NEW.record_id);
            
        -- Increment the number of leaves the node holds by 1
        
        UPDATE rtree_nodes 
        SET num_entries = num_entries + 1
        WHERE level = curr_level AND node = best_node; 
            
        -- Also need to make sure the mbr from root to leaf is correctly set

    ELSE 
    
        -- Let this table hold the found leaf's entries (copying rtree schema)
        -- so that I can manipulate the values locally 
        
        
        -- Step 1: select all the leaf's entries (and NEW) out of the tree into rtree_pool
        -- Step 2: delete the leaf's entries from rtree
        -- Step 3: find e1, e2 from rtree_pool that are furthest apart
        -- Step 4: create a new leaves, L1 and L2, and insert e1, e2
        -- Step 6: insert each entry from rtree_pool into the leaf that minimally grows its mbr
        -- Step 7: update MBRs from root to leaf
        -- Step 8: split upper nodes if necessary
        
        -- 
        -- Step 1
        -- 
        
        -- The entries already in the leaf
        INSERT INTO rtree_pool 
        SELECT * FROM rtree WHERE level = curr_level AND node = best_node ; 
        
        -- The new entry
        INSERT INTO rtree_pool
        SELECT curr_level, best_node, 
        NEW.mbr_tlc_lat, NEW.mbr_tlc_lon, 
        NEW.mbr_brc_lat, NEW.mbr_brc_lon, 
        (NEW.mbr_tlc_lat + NEW.mbr_brc_lat)/2,
        (NEW.mbr_tlc_lon + NEW.mbr_brc_lon)/2,
        NULL, NEW.record_id; 
        
        -- 
        -- Step 2
        -- 
        
        DELETE FROM rtree WHERE level = curr_level AND node = best_node; 
        
        -- 
        -- Step 3
        -- 
    
        -- Big ugly query to obtain furthest-apart points from (leaf+new)
        -- But it works! 
        
        -- distances contains all the distances from one point to another
        WITH distances AS (
            -- e1, e2 are two references to the leaf
            WITH 
                e1 AS (SELECT * FROM rtree_pool), 
                e2 AS (SELECT * FROM rtree_pool)

            -- Just want the record ids
            SELECT e1.record_id AS r1, e2.record_id AS r2,
            -- and the cross-distances 
            (sqrt(pow(e2.center_lat - e1.center_lat, 2) + pow(e2.center_lon - e1.center_lon, 2))) AS distance
            -- from the two-way join
            FROM e1 CROSS JOIN e2
            -- maybe this will make the query a bit faster? 
            WHERE e1.record_id <> e2.record_id
        )
    
        -- just get the entries that are furthest apart
        SELECT r1, r2 FROM distances WHERE distance = (SELECT MAX(distance) FROM distances) LIMIT 1 INTO e1, e2; 
        
        
        -- Now need to form distinct leaves. 
        
        INSERT INTO rtree_leaf1 
        (SELECT * FROM rtree_pool WHERE record_id = e1);
        
        INSERT INTO rtree_leaf2
        (SELECT * FROM rtree_pool WHERE record_id = e2);
        
        DELETE FROM rtree_pool WHERE record_id = e1 OR record_id = e2;
        
        INSERT INTO rtree_nodes VALUES (curr_level, -1, 0, TRUE), (curr_level, -2, 0, TRUE);
        
        
        -- Store the current 
        
        SELECT abs(mbr_tlc_lat - mbr_brc_lat) FROM rtree_leaf1 INTO height1; 
        SELECT abs(mbr_tlc_lon - mbr_brc_lon) FROM rtree_leaf1 INTO width1; 
        
        SELECT abs(mbr_tlc_lat - mbr_brc_lat) FROM rtree_leaf2 INTO height2; 
        SELECT abs(mbr_tlc_lon - mbr_brc_lon) FROM rtree_leaf2 INTO width2; 
        
        
        SELECT width1 * height1 INTO area1; 
        SELECT width2 * height2 INTO area2; 
        
        -- Go through each entry
        
        WHILE ((SELECT COUNT(*) FROM rtree_pool LIMIT 1) > 0) DO 
            INSERT INTO rtree_buffer
            SELECT * FROM rtree_pool LIMIT 1;
            
            
            
            DELETE FROM rtree_pool WHERE record_id = (SELECT AVG(record_id) FROM rtree_buffer);
            DELETE FROM rtree_buffer; 
            
        END WHILE;
        
        UPDATE rtree_properties 
        SET prop_value = prop_value+1
        WHERE prop_name = 'times_visited'; 
        
        DELETE FROM rtree_nodes WHERE node = -1 OR node = -2;
        
        DELETE FROM rtree_pool; 
        DELETE FROM rtree_leaf1; 
        DELETE FROM rtree_leaf2; 
        
    END IF;
    
    
END !;
DELIMITER ;


-- Populating the rtree with basic info: 

-- These values can be used by the trigger. 
INSERT INTO rtree_properties VALUES 
    ('min_entries', 1), 
    ('max_entries', 30),
    ('depth', 0),
    ('times_visited', 0);

-- Create the root node of rtree. 
INSERT INTO rtree_nodes VALUES (0, 0, 0, TRUE);