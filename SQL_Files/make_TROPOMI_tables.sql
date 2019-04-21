-- Rupesh Jeyaram 
-- Created April 21st, 2019

DROP TABLE IF EXISTS entry_geom; 
DROP TABLE IF EXISTS leaf_node_entries; 
DROP TABLE IF EXISTS inner_node_entries; 
DROP TABLE IF EXISTS rtree_entries; 
DROP TABLE IF EXISTS nodes; 
DROP TABLE IF EXISTS tropomi;
DROP TABLE IF EXISTS rtree_properties; 


CREATE TABLE tropomi (

    tropomi_id  INTEGER                  NOT NULL, 
    time            DATETIME                NOT NULL, 
    SIF             NUMERIC(10, 2)       NOT NULL,
    
    PRIMARY KEY (tropomi_id)
    
);

CREATE TABLE nodes (

    level                INTEGER            NOT NULL,
    node_id          INTEGER             NOT NULL, 
    num_entries   INTEGER             NOT NULL,
    
    PRIMARY KEY (level, node_id)
    
);

CREATE TABLE rtree_entries (

    entry_id        INTEGER             NOT NULL,
    
    PRIMARY KEY (entry_id)
    
);

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

CREATE TABLE leaf_node_entries (
    
    entry_id             INTEGER        NOT NULL,
    tropomi_id         INTEGER        NOT NULL, 
    level                   INTEGER       NOT NULL, 
    node_id              INTEGER       NOT NULL,
    
    PRIMARY KEY (entry_id),
    UNIQUE (tropomi_id),
    
    CONSTRAINT FOREIGN KEY (tropomi_id)
        REFERENCES  tropomi (tropomi_id),

    CONSTRAINT FOREIGN KEY (entry_id)
        REFERENCES  rtree_entries (entry_id),
    
    CONSTRAINT FOREIGN KEY (level, node_id)
        REFERENCES  nodes (level, node_id)
    
); 

CREATE TABLE entry_geom (

    entry_id        INTEGER         NOT NULL, 
    
    center_lat         NUMERIC(10, 7)      NOT NULL,
    center_lon        NUMERIC(10, 7)      NOT NULL, 
    
    mbr_tlc_lat       NUMERIC(10, 7)      NOT NULL, 
    mbr_tlc_lon      NUMERIC(10, 7)      NOT NULL, 
    
    mbr_brc_lat      NUMERIC(10, 7)      NOT NULL, 
    mbr_brc_lon     NUMERIC(10, 7)      NOT NULL, 
    
    area                  NUMERIC(10, 5)      NOT NULL, 
    
    PRIMARY KEY (entry_id),
    
    CONSTRAINT FOREIGN KEY (entry_id)
        REFERENCES rtree_entries (entry_id) 

); 

CREATE TABLE rtree_properties (

    prop_name     VARCHAR(20)     NOT NULL,
    prop_value      INTEGER            NOT NULL
    
);

-- Populating the rtree with basic info: 

INSERT INTO rtree_properties VALUES 
    ('min_entries', 1), 
    ('max_entries', 30),
    ('depth', 0);

-- Create the root node of rtree. 
INSERT INTO nodes VALUES (0, 0, 0);