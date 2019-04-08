-- Rupesh Jeyaram 
-- Created April 6th, 2019

-- DROP TABLE commands:

DROP TABLE IF EXISTS tropomi; 

-- CREATE TABLE commands:

-- This is the most important table of this project
-- It will store the direct satellite data

-- record_id is an autoincrementing unique id (primary key)
-- time is when the datapoint was recorded (UTC)
-- I am intentionally not setting this as UNIQUE, because it's conceivable 
-- that multiple spectrometers on a satellite all collect data at the same 
-- time. 
-- SIF is solar induced fluorescence, the property we are examining
-- lat/lon are self-explanatory. Need to check with Christian whether 
-- this is the satellite's position, or the datapoint's location

CREATE TABLE tropomi (

    record_id       INTEGER             AUTO_INCREMENT PRIMARY KEY ,
    time               DATETIME           NOT NULL,
    SIF                VARCHAR(10)      NOT NULL,
    lat                  VARCHAR(20)      NOT NULL,
    lon                 VARCHAR(20)      NOT NULL

); 