-- DROP TABLE IF EXISTS entry_geom; 
-- DROP TABLE IF EXISTS leaf_node_entries; 
-- DROP TABLE IF EXISTS inner_node_entries; 
-- DROP TABLE IF EXISTS rtree_entries; 
-- DROP TABLE IF EXISTS nodes; 
-- DROP TABLE IF EXISTS tropomi;

SHOW GLOBAL VARIABLES LIKE 'slow_query_log';

SET @@profiling = 0;
SET @@profiling_history_size = 0;
SET @@profiling_history_size = 100; 
SET @@profiling = 1;

SET profiling = 0;
SET profiling_history_size = 1000;
SHOW PROFILES;

CALL rtree_insert(' 2019-02-01 00:59:53 ' , 0.6325, -44.0642, -176.6585, -44.1513, -176.5152);
CALL rtree_insert(' 2019-02-01 00:59:53 ' , 0.2667, -44.0398, -176.5245, -44.1267, -176.3834);
CALL rtree_insert(' 2019-02-01 00:59:55 ' , 0.7939, -43.9148, -176.5432, -44.0017, -176.4022);
CALL rtree_insert(' 2019-02-01 00:59:58 ' , -0.0651, -43.7273, -176.5713, -43.8142, -176.4308);
CALL rtree_insert(' 2019-02-01 01:27:25 ' , -0.1348, 51.4097, 156.5509, 51.3069, 156.7035);

CALL rtree_insert(' 2019-02-01 01:27:24 ' , 0.4091, 51.3956, 156.7035, 51.2936, 156.8546);
CALL rtree_insert(' 2019-02-01 01:27:25 ' , -0.427, 51.4537, 156.6567, 51.3516, 156.8081);
CALL rtree_insert(' 2019-02-01 01:27:27 ' , -0.1051, 51.5699, 156.5629, 51.4677, 156.7147);
CALL rtree_insert(' 2019-02-01 01:27:25 ' , 0.196, 51.5398, 156.865, 51.439, 157.0139);
CALL rtree_insert(' 2019-02-01 01:27:21 ' , -0.6926, 51.3487, 157.1526, 51.2487, 157.2995);

CALL rtree_insert(' 2019-02-01 01:27:25 ' , -0.2011, 51.5818, 156.9675, 51.4816, 157.1152);
CALL rtree_insert(' 2019-02-01 01:27:24 ' , -0.1562, 51.5649, 157.1152, 51.4653, 157.2618);
CALL rtree_insert(' 2019-02-01 01:27:22 ' , -0.3921, 51.6072, 157.6022, 51.5099, 157.7439);
CALL rtree_insert(' 2019-02-01 01:07:08 ' , 0.8156, -18.1858, -178.7967, -18.2706, -178.7139);
CALL rtree_insert(' 2019-02-01 00:49:27 ' , 0.2391, -79.5816, -160.4627, -79.6651, -160.0292);

CALL rtree_insert(' 2019-02-01 00:49:28 ' , -0.583, -79.5204, -160.5313, -79.6038, -160.1004);
CALL rtree_insert(' 2019-02-01 00:49:25 ' , 1.4903, -79.6205, -160.0292, -79.7041, -159.5965);
CALL rtree_insert(' 2019-02-01 00:49:27 ' , -0.4184, -79.5593, -160.1004, -79.6429, -159.6703);
CALL rtree_insert(' 2019-02-01 00:49:28 ' , 0.0983, -79.4981, -160.171, -79.5816, -159.7435);
CALL rtree_insert(' 2019-02-01 00:49:29 ' , 0.1503, -79.437, -160.2412, -79.5204, -159.8161);

CALL rtree_insert(' 2019-02-01 00:49:25 ' , -0.4538, -79.598, -159.6703, -79.6816, -159.241);
CALL rtree_insert(' 2019-02-01 00:49:27 ' , 1.0563, -79.5369, -159.7435, -79.6205, -159.3168);
CALL rtree_insert(' 2019-02-01 00:49:28 ' , 0.1838, -79.4758, -159.8161, -79.5593, -159.3919);
CALL rtree_insert(' 2019-02-01 00:49:29 ' , -0.5733, -79.4147, -159.8882, -79.4981, -159.4664);
CALL rtree_insert(' 2019-02-01 00:49:30 ' , -0.4381, -79.3536, -159.9588, -79.437, -159.5404);

CALL rtree_insert(' 2019-02-01 00:49:27 ' , -0.1312, -79.5144, -159.3919, -79.598, -158.9685);
CALL rtree_insert(' 2019-02-01 00:49:28 ' , 0.4132, -79.4533, -159.4664, -79.5369, -159.0455);
CALL rtree_insert(' 2019-02-01 00:49:29 ' , 0.26, -79.3923, -159.5404, -79.4758, -159.1218);
CALL rtree_insert(' 2019-02-01 00:49:30 ' , -0.1614, -79.3312, -159.6129, -79.4147, -159.1976);
CALL rtree_insert(' 2019-02-01 00:49:27 ' , 0.988, -79.4918, -159.0455, -79.5754, -158.6252);

CALL rtree_insert(' 2019-02-01 00:49:29 ' , 0.26, -79.3699, -159.1976, -79.4533, -158.7823);
CALL rtree_insert(' 2019-02-01 00:49:51 ' , -0.2126, -77.914, -158.3056, -77.9965, -157.9588);
CALL rtree_insert(' 2019-02-01 00:49:50 ' , 0.3935, -77.9532, -157.9588, -78.0356, -157.612);
CALL rtree_insert(' 2019-02-01 00:49:51 ' , -0.0459, -77.8924, -158.0328, -77.9748, -157.6881);
CALL rtree_insert(' 2019-02-01 00:49:52 ' , 1.0793, -77.8316, -158.1063, -77.914, -157.7634);

