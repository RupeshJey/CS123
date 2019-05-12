-- Rupesh Jeyaram 
-- Created April 21st, 2019

-- DROP TABLE statements
-- Note: preserve order because of foreign key constraints

DROP TABLE IF EXISTS entry_geom; 
DROP TABLE IF EXISTS leaf_node_entries; 
DROP TABLE IF EXISTS inner_node_entries; 
DROP TABLE IF EXISTS rtree_entries; 
DROP TABLE IF EXISTS nodes; 
DROP TABLE IF EXISTS tropomi;
DROP TABLE IF EXISTS rtree_properties; 

-- tropomi holds the satellite data without geospatial data

-- tropomi_id is an auto-incrementing integer that can be used
-- to identify the record uniquely
-- time is when the datapoint was recorded (UTC)
-- SIF is solar induced fluorescence, the property we are examining

CREATE TABLE tropomi (

    tropomi_id  INTEGER                  AUTO_INCREMENT, 
    time            DATETIME                NOT NULL, 
    SIF             NUMERIC(10, 2)       NOT NULL,
    
    PRIMARY KEY (tropomi_id)
    
);

-- nodes contains all the rtree nodes and their entry count
-- level is the level of the tree where the node is located 0...depth
-- node_id specifies the node within the level 
-- num_entries should update the number of entries per node. 

CREATE TABLE nodes (

    level                INTEGER            NOT NULL,
    node_id          INTEGER             NOT NULL, 
    num_entries   INTEGER             NOT NULL,
    
    PRIMARY KEY (level, node_id)
    
);

-- This table should hold all the entry id's
-- Self-explanatory, auto-incrementing

CREATE TABLE rtree_entries (

    entry_id        INTEGER             AUTO_INCREMENT,
    
    PRIMARY KEY (entry_id)
    
);

-- This table specifically holds all the entries in inner nodes
-- entry_id is a foreign key to rtree_entries (entry_id)
-- child_node_id is an integer that points to the child node
-- level and node_id are same as above

CREATE TABLE inner_node_entries (
    
    entry_id             INTEGER        NOT NULL,
    child_node_id   INTEGER         NOT NULL, 
    level                   INTEGER        NOT NULL, 
    node_id              INTEGER       NOT NULL,
    
    PRIMARY KEY (entry_id),
    UNIQUE (child_node_id),
    
--     CONSTRAINT FOREIGN KEY ((level+1), child_node_id)
--         REFERENCES  rtree_entries (level, node_id)

    CONSTRAINT FOREIGN KEY (entry_id)
        REFERENCES  rtree_entries (entry_id),
    
    CONSTRAINT FOREIGN KEY (level, node_id)
        REFERENCES  nodes (level, node_id)
    
); 

-- This table is very similar to the above, except it contains 
-- the pointer to tropomi table instead of a child node. This is
-- because it each leaf should be correlated with exactly one
-- data record. 

CREATE TABLE leaf_node_entries (
    
    entry_id             INTEGER        NOT NULL,
    tropomi_id         INTEGER        NOT NULL, 
    level                   INTEGER       NOT NULL, 
    node_id              INTEGER       NOT NULL,
    
    -- PRIMARY KEY (entry_id), Disabling for 
    -- UNIQUE (tropomi_id), Disabling temporarily
    
    CONSTRAINT FOREIGN KEY (tropomi_id)
        REFERENCES  tropomi (tropomi_id),

    CONSTRAINT FOREIGN KEY (entry_id)
        REFERENCES  rtree_entries (entry_id),
    
    CONSTRAINT FOREIGN KEY (level, node_id)
        REFERENCES  nodes (level, node_id)
    
); 

-- This is the table with all the geometric properties of  
-- each entry. 

-- The points were NUMERIC(10,7) because we don't need
-- more than 3 digits to the left of the decimal (-180 to 180)
-- The areas were NUMERIC(10,5) since we could get a max
-- value of 180 * 360 = 64,800. 

CREATE TABLE entry_geom (

    entry_id        INTEGER         NOT NULL, 
    
    mbr_tlc_lat       NUMERIC(10, 7)      NOT NULL, 
    mbr_tlc_lon      NUMERIC(10, 7)      NOT NULL, 
    
    mbr_brc_lat      NUMERIC(10, 7)      NOT NULL, 
    mbr_brc_lon     NUMERIC(10, 7)      NOT NULL, 
    
    center_lat         NUMERIC(10, 7)      GENERATED ALWAYS AS ((mbr_tlc_lat + mbr_brc_lat) / 2),
    center_lon        NUMERIC(10, 7)      GENERATED ALWAYS AS ((mbr_tlc_lon + mbr_brc_lon) / 2), 
    
    area                  NUMERIC(10, 5)      GENERATED ALWAYS AS ((mbr_tlc_lat - mbr_brc_lat) * (mbr_brc_lon - mbr_tlc_lon)), 
    
    PRIMARY KEY (entry_id),
    
    CONSTRAINT FOREIGN KEY (entry_id)
        REFERENCES rtree_entries (entry_id) ON UPDATE CASCADE

); 

CREATE TABLE rtree_properties (
    min_entries       INTEGER            NOT NULL,
    max_entries      INTEGER            NOT NULL, 
    depth                INTEGER            NOT NULL, 
    a   NUMERIC(10, 5), 
    b NUMERIC(10, 5),
    c   NUMERIC(10, 5), 
    d NUMERIC(10, 5)
);

-- Populating the rtree with basic info: 

INSERT INTO rtree_properties VALUES (1, 30, 0, NULL, NULL, NULL, NULL);

-- Create the root node of rtree. 
INSERT INTO nodes VALUES (0, 0, 0);