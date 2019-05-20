# Rupesh Jeyaram 
# Created April 6th, 2019

# Load all the TROPOMI data from the .nc files in SOURCE
# and import it into the specified local database 

# NetCDF docs: http://unidata.github.io/netcdf4-python/netCDF4/index.html

# Finding files in directory: https://stackoverflow.com/questions/3964681/find-
# all-files-in-a-directory-with-extension-txt-in-python

# Connecting to database: https://www.python.org/dev/peps/pep-0249/
# https://dev.mysql.com/doc/connector-python/en/connector-python-example-
# cursor-select.html
#
# How to run a SQL script from python (very straightforward)
# https://www.quora.com/How-can-I-execute-a-sql-file-in-Python

SOURCE = '../TROPOMI_Data/'

import os						# For searching through files
import netCDF4 as nc 			# For parsing data format
import mysql.connector as dbapi # For connecting to database
from datetime import datetime 	# For converting unix time to SQL datetime
import time 					# For timing the insertion
import numpy as np 				# For accessing the data more efficiently

# For creating images from rectangles
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.patches import Rectangle
from PIL import Image
import imageio
import glob
import os
import re

# For generating rectangles on image

max_length = 360
max_height = 180

NUM_TO_INSERT = 2000

im = np.array(Image.open('../Images/base.jpg'), dtype=np.uint8)

fig, ax = plt.subplots()

rect_num = 0

colors = ['b', 'r']

# Connect to database

conn = dbapi.connect(host='127.0.0.1', port=3306, user='root',
                         passwd='breakit', db='sys',
                         auth_plugin='mysql_native_password')

cursor = conn.cursor()

t0 = time.time()

# Clear everything before this run

make_tables = open("../SQL_Files/make_TROPOMI_tables.sql", 'r')
make_inserts = open("../SQL_Files/make_TROPOMI_insert.sql", 'r')

sql_make_tables = " ".join(make_tables.readlines())
sql_make_inserts = " ".join(make_inserts.readlines())

# cursor.execute(sql_make_tables)
# cursor.execute(sql_make_tables + " " + sql_make_inserts)
# conn.commit()

# For each data file in the directory 
for file in sorted(os.listdir(SOURCE)):
	if file.endswith('.nc'):
		print(file)

		# Parse it

		nc_file = nc.Dataset(SOURCE + file, 'r')
		keys = nc_file.variables.keys()

		# Very important to convert to numpy array here!!
		# It takes orders of magnitude longer to use the 
		# native Dataset format

		# print(keys)
		# print(np.array(nc_file.variables['bnds']))
		# print(np.array(nc_file.variables['lat_bnds']))
		# print(np.array(nc_file.variables['lon_bnds']))
		# break

		datetimes = np.array(nc_file.variables['TIME'])
		sifs = np.array(nc_file.variables['sif'])
		lats = np.array(nc_file.variables['lat'])
		lons = np.array(nc_file.variables['lon'])
		lat_bnds = np.array(nc_file.variables['lat_bnds'])
		lon_bnds = np.array(nc_file.variables['lon_bnds'])

		num_rows = len(datetimes)

		print(sifs)

		permutation = np.random.permutation(num_rows)
		datetimes = datetimes[permutation]
		sifs = sifs[permutation]
		lats = lats[permutation]
		lons = lons[permutation]
		lat_bnds = np.take(lat_bnds, permutation, axis = 1) 
		lon_bnds = np.take(lon_bnds, permutation, axis = 1) 

		print(sifs)

		# Enter each record into the database

		t1 = time.time()

		# Insert rows one-by-one
		for i in range(num_rows):

			# Temporary cap of N inserts
			if ((i+1) % (NUM_TO_INSERT + 1) == 0):
				print(str(i/num_rows * 100) + '% completed')
				print('total: ', num_rows)
				break

			# Convert from utc to datetime
			date = datetime.utcfromtimestamp(datetimes[i]).strftime\
				('%Y-%m-%d %H:%M:%S')

			# Extract minimum bounding rectangle coordinates
			# reminder: lon corresponds to x, lat corresponds to y

			# top left corner
			mbr_tlc_lat = max(lat_bnds[:,i])	
			mbr_tlc_lon = min(lon_bnds[:,i])

			# bottom right corner
			mbr_brc_lat = min(lat_bnds[:,i])	
			mbr_brc_lon = max(lon_bnds[:,i])

			# Append to SQL statement
			cmd = 'CALL rtree_insert(\' %s \' , %s, %s, %s, %s, %s)' % \
					(date, sifs[i], \
					 mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon)
			print(str(i) + ": " + cmd + ";")
		
			# execute insert
			cursor.execute(cmd)

			
			
		conn.commit()

		break

# query to get all rectangles after insert
query = '(SELECT mbr_tlc_lat, mbr_tlc_lon, \
				mbr_brc_lat, mbr_brc_lon, level \
		 FROM \
		 entry_geom NATURAL JOIN leaf_node_entries) UNION \
		 (SELECT mbr_tlc_lat, mbr_tlc_lon, \
				mbr_brc_lat, mbr_brc_lon, level \
		 FROM \
		 entry_geom NATURAL JOIN inner_node_entries);'

# execute get-query
cursor.execute(query)

# build rectangles array
rectangles = []
for (tlc_lat, tlc_lon, brc_lat, brc_lon, length) in cursor :
	rectangles.append([float(tlc_lat), float(tlc_lon), 
					  float(brc_lat), float(brc_lon), int(length)])

# list -> np.array
rectangles = np.array(rectangles)

for r in rectangles:
	curr_len = r[3] - r[1]
	curr_height = r[0] - r[2]
	rect = Rectangle((r[1] + 180 , 180 - (r[2] + 90) - curr_height), 
		curr_len, curr_height, fill = False, linewidth = 1.0, 
		color = colors[int(r[4])])
	# print("({}, {})".format(curr_len, curr_height))
	ax.add_patch(rect)
	ax.set_xlabel(rect_num)

# print("rectangle count: ", np.shape(rectangles))

plt.imshow(im)
plt.savefig('rect{}.png'.format(rect_num), dpi = 200)
rect_num += 1

[p.remove() for p in reversed(ax.patches)]

# https://stackoverflow.com/questions/5967500/how-to-correctly-sort-a-
# string-with-a-number-inside
def atoi(text):
    return int(text) if text.isdigit() else text
def natural_keys(text):
    return [ atoi(c) for c in re.split(r'(\d+)', text) ]

images = sorted(glob.glob("rect*.png"), key = natural_keys)
mim_images = []
for f in images:
	mim_images.append(imageio.imread(f))
imageio.mimsave('evolution.gif', mim_images)

os.system("rm rect*.png")

print('total elapsed time: ' + str(time.time() - t0))