CALL rtree_insert(' 2019-02-01 00:49:54 ' , 1.0519, -77.7708, -158.1791, -77.8531, -157.8382);
CALL rtree_insert(' 2019-02-01 00:49:55 ' , 0.5154, -77.7099, -158.2511, -77.7923, -157.9121);
CALL rtree_insert(' 2019-02-01 00:49:49 ' , -0.2633, -77.9922, -157.612, -78.0746, -157.2657);
CALL rtree_insert(' 2019-02-01 00:49:50 ' , -0.0343, -77.9315, -157.6881, -78.0139, -157.3436);
CALL rtree_insert(' 2019-02-01 00:49:51 ' , 0.0426, -77.8708, -157.7634, -77.9532, -157.4209);

CALL rtree_insert(' 2019-02-01 00:49:52 ' , -0.0523, -77.8101, -157.8382, -77.8924, -157.4973);
CALL rtree_insert(' 2019-02-01 00:49:55 ' , 0.3576, -77.6885, -157.9854, -77.7708, -157.6485);
CALL rtree_insert(' 2019-02-01 00:49:56 ' , 0.4045, -77.6277, -158.0581, -77.7099, -157.723);
CALL rtree_insert(' 2019-02-01 00:49:58 ' , -0.0976, -77.5061, -158.2019, -77.5882, -157.87);
CALL rtree_insert(' 2019-02-01 00:49:49 ' , 0.2256, -77.9705, -157.3436, -78.0529, -156.9993);

CALL rtree_insert(' 2019-02-01 00:49:50 ' , 0.2822, -77.9098, -157.4209, -77.9922, -157.0785);
CALL rtree_insert(' 2019-02-01 00:49:52 ' , 0.2008, -77.7885, -157.5733, -77.8708, -157.2346);
CALL rtree_insert(' 2019-02-01 00:49:54 ' , -0.2059, -77.7278, -157.6485, -77.8101, -157.3118);
CALL rtree_insert(' 2019-02-01 00:49:55 ' , -0.2264, -77.667, -157.723, -77.7493, -157.3882);
CALL rtree_insert(' 2019-02-01 00:49:56 ' , 0.5981, -77.6063, -157.7969, -77.6885, -157.4638);

CALL rtree_insert(' 2019-02-01 00:49:58 ' , 0.1945, -77.4848, -157.943, -77.5669, -157.6132);
CALL rtree_insert(' 2019-02-01 00:49:59 ' , 0.7847, -77.424, -158.0148, -77.5061, -157.6872);
CALL rtree_insert(' 2019-02-01 00:50:00 ' , 0.6365, -77.3632, -158.086, -77.4452, -157.7602);
CALL rtree_insert(' 2019-02-01 00:50:01 ' , -0.7367, -77.3024, -158.1569, -77.3844, -157.8325);
CALL rtree_insert(' 2019-02-01 00:50:03 ' , -0.2798, -77.1807, -158.2966, -77.2626, -157.9757);

CALL rtree_insert(' 2019-02-01 00:49:49 ' , 0.1692, -77.9487, -157.0785, -78.0311, -156.7363);
CALL rtree_insert(' 2019-02-01 00:49:52 ' , 0.1324, -77.7669, -157.3118, -77.8492, -156.9752);

SELECT * FROM tropomi;
SELECT * FROM leaf_node_entries; 
SELECT * FROM inner_node_entries; 
SELECT * FROM nodes; 
SELECT * FROM entry_geom ; 
SELECT * FROM rtree_entries; 


SELECT * FROM rtree_properties;
SELECT * FROM path_to_leaf;

SELECT COUNT(*) FROM tropomi;

TRUNCATE entry_pool;

INSERT INTO entry_pool VALUES (1);

SELECT SUM(num_entries) FROM nodes WHERE level = 3; 
SELECT * FROM inner_node_entries WHERE level = 2;

SHOW INDEXES FROM entry_geom; 

SELECT COUNT(*) FROM entry_geom;
SELECT COUNT(entry_id) FROM leaf_node_entries;

SELECT *  FROM (entry_geom NATURAL JOIN leaf_node_entries) ; 

SELECT COUNT(*) FROM tropomi;

SELECT COUNT(*) FROM entry_pool;
SELECT COUNT(*) FROM leaf_node_entries WHERE level <> 2;

SELECT * FROM traverser; 

SELECT COUNT(*) FROM entry_geom; 

SELECT * FROM (entry_geom NATURAL JOIN leaf_node_entries) UNION 
SELECT * FROM (entry_geom NATURAL JOIN inner_node_entries); 

SELECT SUM(num_entries) FROM nodes WHERE level = 1;

(SELECT mbr_tlc_lat, mbr_tlc_lon, 
					mbr_brc_lat, mbr_brc_lon, level, 1 
			 FROM 
			 entry_geom NATURAL JOIN leaf_node_entries) UNION 
			 (SELECT mbr_tlc_lat, mbr_tlc_lon, 
					mbr_brc_lat, mbr_brc_lon, level, 1 
			 FROM 
			 entry_geom NATURAL JOIN inner_node_entries);

